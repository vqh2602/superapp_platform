import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, NativeWindowBridge, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;

export class NativeBridgeTransport implements ITransport {
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
    if (typeof window === 'undefined') return false;
    const win = window as unknown as NativeWindowBridge;
    return !!win.FlutterBridge?.postMessage;
  }

  private initNativeGlobalBridge(): void {
    if (typeof window === 'undefined') return;
    const win = window as unknown as NativeWindowBridge;

    if (!win.SuperAppBridge) {
      win.SuperAppBridge = {
        _callbacks: {},
        _listeners: {},
        postMessage: (msg: any) => {
          if (win.FlutterBridge?.postMessage) {
            win.FlutterBridge.postMessage(typeof msg === 'string' ? msg : JSON.stringify(msg));
          }
        },
        dispatchResponse: (res: BridgeResponse) => {
          this.handleNativeResponse(res);
        },
        dispatchEvent: (evt: { event: string; payload: any }) => {
          this.emit(evt.event, evt.payload);
        },
        addEventListener: (event: string, handler: BridgeEventListener) => {
          this.on(event, handler);
        },
        removeEventListener: (event: string, handler: BridgeEventListener) => {
          this.off(event, handler);
        },
      };
    }
  }

  private handleNativeResponse(res: BridgeResponse): void {
    if (this.debug) {
      console.log(`[NativeBridgeTransport] Response received:`, res);
    }
    const pending = this.callbacks.get(res.id);
    if (!pending) return;

    clearTimeout(pending.timer);
    this.callbacks.delete(res.id);

    if (res.success) {
      pending.resolve(res.data);
    } else {
      pending.reject(res.error || { code: 'UNKNOWN_ERROR', message: 'Operation failed without error payload' });
    }
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    const id = `req_${Date.now()}_${requestSequence++}`;
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
      const timer = setTimeout(() => {
        this.callbacks.delete(id);
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
        if (win.FlutterBridge?.postMessage) {
          win.FlutterBridge.postMessage(JSON.stringify(request));
        } else {
          clearTimeout(timer);
          this.callbacks.delete(id);
          reject({
            code: 'NATIVE_NOT_AVAILABLE',
            message: 'FlutterBridge is not installed on window object',
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
