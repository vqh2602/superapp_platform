import { BridgeEventListener, TransportType } from './types.js';

export interface ITransport {
  getType(): TransportType;
  isConnected(): boolean;
  invoke<T = any>(action: string, payload?: Record<string, any>, timeoutMs?: number): Promise<T>;
  on(event: string, listener: BridgeEventListener): () => void;
  off(event: string, listener: BridgeEventListener): void;
  emit(event: string, payload: any): void;
}
