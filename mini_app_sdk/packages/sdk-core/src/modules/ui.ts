import { ITransport } from '@superapp/sdk-transport';
import {
  AlertOptions,
  ConfigAppViewOptions,
  ConfirmOptions,
  NotificationResult,
  RequestSendNotificationOptions,
  SetNavigationBarColorOptions,
  ToastOptions,
} from '../types/index.js';

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
   * Đặt lại tiêu đề trên thanh điều hướng của trang hiện tại
   */
  public async setNavigationBarTitle(title: string | { title: string }): Promise<void> {
    const payload = typeof title === 'string' ? { title } : title;
    await this.transport.invoke('ui.setNavigationBarTitle', payload);
  }

  /**
   * Đặt lại màu nền & màu chữ/icon thanh điều hướng (Action Bar / Header)
   */
  public async setNavigationBarColor(options: SetNavigationBarColorOptions | string): Promise<void> {
    const payload = typeof options === 'string' ? { color: options } : options;
    await this.transport.invoke('ui.setNavigationBarColor', payload);
  }

  /**
   * Đổi màu nền thanh trạng thái (Status Bar)
   */
  public async setStatusBarColor(color: string): Promise<void> {
    await this.transport.invoke('ui.setStatusBarColor', { color });
  }

  /**
   * Ẩn/hiện, tuỳ chỉnh màu sắc, kiểu hiển thị của status bar, action bar, bottom navigation
   */
  public async configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.transport.invoke('ui.configAppView', options);
  }

  /**
   * Yêu cầu người dùng cho phép ứng dụng gửi thông báo qua Official Account / Mini App Channel
   */
  public async requestSendNotification(options: RequestSendNotificationOptions = {}): Promise<NotificationResult> {
    return this.transport.invoke<NotificationResult>('ui.requestSendNotification', options);
  }
}
