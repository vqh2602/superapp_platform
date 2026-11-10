import { bridgeTimeoutMs } from './timeout-policy.js';
import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;

export class PostMessageTransport implements ITransport {
  private appId: string;
  private defaultTimeoutMs?: number;
  private debug: boolean;
  private trustedHostOrigin?: string;
  private callbacks: Map<
    string,
    {
      resolve: (val: any) => void;
      reject: (err: any) => void;
      timer: any;
      action: string;
      sessionNonce: string;
      createdAt: number;
    }
  > = new Map();
  private listeners: Map<string, Set<BridgeEventListener>> = new Map();
  private messageListener?: (event: MessageEvent) => void;

  constructor(config: TransportConfig = {}) {
    this.appId = config.appId || 'mini_app_simulator';
    this.defaultTimeoutMs = config.timeoutMs;
    this.debug = config.debug ?? false;
    this.trustedHostOrigin = config.trustedHostOrigin || this.resolveAutoDetectedHostOrigin();
    this.initMessageListener();
    this.initHandshake();
  }

  public getType(): TransportType {
    return 'postmessage';
  }

  public isConnected(): boolean {
    return typeof window !== 'undefined' && window.parent !== window;
  }

  public getTrustedHostOrigin(): string | undefined {
    return this.trustedHostOrigin;
  }

  public setTrustedHostOrigin(origin: string): void {
    if (!this.isValidHostOrigin(origin) && origin !== '*') {
      throw new Error(`[PostMessageTransport] Invalid host origin: "${origin}". Must be a valid HTTP localhost or HTTPS origin.`);
    }
    this.trustedHostOrigin = origin;
  }

