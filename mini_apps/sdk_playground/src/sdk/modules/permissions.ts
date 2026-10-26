import { BridgeTransport } from '../bridgeTransport';

export class PermissionsModule {
  constructor(private transport: BridgeTransport) {}

  public async request(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.request', { capability });
  }

  public async check(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.check', { capability });
  }
}
