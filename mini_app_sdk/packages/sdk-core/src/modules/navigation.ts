import { ITransport } from '@superapp/sdk-transport';

export class NavigationModule {
  constructor(private transport: ITransport) {}

  /**
   * Đóng Mini App và quay lại màn hình SuperApp chính
   */
  public async closeApp(): Promise<void> {
    await this.transport.invoke('navigation.closeApp');
  }

  /**
   * Mở liên kết trình duyệt ngoài
   */
  public async openUrl(url: string): Promise<void> {
    await this.transport.invoke('phone.openExternalBrowser', { url });
  }
}
