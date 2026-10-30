import { bridgeTimeoutMs } from './timeout-policy.js';
import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;

export class PostMessageTransport implements ITransport {
  private appId: string;
  private defaultTimeoutMs?: number;
  private debug: boolean;
  private callbacks: Map<string, { resolve: (val: any) => void; reject: (err: any) => void; timer: any }> = new Map();
  private listeners: Map<string, Set<BridgeEventListener>> = new Map();
  private messageListener?: (event: MessageEvent) => void;

  constructor(config: TransportConfig = {}) {
    this.appId = config.appId || 'mini_app_simulator';
    this.defaultTimeoutMs = config.timeoutMs;
    this.debug = config.debug ?? false;
    this.initMessageListener();
  }

  public getType(): TransportType {
    return 'postmessage';
  }

  public isConnected(): boolean {
    return typeof window !== 'undefined' && window.parent !== window;
  }

  private initMessageListener(): void {
    if (typeof window === 'undefined') return;

    this.messageListener = (event: MessageEvent) => {
      const data = event.data;
      if (!data || typeof data !== 'object') return;

      if (data.type === 'SUPERAPP_BRIDGE_RESPONSE') {
        const res: BridgeResponse = data.response;
        if (!res || !res.id) return;

        const pending = this.callbacks.get(res.id);
        if (pending) {
          clearTimeout(pending.timer);
          this.callbacks.delete(res.id);
          if (this.debug) {
            console.log(`[PostMessageTransport] Response received:`, res);
          }
          if (res.success) {
            pending.resolve(res.data);
          } else {
            pending.reject(res.error || { code: 'UNKNOWN_ERROR', message: 'Request failed in simulator' });
          }
        }
      } else if (data.type === 'SUPERAPP_BRIDGE_EVENT') {
        if (data.event) {
          this.emit(data.event, data.payload);
        }
      }
    };

    window.addEventListener('message', this.messageListener);
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    const id = `req_${Date.now()}_${requestSequence++}`;
    const timeout = bridgeTimeoutMs(action, timeoutMs ?? this.defaultTimeoutMs);

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'miniapp://simulator',
      timestamp: Date.now(),
    };

    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.callbacks.delete(id);
        const timeoutError: BridgeError = {
          code: 'TIMEOUT',
          message: `Simulator Bridge call "${action}" timed out after ${timeout}ms`,
        };
        reject(timeoutError);
      }, timeout);

      this.callbacks.set(id, { resolve, reject, timer });

      if (typeof window !== 'undefined' && window.parent) {
        if (this.debug) {
          console.log(`[PostMessageTransport] PostMessage out to parent:`, request);
        }
        window.parent.postMessage({
          type: 'SUPERAPP_BRIDGE_REQUEST',
          request,
        }, '*');
      } else {
        clearTimeout(timer);
        this.callbacks.delete(id);
        reject({
          code: 'PARENT_WINDOW_NOT_FOUND',
          message: 'PostMessage target parent window not accessible',
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
    const set = this.listeners.get(event);
    if (set) {
      set.forEach((listener) => {
        try {
          listener(payload);
        } catch (err) {
          console.error(`[PostMessageTransport] Listener error on event "${event}":`, err);
        }
      });
    }
  }

  public destroy(): void {
    if (typeof window !== 'undefined' && this.messageListener) {
      window.removeEventListener('message', this.messageListener);
    }
  }
}
