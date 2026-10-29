import { ITransport } from '@superapp/sdk-transport';
import { MinimizeAppResult } from '../types/index.js';

export class NavigationModule {
  constructor(private transport: ITransport) {}

  /**
   * Đóng Mini App và quay lại màn hình SuperApp chính
   */
  public async closeApp(): Promise<void> {
    await this.transport.invoke('navigation.closeApp');
  }

  /**
   * Thu nhỏ Mini App vào dạng floating window / background dock
   */
  public async minimizeApp(): Promise<MinimizeAppResult> {
    return this.transport.invoke<MinimizeAppResult>('navigation.minimizeApp');
  }

  /**
   * Mở liên kết trình duyệt ngoài
   */
  public async openUrl(url: string): Promise<void> {
    await this.transport.invoke('phone.openExternalBrowser', { url });
  }
}
