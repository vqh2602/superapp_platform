import { ITransport } from '../../transport/index.js';
import { MinimizeAppResult } from '../types/index.js';

export class NavigationModule {
  constructor(private transport: ITransport) {}

  /**
   * Tự động điều hướng mở màn hình Native của SuperApp (ví dụ: 'profile', 'form')
   */
  public async openNativePage(page: 'profile' | 'form' | string, params?: Record<string, any>): Promise<any> {
    return this.transport.invoke('navigation.openNativePage', { page, params });
  }

  /**
   * Điều hướng chuyển sang một Mini App khác trong SuperApp
   */
  public async openMiniApp(appId: string, params?: Record<string, any>): Promise<any> {
    return this.transport.invoke('navigation.openMiniApp', { appId, params });
  }

  /**
   * Đóng Mini App và quay lại màn hình SuperApp chính
   */
  public async closeApp(): Promise<any> {
    return this.transport.invoke('navigation.closeApp');
  }

  /**
   * Alias cho closeApp()
   */
  public async close(): Promise<any> {
    return this.transport.invoke('navigation.close');
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
  public async openUrl(url: string): Promise<any> {
    return this.transport.invoke('phone.openExternalBrowser', { url });
  }
}
