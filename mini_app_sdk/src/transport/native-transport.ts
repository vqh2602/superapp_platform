import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, NativeWindowBridge, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;
// A forwarding shim is not evidence that a native host is connected.
const forwardingShims = new WeakSet<Function>();
export function isNativeBridgeAvailable(): boolean {
  if (typeof window === 'undefined') return false;
  const win = window as unknown as NativeWindowBridge;
  const send = win.SuperAppBridge?.postMessage;
  return typeof win.FlutterBridge?.postMessage === 'function' ||
    (typeof send === 'function' && !forwardingShims.has(send));
}

export class NativeBridgeTransport implements ITransport {
  private installedBridges = new WeakSet<object>();
  private appId: string;
  private defaultTimeoutMs: number;
  private debug: boolean;
  private callbacks: Map<string, { resolve: (val: any) => void; reject: (err: any) => void; timer: any }> = new Map();
  private listeners: Map<string, Set<BridgeEventListener>> = new Map();

  constructor(config: TransportConfig = {}) {
    this.appId = config.appId || 'mini_app_default';
    this.defaultTimeoutMs = config.timeoutMs ?? 10000;
    this.debug = config.debug ?? false;
    this.initNativeGlobalBridge();
  }

  public getType(): TransportType {
    return 'native';
  }

  public isConnected(): boolean {
    return isNativeBridgeAvailable();
  }

  private initNativeGlobalBridge(): void {
    if (typeof window === 'undefined') return;
    const win = window as unknown as NativeWindowBridge;
    if (!win.SuperAppBridge) {
      // Keep the shared callback/listener contract used by the Flutter host and
      // plain JS clients, even when this SDK is the first script to initialize.
      win.SuperAppBridge = {} as NonNullable<NativeWindowBridge['SuperAppBridge']>;
    }
    const bridge = win.SuperAppBridge;
    bridge._callbacks ||= {};
    bridge._listeners ||= {};
    if (!bridge.postMessage) {
      bridge.postMessage = (msg: any) => {
        win.FlutterBridge?.postMessage(typeof msg === 'string' ? msg : JSON.stringify(msg));
      };
      forwardingShims.add(bridge.postMessage);
    }
    if (!bridge.dispatchResponse) {
      bridge.dispatchResponse = (res: BridgeResponse) => {
        const callback = bridge._callbacks[res.id];
        if (callback) {
          delete bridge._callbacks[res.id];
          callback(res);
        }
      };
    }
    if (!bridge.dispatchEvent) {
      bridge.dispatchEvent = (evt) => {
        for (const listener of [...(bridge._listeners[evt.event] || [])]) {
          try { listener(evt.payload); } catch (error) { console.error(error); }
        }
      };
    }
    bridge.addEventListener ||= (event, handler) => {
      (bridge._listeners[event] ||= []).push(handler);
    };
    bridge.removeEventListener ||= (event, handler) => {
      bridge._listeners[event] = (bridge._listeners[event] || []).filter(fn => fn !== handler);
    };
    // Install once per bridge object, rather than stacking new wrappers per call.
    // Also reconnect if a host replaces the bridge after SDK initialization.
    if (this.installedBridges.has(bridge)) return;
    this.installedBridges.add(bridge);
    const previousResponse = bridge.dispatchResponse;
    bridge.dispatchResponse = (res) => {
      this.handleNativeResponse(res);
      previousResponse.call(bridge, res);
    };
    const previousEvent = bridge.dispatchEvent;
    bridge.dispatchEvent = (evt) => {
      this.emit(evt.event, evt.payload);
      previousEvent.call(bridge, evt);
    };
  }

  private handleNativeResponse(res: BridgeResponse): void {
    if (!res || !res.id) return;
    if (this.debug) {
      console.log(`[NativeBridgeTransport] Response received:`, res);
    }
    const pending = this.callbacks.get(res.id);
    if (!pending) return;

    clearTimeout(pending.timer);
    this.callbacks.delete(res.id);

    if (typeof window !== 'undefined') {
      const win = window as unknown as NativeWindowBridge;
      if (win.SuperAppBridge?._callbacks) {
        delete win.SuperAppBridge._callbacks[res.id];
      }
    }

    if (res.success) {
      pending.resolve(res.data);
    } else {
      pending.reject(res.error || { code: 'UNKNOWN_ERROR', message: 'Operation failed without error payload' });
    }
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    const id = `sdk_req_${Date.now()}_${requestSequence++}`;
    const timeout = timeoutMs ?? this.defaultTimeoutMs;

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'miniapp://local',
      timestamp: Date.now(),
    };

    return new Promise<T>((resolve, reject) => {
      this.initNativeGlobalBridge();

      const timer = setTimeout(() => {
        this.callbacks.delete(id);
        if (typeof window !== 'undefined') {
          const win = window as unknown as NativeWindowBridge;
          if (win.SuperAppBridge?._callbacks) {
            delete win.SuperAppBridge._callbacks[id];
          }
        }
        const timeoutError: BridgeError = {
          code: 'TIMEOUT',
          message: `Bridge call "${action}" timed out after ${timeout}ms`,
        };
        if (this.debug) {
          console.warn(`[NativeBridgeTransport] Request ${id} timed out:`, timeoutError);
        }
        reject(timeoutError);
      }, timeout);

      this.callbacks.set(id, { resolve, reject, timer });

      if (this.debug) {
        console.log(`[NativeBridgeTransport] Invoking ${action}:`, request);
      }

      if (typeof window !== 'undefined') {
        const win = window as unknown as NativeWindowBridge;

        // Register callback in window.SuperAppBridge._callbacks for seamless polyfill response delivery
        if (win.SuperAppBridge) {
          win.SuperAppBridge._callbacks = win.SuperAppBridge._callbacks || {};
          win.SuperAppBridge._callbacks[id] = (res: BridgeResponse) => {
            this.handleNativeResponse(res);
          };
        }

        if (win.FlutterBridge?.postMessage) {
          win.FlutterBridge.postMessage(JSON.stringify(request));
        } else if (isNativeBridgeAvailable() && win.SuperAppBridge?.postMessage) {
          win.SuperAppBridge.postMessage(request);
        } else {
          clearTimeout(timer);
          this.callbacks.delete(id);
          if (win.SuperAppBridge?._callbacks) {
            delete win.SuperAppBridge._callbacks[id];
          }
          reject({
            code: 'NATIVE_NOT_AVAILABLE',
            message: 'FlutterBridge or SuperAppBridge is not installed on window object',
          } as BridgeError);
        }
      } else {
        clearTimeout(timer);
        this.callbacks.delete(id);
        reject({
          code: 'ENVIRONMENT_ERROR',
          message: 'Cannot invoke native bridge in a non-browser environment',
        } as BridgeError);
      }
    });
  }

  public on(event: string, listener: BridgeEventListener): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(listener);
    return () => this.off(event, listener);
  }

  public off(event: string, listener: BridgeEventListener): void {
    const set = this.listeners.get(event);
    if (set) {
      set.delete(listener);
      if (set.size === 0) {
        this.listeners.delete(event);
      }
    }
  }

  public emit(event: string, payload: any): void {
    if (this.debug) {
      console.log(`[NativeBridgeTransport] Event received [${event}]:`, payload);
    }
    const set = this.listeners.get(event);
    if (set) {
      set.forEach((listener) => {
        try {
          listener(payload);
        } catch (err) {
          console.error(`[NativeBridgeTransport] Error in listener for event "${event}":`, err);
        }
      });
    }
  }
}
