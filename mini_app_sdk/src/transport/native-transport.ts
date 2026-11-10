import { BridgeHub, isForwardingShim } from './bridge-hub.js';
import { bridgeTimeoutMs } from './timeout-policy.js';
import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, NativeWindowBridge, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;
let transportSequence = 1;

export function isNativeBridgeAvailable(): boolean {
  if (typeof window === 'undefined') return false;
  const win = window as unknown as NativeWindowBridge;
  const send = win.SuperAppBridge?.postMessage;
  return typeof win.FlutterBridge?.postMessage === 'function' ||
    (typeof send === 'function' && !isForwardingShim(send));
}

export class NativeBridgeTransport implements ITransport {
  private transportId: string;
  private appId: string;
  private defaultTimeoutMs?: number;
  private debug: boolean;
  private isDestroyed = false;
  private hub: BridgeHub;

  constructor(config: TransportConfig = {}) {
    this.transportId = `native_trans_${Date.now()}_${transportSequence++}`;
    this.appId = config.appId || 'mini_app_default';
    this.defaultTimeoutMs = config.timeoutMs;
    this.debug = config.debug ?? false;
    this.hub = BridgeHub.getShared();
    this.hub.installOnGlobalBridge();
  }

  public getType(): TransportType {
    return 'native';
  }

  public isConnected(): boolean {
    return isNativeBridgeAvailable();
  }

  public getTransportId(): string {
    return this.transportId;
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    if (this.isDestroyed) {
      return Promise.reject({
        code: 'TRANSPORT_DESTROYED',
        message: 'NativeBridgeTransport has been destroyed and cannot invoke actions',
      } as BridgeError);
    }

    const id = `sdk_req_${Date.now()}_${requestSequence++}`;
    const timeout = bridgeTimeoutMs(action, timeoutMs ?? this.defaultTimeoutMs);

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'miniapp://local',
      timestamp: Date.now(),
    };

    return new Promise<T>((resolve, reject) => {
      this.hub.installOnGlobalBridge();

      const timer = setTimeout(() => {
        this.hub.unregisterCallback(id);
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

      this.hub.registerCallback(id, {
        transportId: this.transportId,
        action,
        resolve,
        reject,
        timer,
        createdAt: Date.now(),
      });

      if (this.debug) {
        console.log(`[NativeBridgeTransport] Invoking ${action}:`, request);
      }

      if (typeof window !== 'undefined') {
        const win = window as unknown as NativeWindowBridge;

        // Register callback in window.SuperAppBridge._callbacks for seamless polyfill response delivery
        if (win.SuperAppBridge) {
          win.SuperAppBridge._callbacks = win.SuperAppBridge._callbacks || {};
          win.SuperAppBridge._callbacks[id] = (res: BridgeResponse) => {
            this.hub.dispatchResponse(res);
          };
        }

        if (win.FlutterBridge?.postMessage) {
          win.FlutterBridge.postMessage(JSON.stringify(request));
        } else if (isNativeBridgeAvailable() && win.SuperAppBridge?.postMessage) {
          win.SuperAppBridge.postMessage(request);
        } else {
          clearTimeout(timer);
          this.hub.unregisterCallback(id);
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
        this.hub.unregisterCallback(id);
        reject({
          code: 'ENVIRONMENT_ERROR',
          message: 'Cannot invoke native bridge in a non-browser environment',
        } as BridgeError);
      }
    });
  }

  public on(event: string, listener: BridgeEventListener): () => void {
    return this.hub.addListener(this.transportId, event, listener);
  }

  public off(event: string, listener: BridgeEventListener): void {
    this.hub.removeListener(this.transportId, event, listener);
  }

  public emit(event: string, payload: any): void {
    if (this.debug) {
      console.log(`[NativeBridgeTransport] Emitting event [${event}]:`, payload);
    }
    this.hub.dispatchEvent({ event, payload });
  }

  public destroy(): void {
    if (this.isDestroyed) return;
    this.isDestroyed = true;

    this.hub.cancelPendingRequestsForTransport(
      this.transportId,
      'ABORTED',
      'NativeBridgeTransport was destroyed before request completed'
    );
    this.hub.removeListenersForTransport(this.transportId);

    if (this.debug) {
      console.log(`[NativeBridgeTransport] Transport ${this.transportId} destroyed.`);
    }
  }

  public dispose(): void {
    this.destroy();
  }
}
