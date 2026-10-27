import { ITransport } from './transport.interface.js';
import { BridgeEventListener, BridgeRequest, BridgeResponse, TransportConfig, TransportType } from './types.js';

export type MockDispatcher = (request: BridgeRequest) => Promise<BridgeResponse>;

export class MockBridgeTransport implements ITransport {
  private appId: string;
  private debug: boolean;
  private dispatcher?: MockDispatcher;
  private listeners: Map<string, Set<BridgeEventListener>> = new Map();

  constructor(config: TransportConfig & { dispatcher?: MockDispatcher } = {}) {
    this.appId = config.appId || 'mini_app_mock';
    this.debug = config.debug ?? false;
    this.dispatcher = config.dispatcher;
  }

  public getType(): TransportType {
    return 'mock';
  }

  public isConnected(): boolean {
    return true;
  }

  public setDispatcher(dispatcher: MockDispatcher): void {
    this.dispatcher = dispatcher;
  }

  public async invoke<T = any>(action: string, payload: Record<string, any> = {}, _timeoutMs?: number): Promise<T> {
    const request: BridgeRequest = {
      id: `mock_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'mock://in-memory',
      timestamp: Date.now(),
    };

    if (this.debug) {
      console.log(`[MockBridgeTransport] Dispatching mock call:`, request);
    }

    if (!this.dispatcher) {
      throw {
        code: 'NO_MOCK_DISPATCHER',
        message: `No mock dispatcher registered for action "${action}". Attach an SDKMockEngine instance.`,
      };
    }

    const response = await this.dispatcher(request);
    if (this.debug) {
      console.log(`[MockBridgeTransport] Dispatcher responded:`, response);
    }

    if (response.success) {
      return response.data as T;
    } else {
      throw response.error || { code: 'MOCK_ERROR', message: `Mock execution failed for ${action}` };
    }
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
          console.error(`[MockBridgeTransport] Event listener error for "${event}":`, err);
        }
      });
    }
  }
}
