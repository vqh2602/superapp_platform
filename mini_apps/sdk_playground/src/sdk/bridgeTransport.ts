import { TransportResolver, type ITransport } from '@vqh2602/mini-app-sdk';
import { BridgeEventListener } from './types';

export class BridgeTransport {
  private runtimeTransport: ITransport;
  constructor(appId = 'sdk_playground') {
    this.runtimeTransport = TransportResolver.resolve({ appId });
  }
  public isConnectedToNative(): boolean { return this.runtimeTransport.getType() === 'native'; }
  public isConnectedToSimulator(): boolean { return this.runtimeTransport.getType() === 'postmessage'; }
  public isConnected(): boolean { return this.runtimeTransport.isConnected(); }
  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs?: number): Promise<T> {
    return this.runtimeTransport.invoke<T>(action, payload, timeoutMs);
  }
  public addEventListener(event: string, handler: BridgeEventListener): () => void {
    return this.runtimeTransport.on(event, handler);
  }
}
