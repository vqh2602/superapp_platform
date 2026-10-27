import { ITransport } from '@superapp/sdk-transport';
import { AlertOptions, ConfirmOptions, ToastOptions } from '../types/index.js';

export class UIModule {
  constructor(private transport: ITransport) {}

  /**
   * Hiển thị thông báo Toast nhanh
   */
  public async showToast(options: ToastOptions | string): Promise<void> {
    const payload = typeof options === 'string' ? { message: options } : options;
    await this.transport.invoke('ui.showToast', payload);
  }

  /**
   * Hiển thị hộp thoại cảnh báo (Alert Dialog)
   */
  public async showAlert(options: AlertOptions): Promise<void> {
    await this.transport.invoke('ui.showAlert', options);
  }

  /**
   * Hiển thị hộp thoại xác nhận (Confirm Dialog)
   */
  public async showConfirm(options: ConfirmOptions): Promise<boolean> {
    const res = await this.transport.invoke<{ confirmed: boolean }>('ui.showConfirm', options);
    return !!res?.confirmed;
  }

  /**
   * Đặt tiêu đề thanh điều hướng của Mini App
   */
  public async setNavigationBarTitle(title: string): Promise<void> {
    await this.transport.invoke('ui.setNavigationBarTitle', { title });
  }

  /**
   * Đổi màu nền thanh trạng thái (Status Bar)
   */
  public async setStatusBarColor(color: string): Promise<void> {
    await this.transport.invoke('ui.setStatusBarColor', { color });
  }
}
