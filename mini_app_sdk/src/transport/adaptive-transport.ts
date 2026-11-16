import { ITransport } from './transport.interface.js';
import { NativeBridgeTransport, isNativeBridgeAvailable } from './native-transport.js';
import { PostMessageTransport } from './postmessage-transport.js';
import { MockBridgeTransport, MockDispatcher } from './mock-transport.js';
import { BridgeError, BridgeEventListener, TransportConfig, TransportType } from './types.js';

export interface AdaptiveTransportOptions extends TransportConfig {
  mockDispatcher?: MockDispatcher;
}

/**
 * AdaptiveBridgeTransport automatically selects and routes requests to:
 * 1. Native container (SuperApp Flutter WebView via window.FlutterBridge or window.SuperAppBridge)
 * 2. Parent Simulator iframe (Browser Simulator via window.parent.postMessage)
 * With neither channel present, calls return the native bridge availability error.
 *
 * Transports are lazily instantiated so that in a native environment,
 * PostMessageTransport and MockBridgeTransport are never created, eliminating
 * unnecessary event listeners and postMessage handshakes.
 */
export class AdaptiveBridgeTransport implements ITransport {
  private _nativeTransport?: NativeBridgeTransport;
  private _postmessageTransport?: PostMessageTransport;
  private _mockTransport?: MockBridgeTransport;
  private isDestroyed = false;
  private options: AdaptiveTransportOptions;
  private debug: boolean;

  constructor(options: AdaptiveTransportOptions = {}) {
    this.options = options;
    this.debug = options.debug ?? false;
  }

  public get nativeTransport(): NativeBridgeTransport {
    if (!this._nativeTransport) {
      this._nativeTransport = new NativeBridgeTransport(this.options);
    }
    return this._nativeTransport;
  }

  public get postmessageTransport(): PostMessageTransport {
    if (!this._postmessageTransport) {
      this._postmessageTransport = new PostMessageTransport(this.options);
    }
    return this._postmessageTransport;
  }

  public get mockTransport(): MockBridgeTransport {
    if (!this._mockTransport) {
      this._mockTransport = new MockBridgeTransport({
        ...this.options,
        dispatcher: this.options.mockDispatcher,
      });
    }
    return this._mockTransport;
  }

  public setMockDispatcher(dispatcher: MockDispatcher): void {
    this.mockTransport.setDispatcher(dispatcher);
  }

  public isNativeAvailable(): boolean {
    return isNativeBridgeAvailable();
  }

  public isSimulatorAvailable(): boolean {
    if (typeof window === 'undefined') return false;
    return !!(window.parent && window.parent !== window);
  }

  public getType(): TransportType {
    if (this.isNativeAvailable()) return 'native';
    if (this.isSimulatorAvailable()) return 'postmessage';
    return 'unavailable';
  }

  public isConnected(): boolean {
    return this.isNativeAvailable() || this.isSimulatorAvailable();
  }

  public getActiveTransport(): ITransport {
    if (this.isNativeAvailable()) {
      return this.nativeTransport;
    }
    if (this.isSimulatorAvailable()) {
      return this.postmessageTransport;
    }
    return this.nativeTransport;
  }

  public async invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    // If not immediately available, perform a brief micro-poll (up to 100ms)
    // to give Flutter WebView's addJavaScriptChannel time to attach
    if (!this.isDestroyed && !this.isNativeAvailable() && !this.isSimulatorAvailable() && typeof window !== 'undefined') {
      for (let i = 0; i < 4; i++) {
        if (this.isDestroyed || this.isNativeAvailable()) break;
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    if (this.isDestroyed) {
      throw { code: 'TRANSPORT_DESTROYED', message: 'AdaptiveBridgeTransport has been destroyed' } satisfies BridgeError;
    }

    const active = this.getActiveTransport();
    if (this.debug) {
      console.info(`[AdaptiveBridgeTransport] Routing action "${action}" to transport: [${active.getType()}]`);
    }
    return active.invoke<T>(action, payload, timeoutMs);
  }

  public on(event: string, listener: BridgeEventListener): () => void {
    if (this.isDestroyed) return () => {};
    const unsubs = [this.nativeTransport.on(event, listener)];
    if (!this.isNativeAvailable() && this.isSimulatorAvailable()) {
      unsubs.push(this.postmessageTransport.on(event, listener));
    }
    if (this._mockTransport) {
      unsubs.push(this._mockTransport.on(event, listener));
    }
    return () => {
      for (const unsub of unsubs) {
        unsub();
      }
    };
  }

  public off(event: string, listener: BridgeEventListener): void {
    if (this._nativeTransport) {
      this._nativeTransport.off(event, listener);
    }
    if (this._postmessageTransport) {
      this._postmessageTransport.off(event, listener);
    }
    if (this._mockTransport) {
      this._mockTransport.off(event, listener);
    }
  }

  public emit(event: string, payload: any): void {
    if (!this.isDestroyed) this.getActiveTransport().emit(event, payload);
  }

  public destroy(): void {
    this.isDestroyed = true;
    if (this._nativeTransport) {
      this._nativeTransport.destroy();
      this._nativeTransport = undefined;
    }
    if (this._postmessageTransport) {
      this._postmessageTransport.destroy();
      this._postmessageTransport = undefined;
    }
    if (this._mockTransport) {
      this._mockTransport.destroy();
      this._mockTransport = undefined;
    }
  }

  public dispose(): void {
    this.destroy();
  }
}
