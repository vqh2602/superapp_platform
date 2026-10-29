import { BridgeTransport } from '../bridgeTransport';

export interface ConfigAppViewOptions {
  headerColor?: string;
  headerTitle?: string;
  textColor?: 'white' | 'black';
  statusBar?: 'transparent' | 'hidden' | 'light' | 'dark';
  statusBarColor?: string;
  actionBarHidden?: boolean;
  hideAndroidBottomNavigationBar?: boolean;
  hideStatusBar?: boolean;
  hideNavigationBar?: boolean;
  hasPadding?: boolean;
  hasPaddingTop?: boolean;
  hasPaddingBottom?: boolean;
  safeAreaTop?: boolean;
  safeAreaBottom?: boolean;
  safeArea?: boolean | { top?: boolean; bottom?: boolean };
  bottomNavColor?: string;
  header?: {
    color?: string;
    title?: string;
    textColor?: 'white' | 'black';
    hidden?: boolean;
  };
  bottomNav?: {
    color?: string;
    hidden?: boolean;
  };
}

export interface SetNavigationBarColorOptions {
  color: string;
  textColor?: 'white' | 'black';
  statusBarColor?: string;
}

export class UIModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Hiển thị thông báo ngắn (toast) ở đáy màn hình
   */
  public async showToast(message: string, duration: number = 2000): Promise<{ success: boolean; message: string }> {
    return this.transport.invoke('showToast', { message, duration });
  }

  /**
   * Hiển thị hộp thoại cảnh báo (alert)
   */
  public async showAlert(options: { title?: string; message: string; buttonText?: string }): Promise<{ success: boolean }> {
    return this.transport.invoke('ui.showAlert', options);
  }

  /**
   * Hiển thị hộp thoại xác nhận (confirm)
   */
  public async showConfirm(options: { title?: string; message: string; confirmText?: string; cancelText?: string }): Promise<{ confirmed: boolean }> {
    return this.transport.invoke('ui.showConfirm', options);
  }

  /**
   * Đặt lại tiêu đề trên thanh điều hướng của trang hiện tại
   */
  public async setNavigationBarTitle(title: string | { title: string }): Promise<{ success: boolean; title: string }> {
    const payload = typeof title === 'string' ? { title } : title;
    return this.transport.invoke('setNavigationBarTitle', payload);
  }

  /**
   * Rung thiết bị (haptic feedback)
   */
  public async vibrate(style: 'light' | 'medium' | 'heavy' = 'medium'): Promise<{ success: boolean; style: string }> {
    return this.transport.invoke('vibrate', { style });
  }

  /**
   * Sao chép văn bản vào clipboard
   */
  public async copyToClipboard(text: string): Promise<{ success: boolean; length: number }> {
    return this.transport.invoke('copyToClipboard', { text });
  }

  /**
   * Đặt độ sáng màn hình (0.0 đến 1.0)
   */
  public async setBrightness(brightness: number): Promise<{ success: boolean; brightness: number }> {
    return this.transport.invoke('setBrightness', { brightness });
  }

  /**
   * Cấu hình hợp nhất navigation bar, header và status bar (Zalo-compatible)
   * Thay thế cho setStatusBarStyle, setStatusBarColor, setNavigationBarColor
   */
  public async configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.transport.invoke('configAppView', options);
  }

  /**
   * @deprecated Gộp chung vào configAppView({ statusBar: style, textColor: ... })
   */
  public async setStatusBarStyle(style: 'light' | 'dark'): Promise<any> {
    return this.configAppView({ statusBar: style, textColor: style === 'light' ? 'white' : 'black' });
  }

  /**
   * @deprecated Gộp chung vào configAppView({ statusBarColor: color })
   */
  public async setStatusBarColor(color: string): Promise<any> {
    return this.configAppView({ statusBarColor: color });
  }

  /**
   * @deprecated Gộp chung vào configAppView({ headerColor: ... })
   */
  public async setNavigationBarColor(options: string | SetNavigationBarColorOptions): Promise<any> {
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
   * Yêu cầu người dùng cho phép ứng dụng gửi thông báo qua Official Account / Mini App Channel
   */
  public async requestSendNotification(options: { templateId?: string; reason?: string } = {}): Promise<any> {
    return this.transport.invoke('ui.requestSendNotification', options);
  }

  /**
   * Hiển thị menu hành động mặc định của shell
   */
  public async showMiniappMenu(): Promise<{ success: boolean; action: string }> {
    return this.transport.invoke('showMiniappMenu');
  }
}
