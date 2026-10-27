import { BridgeTransport } from '../bridgeTransport';

export class PermissionsModule {
  constructor(private transport: BridgeTransport) {}

  public async request(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.request', { capability });
  }

  public async check(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.check', { capability });
  }

  public async getPermissions(): Promise<{ appId: string; permissions: Record<string, boolean> }> {
    return this.transport.invoke('permission.getPermissions');
  }
}
