import { ITransport } from '../../transport/index.js';
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
  public async showToast(options: ToastOptions | string): Promise<any> {
    const payload = typeof options === 'string' ? { message: options } : options;
    return this.transport.invoke('ui.showToast', payload);
  }

  /**
   * Hiển thị hộp thoại cảnh báo (Alert Dialog)
   */
  public async showAlert(options: AlertOptions): Promise<any> {
    return this.transport.invoke('ui.showAlert', options);
  }

  /**
   * Hiển thị hộp thoại xác nhận (Confirm Dialog)
   */
  public async showConfirm(options: ConfirmOptions): Promise<{ confirmed: boolean }> {
    return this.transport.invoke<{ confirmed: boolean }>('ui.showConfirm', options);
  }

  /**
   * Đặt lại tiêu đề trên thanh điều hướng của trang hiện tại
   */
  public async setNavigationBarTitle(title: string | { title: string }): Promise<any> {
    const payload = typeof title === 'string' ? { title } : title;
    return this.transport.invoke('ui.setNavigationBarTitle', payload);
  }

  /**
   * Cấu hình hợp nhất giao diện: Ẩn/hiện, tuỳ chỉnh màu sắc, kiểu hiển thị của status bar, action bar, bottom navigation
   * (Thay thế cho setStatusBarStyle, setStatusBarColor, setNavigationBarColor)
   */
  public async configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.transport.invoke('ui.configAppView', options);
  }

  /**
   * @deprecated Gộp chung vào configAppView({ headerColor: ... })
   */
  public async setNavigationBarColor(options: SetNavigationBarColorOptions | string): Promise<any> {
    const payload: ConfigAppViewOptions = typeof options === 'string'
      ? { headerColor: options }
      : {
          headerColor: options.color,
          textColor: options.textColor,
          statusBarColor: options.statusBarColor,
        };
    return this.configAppView(payload);
  }

  /**
   * @deprecated Gộp chung vào configAppView({ statusBarColor: color })
   */
  public async setStatusBarColor(color: string): Promise<any> {
    return this.configAppView({ statusBarColor: color });
  }

  /**
   * @deprecated Gộp chung vào configAppView({ statusBar: style, textColor: ... })
   */
  public async setStatusBarStyle(style: 'light' | 'dark'): Promise<any> {
    return this.configAppView({ statusBar: style, textColor: style === 'light' ? 'white' : 'black' });
  }

  /**
   * Yêu cầu người dùng cho phép ứng dụng gửi thông báo qua Official Account / Mini App Channel
   */
  public async requestSendNotification(options: RequestSendNotificationOptions = {}): Promise<NotificationResult> {
    return this.transport.invoke<NotificationResult>('ui.requestSendNotification', options);
  }
}