  public isValidHostOrigin(origin: string): boolean {
    if (!origin || typeof origin !== 'string') return false;
    try {
      const url = new URL(origin);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') {
        return false;
      }
      // In development, localhost and 127.0.0.1 or local domains are allowed
      if (
        url.hostname === 'localhost' ||
        url.hostname === '127.0.0.1' ||
        url.hostname.endsWith('.localhost')
      ) {
        return true;
      }
      // For remote hosts, HTTPS is required
      return url.protocol === 'https:';
    } catch (_) {
      return false;
    }
  }

  private resolveAutoDetectedHostOrigin(): string | undefined {
    if (typeof window === 'undefined') return undefined;

    const win = window as any;

    // 1. Explicit global injection by host container
    if (win.__SUPERAPP_TRUSTED_HOST_ORIGIN__) {
      return win.__SUPERAPP_TRUSTED_HOST_ORIGIN__;
    }
    if (win.__SUPERAPP_HOST_ORIGIN__) {
      return win.__SUPERAPP_HOST_ORIGIN__;
    }

    // 2. Query param ?hostOrigin=... or ?trustedHostOrigin=...
    try {
      if (win.location?.search) {
        const params = new URLSearchParams(win.location.search);
        const fromParam = params.get('trustedHostOrigin') || params.get('hostOrigin');
        if (fromParam) {
          const parsed = new URL(fromParam).origin;
          if (this.isValidHostOrigin(parsed)) {
            return parsed;
          }
        }
      }
    } catch (_) {}

    // 3. window.location.ancestorOrigins (Chromium & WebKit)
    try {
      if (win.location?.ancestorOrigins && win.location.ancestorOrigins.length > 0) {
        const ancestor = win.location.ancestorOrigins[0];
        if (ancestor && ancestor !== 'null' && this.isValidHostOrigin(ancestor)) {
          return ancestor;
        }
      }
    } catch (_) {}

    // 4. document.referrer
    try {
      if (typeof document !== 'undefined' && document.referrer) {
        const referrerOrigin = new URL(document.referrer).origin;
        if (referrerOrigin && referrerOrigin !== 'null' && this.isValidHostOrigin(referrerOrigin)) {
          return referrerOrigin;
        }
      }
    } catch (_) {}

    return undefined;
  }

  public getTargetOrigin(): string {
    if (this.trustedHostOrigin && this.trustedHostOrigin !== '*') {
      return this.trustedHostOrigin;
    }

    const detected = this.resolveAutoDetectedHostOrigin();
    if (detected) {
      this.trustedHostOrigin = detected;
      return detected;
    }

    if (typeof window !== 'undefined' && window.location?.origin && window.location.origin !== 'null') {
      try {
        const url = new URL(window.location.origin);
        if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') {
          return window.location.origin;
        }
      } catch (_) {}
    }

    if (this.debug) {
      console.warn('[PostMessageTransport] Warning: No trustedHostOrigin configured. Using fallback target origin.');
    }
    return '*';
  }

  private initHandshake(): void {
    if (typeof window === 'undefined' || !window.parent || window.parent === window) return;

    try {
      const target = this.trustedHostOrigin || '*';
      window.parent.postMessage(
        {
          type: 'SUPERAPP_BRIDGE_HANDSHAKE',
          appId: this.appId,
          clientOrigin: window.location?.origin,
          timestamp: Date.now(),
        },
        target
      );
    } catch (_) {}
  }

  private initMessageListener(): void {
    if (typeof window === 'undefined') return;

    this.messageListener = (event: MessageEvent) => {
      // 1. Verify event source is parent window
      if (typeof window !== 'undefined' && window.parent) {
        if (event.source && event.source !== window.parent) {
          if (this.debug) {
            console.warn('[PostMessageTransport] Rejected message: event.source !== window.parent');
          }
          return;
        }
      }

      // 2. Verify event origin against trustedHostOrigin
      if (this.trustedHostOrigin && this.trustedHostOrigin !== '*') {
        if (event.origin && event.origin !== this.trustedHostOrigin) {
          if (this.debug) {
            console.warn(
              `[PostMessageTransport] Rejected message from untrusted origin: "${event.origin}". Expected: "${this.trustedHostOrigin}"`
            );
          }
          return;
        }
      }

      const data = event.data;
      if (!data || typeof data !== 'object') return;

      // Handle handshake messages
      if (data.type === 'SUPERAPP_SIMULATOR_HANDSHAKE' || data.type === 'SUPERAPP_SIMULATOR_HANDSHAKE_ACK') {
        const hostOrigin = data.hostOrigin || event.origin;
        if (hostOrigin && this.isValidHostOrigin(hostOrigin)) {
          if (!this.trustedHostOrigin) {
            this.trustedHostOrigin = hostOrigin;
            if (this.debug) {
              console.log(`[PostMessageTransport] Handshake established with host origin: ${this.trustedHostOrigin}`);
            }
          }
        }
        return;
      }

      if (data.type === 'SUPERAPP_BRIDGE_RESPONSE') {
        const res: BridgeResponse = data.response;
        if (!res || !res.id) return;

        const pending = this.callbacks.get(res.id);
        if (!pending) {
          if (this.debug) {
            console.warn(`[PostMessageTransport] Response received for unknown or expired request: ${res.id}`);
          }
          return;
        }

        // 3. Verify sessionNonce
        if (pending.sessionNonce) {
          if (!res.sessionNonce || res.sessionNonce !== pending.sessionNonce) {
            const errorMsg = `Session nonce verification failed for request ${res.id}.`;
            console.error(`[PostMessageTransport] Security Violation: ${errorMsg}`);
            clearTimeout(pending.timer);
            this.callbacks.delete(res.id);
            pending.reject({
              code: 'SECURITY_ERROR',
              message: errorMsg,
            } as BridgeError);
            return;
          }
        }

        // 4. Verify action
        if (res.action && pending.action && res.action !== pending.action) {
          const errorMsg = `Action mismatch for request ${res.id}: expected "${pending.action}", received "${res.action}".`;
          console.error(`[PostMessageTransport] Security Violation: ${errorMsg}`);
          clearTimeout(pending.timer);
          this.callbacks.delete(res.id);
          pending.reject({
            code: 'SECURITY_ERROR',
            message: errorMsg,
          } as BridgeError);
          return;
        }

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
    const sessionNonce = `nonce_${Date.now()}_${Math.random().toString(36).substring(2, 11)}_${requestSequence}`;
    const timeout = bridgeTimeoutMs(action, timeoutMs ?? this.defaultTimeoutMs);

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location?.origin : 'miniapp://simulator',
      timestamp: Date.now(),
      sessionNonce,
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

      this.callbacks.set(id, {
        resolve,
        reject,
        timer,
        action,
        sessionNonce,
        createdAt: Date.now(),
      });

      if (typeof window !== 'undefined' && window.parent) {
        if (this.debug) {
          console.log(`[PostMessageTransport] PostMessage out to parent:`, request);
        }
        const targetOrigin = this.getTargetOrigin();
        window.parent.postMessage(
          {
            type: 'SUPERAPP_BRIDGE_REQUEST',
            request,
          },
          targetOrigin
        );
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
    for (const [id, pending] of this.callbacks.entries()) {
      clearTimeout(pending.timer);
      pending.reject({
        code: 'ABORTED',
        message: 'PostMessageTransport was destroyed',
      } as BridgeError);
    }
    this.callbacks.clear();
    this.listeners.clear();

    if (typeof window !== 'undefined' && this.messageListener) {
      window.removeEventListener('message', this.messageListener);
      this.messageListener = undefined;
    }
  }

  public dispose(): void {
    this.destroy();
  }
}
