import { ITransport } from './transport.interface.js';
import { NativeBridgeTransport } from './native-transport.js';
import { PostMessageTransport } from './postmessage-transport.js';
import { MockBridgeTransport, MockDispatcher } from './mock-transport.js';
import { BridgeEventListener, NativeWindowBridge, TransportConfig, TransportType } from './types.js';

export interface AdaptiveTransportOptions extends TransportConfig {
  mockDispatcher?: MockDispatcher;
}

/**
 * AdaptiveBridgeTransport automatically selects and routes requests to:
 * 1. Native container (SuperApp Flutter WebView via window.FlutterBridge or window.SuperAppBridge)
 * 2. Parent Simulator iframe (Browser Simulator via window.parent.postMessage)
 * 3. Mock Bridge Transport (Local dev, test suites, or standalone browser tabs)
 *
 * It re-evaluates the environment dynamically so that if the native bridge
 * becomes available after script evaluation, calls are seamlessly routed to native.
 */
export class AdaptiveBridgeTransport implements ITransport {
  private nativeTransport: NativeBridgeTransport;
  private postmessageTransport: PostMessageTransport;
  private mockTransport: MockBridgeTransport;
  private debug: boolean;

  constructor(options: AdaptiveTransportOptions = {}) {
    this.debug = options.debug ?? false;
    this.nativeTransport = new NativeBridgeTransport(options);
    this.postmessageTransport = new PostMessageTransport(options);
    this.mockTransport = new MockBridgeTransport({ ...options, dispatcher: options.mockDispatcher });
  }

  public setMockDispatcher(dispatcher: MockDispatcher): void {
    this.mockTransport.setDispatcher(dispatcher);
  }

  public isNativeAvailable(): boolean {
    if (typeof window === 'undefined') return false;
    const win = window as unknown as NativeWindowBridge;
    return !!(win.FlutterBridge?.postMessage || win.SuperAppBridge?.postMessage);
  }

  public isSimulatorAvailable(): boolean {
    if (typeof window === 'undefined') return false;
    return !!(window.parent && window.parent !== window);
  }

  public getType(): TransportType {
    if (this.isNativeAvailable()) return 'native';
    if (this.isSimulatorAvailable()) return 'postmessage';
    return 'mock';
  }

  public isConnected(): boolean {
    return this.isNativeAvailable() || this.isSimulatorAvailable() || this.mockTransport.isConnected();
  }

  public getActiveTransport(): ITransport {
    if (this.isNativeAvailable()) {
      return this.nativeTransport;
    }
    if (this.isSimulatorAvailable()) {
      return this.postmessageTransport;
    }
    return this.mockTransport;
  }

  public async invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    // If not immediately available, perform a brief micro-poll (up to 100ms)
    // to give Flutter WebView's addJavaScriptChannel time to attach
    if (!this.isNativeAvailable() && !this.isSimulatorAvailable() && typeof window !== 'undefined') {
      for (let i = 0; i < 4; i++) {
        if (this.isNativeAvailable()) break;
        await new Promise((r) => setTimeout(r, 25));
      }
    }

    const active = this.getActiveTransport();
    if (this.debug) {
      console.info(`[AdaptiveBridgeTransport] Routing action "${action}" to transport: [${active.getType()}]`);
    }
    return active.invoke<T>(action, payload, timeoutMs);
  }

  public on(event: string, listener: BridgeEventListener): () => void {
    const unsubNative = this.nativeTransport.on(event, listener);
    const unsubPost = this.postmessageTransport.on(event, listener);
    const unsubMock = this.mockTransport.on(event, listener);
    return () => {
      unsubNative();
      unsubPost();
      unsubMock();
    };
  }

  public off(event: string, listener: BridgeEventListener): void {
    this.nativeTransport.off(event, listener);
    this.postmessageTransport.off(event, listener);
    this.mockTransport.off(event, listener);
  }

  public emit(event: string, payload: any): void {
    this.getActiveTransport().emit(event, payload);
  }
}
