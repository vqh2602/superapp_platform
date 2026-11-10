import { BridgeError, BridgeEventListener, BridgeResponse, NativeWindowBridge } from './types.js';

export interface PendingBridgeCallback {
  transportId: string;
  action: string;
  resolve: (val: any) => void;
  reject: (err: any) => void;
  timer: any;
  createdAt: number;
}

const forwardingShims = new WeakSet<Function>();

export function isForwardingShim(fn: Function): boolean {
  return forwardingShims.has(fn);
}

export function markAsForwardingShim(fn: Function): void {
  forwardingShims.add(fn);
}

/**
 * Page-level BridgeHub providing a single shared registry for native callbacks
 * and event dispatching across all SDK and transport instances.
 *
 * Prevents wrapper accumulation on window.SuperAppBridge regardless of how
 * many SuperAppSDK or NativeBridgeTransport instances are instantiated.
 */
export class BridgeHub {
  private static instance?: BridgeHub;

  private pendingCallbacks: Map<string, PendingBridgeCallback> = new Map();
  private transportListeners: Map<string, Map<string, Set<BridgeEventListener>>> = new Map();
  private pageUnloadHandler?: () => void;

  public static getShared(): BridgeHub {
    if (typeof window !== 'undefined') {
      const win = window as any;
      if (!win.__SUPERAPP_BRIDGE_HUB__) {
        win.__SUPERAPP_BRIDGE_HUB__ = new BridgeHub();
      }
      return win.__SUPERAPP_BRIDGE_HUB__;
    }
    if (!BridgeHub.instance) {
      BridgeHub.instance = new BridgeHub();
    }
    return BridgeHub.instance;
  }

  public static resetForTesting(): void {
    if (typeof window !== 'undefined') {
      const win = window as any;
      if (win.__SUPERAPP_BRIDGE_HUB__) {
        win.__SUPERAPP_BRIDGE_HUB__.cleanupAll('TEST_RESET', 'BridgeHub reset for testing');
        delete win.__SUPERAPP_BRIDGE_HUB__;
      }
    }
    if (BridgeHub.instance) {
      BridgeHub.instance.cleanupAll('TEST_RESET', 'BridgeHub reset for testing');
      BridgeHub.instance = undefined;
    }
  }

  /**
   * Installs the canonical dispatchResponse and dispatchEvent wrappers
   * exactly once on window.SuperAppBridge.
   */
  public installOnGlobalBridge(): void {
    if (typeof window === 'undefined') return;

    const win = window as unknown as NativeWindowBridge;
    if (!win.SuperAppBridge) {
      win.SuperAppBridge = {} as NonNullable<NativeWindowBridge['SuperAppBridge']>;
    }
    const bridge = win.SuperAppBridge;
    bridge._callbacks ||= {};
    bridge._listeners ||= {};

    if (!bridge.postMessage) {
      bridge.postMessage = (msg: any) => {
        win.FlutterBridge?.postMessage(typeof msg === 'string' ? msg : JSON.stringify(msg));
      };
      markAsForwardingShim(bridge.postMessage);
    }

    if (!bridge.addEventListener) {
      bridge.addEventListener = (event, handler) => {
        (bridge._listeners[event] ||= []).push(handler);
      };
    }
    if (!bridge.removeEventListener) {
      bridge.removeEventListener = (event, handler) => {
        bridge._listeners[event] = (bridge._listeners[event] || []).filter(fn => fn !== handler);
      };
    }

    // Check if the Hub is already hooked into this bridge instance
    const bridgeObj = bridge as any;
    if (bridgeObj.__hubInstalled__) {
      return;
    }
    bridgeObj.__hubInstalled__ = true;

    // Single canonical dispatchResponse implementation:
    bridge.dispatchResponse = (res: BridgeResponse) => {
      this.dispatchResponse(res);
    };

    // Single canonical dispatchEvent implementation:
    bridge.dispatchEvent = (evt: { event: string; payload: any }) => {
      this.dispatchEvent(evt);
    };

    // Register automatic cleanup on page unload if in a browser environment
    if (!this.pageUnloadHandler && typeof window.addEventListener === 'function') {
      this.pageUnloadHandler = () => {
        this.cleanupAll('PAGE_UNLOADED', 'Mini App page unloaded');
      };
      try {
        window.addEventListener('pagehide', this.pageUnloadHandler);
        window.addEventListener('beforeunload', this.pageUnloadHandler);
      } catch (_) {}
    }
  }

  public registerCallback(id: string, callback: PendingBridgeCallback): void {
    this.pendingCallbacks.set(id, callback);
  }

  public unregisterCallback(id: string): void {
    this.pendingCallbacks.delete(id);
  }

  public addListener(transportId: string, event: string, listener: BridgeEventListener): () => void {
    let eventMap = this.transportListeners.get(transportId);
    if (!eventMap) {
      eventMap = new Map();
      this.transportListeners.set(transportId, eventMap);
    }
    let set = eventMap.get(event);
    if (!set) {
      set = new Set();
      eventMap.set(event, set);
    }
    set.add(listener);

    return () => this.removeListener(transportId, event, listener);
  }

