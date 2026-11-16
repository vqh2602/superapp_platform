import { bridgeTimeoutMs } from './timeout-policy.js';
import { ITransport } from './transport.interface.js';
import { BridgeError, BridgeEventListener, BridgeRequest, BridgeResponse, TransportConfig, TransportType } from './types.js';

let requestSequence = 1;

/**
 * PostMessageHub provides a single shared window.addEventListener('message')
 * across all PostMessageTransport instances in the page.
 *
 * It prevents duplicate listeners, routes responses strictly to the requesting
 * transport instance, and unregisters from window when all instances are destroyed.
 */
export class PostMessageHub {
  private static instance?: PostMessageHub;
  private transports: Set<PostMessageTransport> = new Set();
  private messageListener?: (event: MessageEvent) => void;

  public static getShared(): PostMessageHub {
    if (typeof window !== 'undefined') {
      const win = window as any;
      if (!win.__SUPERAPP_POSTMESSAGE_HUB__) {
        win.__SUPERAPP_POSTMESSAGE_HUB__ = new PostMessageHub();
      }
      return win.__SUPERAPP_POSTMESSAGE_HUB__;
    }
    if (!PostMessageHub.instance) {
      PostMessageHub.instance = new PostMessageHub();
    }
    return PostMessageHub.instance;
  }

  public static resetForTesting(): void {
    if (typeof window !== 'undefined') {
      const win = window as any;
      if (win.__SUPERAPP_POSTMESSAGE_HUB__) {
        win.__SUPERAPP_POSTMESSAGE_HUB__.cleanupAll();
        delete win.__SUPERAPP_POSTMESSAGE_HUB__;
      }
    }
    if (PostMessageHub.instance) {
      PostMessageHub.instance.cleanupAll();
      PostMessageHub.instance = undefined;
    }
  }

  public register(transport: PostMessageTransport): void {
    this.transports.add(transport);
    this.ensureListener();
  }

  public unregister(transport: PostMessageTransport): void {
    this.transports.delete(transport);
    if (this.transports.size === 0) {
      this.removeListener();
    }
  }

  public getActiveCount(): number {
    return this.transports.size;
  }

  public isListenerInstalled(): boolean {
    return !!this.messageListener;
  }

  private ensureListener(): void {
    if (typeof window === 'undefined') return;
    if (this.messageListener) return;

    this.messageListener = (event: MessageEvent) => {
      this.handleMessage(event);
    };
    window.addEventListener('message', this.messageListener);
  }

  private removeListener(): void {
    if (typeof window !== 'undefined' && this.messageListener) {
      window.removeEventListener('message', this.messageListener);
      this.messageListener = undefined;
    }
  }

  public cleanupAll(): void {
    this.removeListener();
    for (const transport of Array.from(this.transports)) {
      transport.destroy();
    }
    this.transports.clear();
  }

  public handleMessage(event: MessageEvent): void {
    // 1. Verify event source is parent window
    if (typeof window !== 'undefined' && window.parent) {
      if (event.source && event.source !== window.parent) {
        for (const transport of this.transports) {
          if (transport.isDebug()) {
            console.warn('[PostMessageTransport] Rejected message: event.source !== window.parent');
          }
          break;
        }
        return;
      }
    }

    const data = event.data;
    if (!data || typeof data !== 'object') return;

    // 2. Handshake message
    if (data.type === 'SUPERAPP_SIMULATOR_HANDSHAKE' || data.type === 'SUPERAPP_SIMULATOR_HANDSHAKE_ACK') {
      for (const transport of this.transports) {
        transport.handleHandshakeMessage(data, event);
      }
      return;
    }

    // 3. Response message
    if (data.type === 'SUPERAPP_BRIDGE_RESPONSE') {
      const res: BridgeResponse = data.response;
      if (!res || !res.id) return;

      let handled = false;
      for (const transport of this.transports) {
        if (transport.hasCallback(res.id)) {
          transport.handleResponseMessage(res, event);
          handled = true;
          break;
        }
      }
      if (!handled && this.transports.size > 0) {
        for (const transport of this.transports) {
          if (transport.isDebug()) {
            console.warn(`[PostMessageTransport] Response received for unknown or expired request: ${res.id}`);
            break;
          }
        }
      }
      return;
    }

    // 4. Event message
    if (data.type === 'SUPERAPP_BRIDGE_EVENT') {
      if (data.event) {
        for (const transport of this.transports) {
          if (matchesHostOrigin(transport, event)) {
            transport.emit(data.event, data.payload);
          }
        }
      }
    }
  }
}

function matchesHostOrigin(transport: PostMessageTransport, event: MessageEvent): boolean {
  const origin = transport.getTrustedHostOrigin();
  if (!origin || origin === '*' || event.origin === origin) return true;

  if (transport.isDebug()) {
    console.warn(`[PostMessageTransport] Rejected message from untrusted origin: "${event.origin}". Expected: "${origin}"`);
  }
  return false;
}

export class PostMessageTransport implements ITransport {
  private appId: string;
  private defaultTimeoutMs?: number;
  private debug: boolean;
  private trustedHostOrigin?: string;
  private isDestroyed = false;
  private hub: PostMessageHub;
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

  constructor(config: TransportConfig = {}) {
    this.appId = config.appId || 'mini_app_simulator';
    this.defaultTimeoutMs = config.timeoutMs;
    this.debug = config.debug ?? false;
    this.trustedHostOrigin = config.trustedHostOrigin || this.resolveAutoDetectedHostOrigin();
    this.hub = PostMessageHub.getShared();
    this.hub.register(this);
    this.initHandshake();
  }

  public isDebug(): boolean {
    return this.debug;
  }

  public hasCallback(id: string): boolean {
    return this.callbacks.has(id);
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

  public handleHandshakeMessage(data: any, event: MessageEvent): void {
    const hostOrigin = event.origin;
    if ((!data.hostOrigin || data.hostOrigin === hostOrigin) && this.isValidHostOrigin(hostOrigin)) {
      if (!this.trustedHostOrigin) {
        this.trustedHostOrigin = hostOrigin;
        if (this.debug) {
          console.log(`[PostMessageTransport] Handshake established with host origin: ${this.trustedHostOrigin}`);
        }
      }
    }
  }

  public handleResponseMessage(res: BridgeResponse, event: MessageEvent): void {
    if (!matchesHostOrigin(this, event)) return;

    const pending = this.callbacks.get(res.id);
    if (!pending) return;

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
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    if (this.isDestroyed) {
      return Promise.reject({
        code: 'TRANSPORT_DESTROYED',
        message: 'PostMessageTransport has been destroyed and cannot invoke actions',
      } as BridgeError);
    }

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
    if (this.isDestroyed) return;
    this.isDestroyed = true;

    for (const [id, pending] of this.callbacks.entries()) {
      clearTimeout(pending.timer);
      pending.reject({
        code: 'ABORTED',
        message: 'PostMessageTransport was destroyed',
      } as BridgeError);
    }
    this.callbacks.clear();
    this.listeners.clear();

    this.hub.unregister(this);
  }

  public dispose(): void {
    this.destroy();
  }
}
