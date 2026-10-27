import { BridgeTransport } from '../bridgeTransport';

export class UIModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Hiển thị thông báo ngắn (toast) ở đáy màn hình
   */
  public async showToast(message: string, duration: number = 2000): Promise<{ success: boolean; message: string }> {
    return this.transport.invoke('showToast', { message, duration });
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
   * Mini App tự báo màu icon status bar phù hợp với nền (light/dark)
   */
  public async setStatusBarStyle(style: 'light' | 'dark'): Promise<{ success: boolean; style: string }> {
    return this.transport.invoke('setStatusBarStyle', { style });
  }

  /**
   * Đổi màu nền của status bar
   */
  public async setStatusBarColor(color: string): Promise<{ success: boolean; color: string }> {
    return this.transport.invoke('setStatusBarColor', { color });
  }

  /**
   * Đổi màu thanh navigation bar
   */
  public async setNavigationBarColor(color: string): Promise<{ success: boolean; color: string }> {
    return this.transport.invoke('setNavigationBarColor', { color });
  }

  /**
   * Cấu hình hiển thị navigation bar và status bar
   */
  public async configAppView(options: {
    hideStatusBar?: boolean;
    hideNavigationBar?: boolean;
  }): Promise<{ success: boolean; hideStatusBar: boolean; hideNavigationBar: boolean }> {
    return this.transport.invoke('configAppView', options);
  }

  /**
   * Hiển thị menu hành động mặc định của shell
   */
  public async showMiniappMenu(): Promise<{ success: boolean; action: string }> {
    return this.transport.invoke('showMiniappMenu');
  }
}