  public removeListener(transportId: string, event: string, listener: BridgeEventListener): void {
    const eventMap = this.transportListeners.get(transportId);
    if (!eventMap) return;
    const set = eventMap.get(event);
    if (set) {
      set.delete(listener);
      if (set.size === 0) {
        eventMap.delete(event);
      }
    }
    if (eventMap.size === 0) {
      this.transportListeners.delete(transportId);
    }
  }

  public removeListenersForTransport(transportId: string): void {
    this.transportListeners.delete(transportId);
  }

  public cancelPendingRequestsForTransport(
    transportId: string,
    errorCode = 'ABORTED',
    errorMessage = 'Request aborted because transport was destroyed'
  ): void {
    for (const [id, pending] of [...this.pendingCallbacks.entries()]) {
      if (pending.transportId === transportId) {
        clearTimeout(pending.timer);
        this.pendingCallbacks.delete(id);

        if (typeof window !== 'undefined') {
          const win = window as unknown as NativeWindowBridge;
          if (win.SuperAppBridge?._callbacks) {
            delete win.SuperAppBridge._callbacks[id];
          }
        }

        pending.reject({
          code: errorCode,
          message: errorMessage,
        } as BridgeError);
      }
    }
  }

  public dispatchResponse(res: BridgeResponse): void {
    if (!res || !res.id) return;

    // Check if plain JS or legacy code registered a callback directly in window.SuperAppBridge._callbacks
    let plainCallback: ((res: BridgeResponse) => void) | undefined;
    if (typeof window !== 'undefined') {
      const win = window as unknown as NativeWindowBridge;
      if (win.SuperAppBridge?._callbacks && win.SuperAppBridge._callbacks[res.id]) {
        plainCallback = win.SuperAppBridge._callbacks[res.id];
        delete win.SuperAppBridge._callbacks[res.id];
      }
    }

    // Check pending Hub callbacks
    const pending = this.pendingCallbacks.get(res.id);
    if (pending) {
      clearTimeout(pending.timer);
      this.pendingCallbacks.delete(res.id);

      if (res.success) {
        pending.resolve(res.data);
      } else {
        pending.reject(res.error || { code: 'UNKNOWN_ERROR', message: 'Operation failed without error payload' });
      }
      return;
    }

    // If not in pending Hub callbacks, execute the plain JS callback (e.g. playground legacy code)
    if (plainCallback) {
      try {
        plainCallback(res);
      } catch (err) {
        console.error(`[BridgeHub] Plain JS callback error on request "${res.id}":`, err);
      }
    }
  }

  public dispatchEvent(evt: { event: string; payload: any }): void {
    if (!evt || !evt.event) return;

    // 1. Dispatch to all active transport instances registered in BridgeHub
    for (const [transportId, eventMap] of this.transportListeners.entries()) {
      const listeners = eventMap.get(evt.event);
      if (listeners) {
        for (const listener of [...listeners]) {
          try {
            listener(evt.payload);
          } catch (err) {
            console.error(`[BridgeHub] Error in listener (${transportId}) for event "${evt.event}":`, err);
          }
        }
      }
    }

    // 2. Dispatch to plain JS listeners on window.SuperAppBridge._listeners
    if (typeof window !== 'undefined') {
      const win = window as unknown as NativeWindowBridge;
      const plainListeners = win.SuperAppBridge?._listeners?.[evt.event];
      if (plainListeners && Array.isArray(plainListeners)) {
        for (const fn of [...plainListeners]) {
          try {
            fn(evt.payload);
          } catch (err) {
            console.error(`[BridgeHub] Error in plain JS listener for event "${evt.event}":`, err);
          }
        }
      }
    }
  }

  public cleanupAll(errorCode = 'PAGE_UNLOADED', errorMessage = 'BridgeHub cleaned up'): void {
    for (const [id, pending] of this.pendingCallbacks.entries()) {
      clearTimeout(pending.timer);
      pending.reject({
        code: errorCode,
        message: errorMessage,
      } as BridgeError);
    }
    this.pendingCallbacks.clear();
    this.transportListeners.clear();

    if (typeof window !== 'undefined') {
      const win = window as unknown as NativeWindowBridge;
      if (win.SuperAppBridge) {
        win.SuperAppBridge._callbacks = {};
      }
      if (this.pageUnloadHandler && typeof window.removeEventListener === 'function') {
        try {
          window.removeEventListener('pagehide', this.pageUnloadHandler);
          window.removeEventListener('beforeunload', this.pageUnloadHandler);
        } catch (_) {}
      }
    }
  }

  public getPendingCount(): number {
    return this.pendingCallbacks.size;
  }

  public getListenerCount(event?: string): number {
    let total = 0;
    for (const eventMap of this.transportListeners.values()) {
      if (event) {
        total += eventMap.get(event)?.size ?? 0;
      } else {
        for (const set of eventMap.values()) {
          total += set.size;
        }
      }
    }
    return total;
  }
}
