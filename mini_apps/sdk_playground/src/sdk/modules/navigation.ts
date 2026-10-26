import { BridgeTransport } from '../bridgeTransport';

export class NavigationModule {
  constructor(private transport: BridgeTransport) {}

  public async openNativePage(page: 'profile' | 'form' | string, params?: Record<string, any>): Promise<any> {
    return this.transport.invoke('navigation.openNativePage', { page, params });
  }

  public async close(): Promise<any> {
    return this.transport.invoke('navigation.close');
  }

  public async openMiniApp(appId: string): Promise<any> {
    return this.transport.invoke('navigation.openMiniApp', { appId });
  }
}
