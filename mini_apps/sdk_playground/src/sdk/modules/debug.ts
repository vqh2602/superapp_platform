import { BridgeTransport } from '../bridgeTransport';

export class DebugModule {
  constructor(private transport: BridgeTransport) {}

  public async echo(payload: any): Promise<any> {
    return this.transport.invoke('debug.echo', payload);
  }

  public async simulateFailure(type: 'timeout' | 'unauthorized' | 'permission_denied' | 'unsupported' | 'internal'): Promise<any> {
    return this.transport.invoke('debug.simulateFailure', { type });
  }
}
