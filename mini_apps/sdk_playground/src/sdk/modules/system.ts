import { BridgeTransport } from '../bridgeTransport';

export class SystemModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Lấy thông tin kết nối mạng hiện tại (wifi, cellular, none)
   */
  public async getNetworkInfo(): Promise<{
    networkType: string;
    isConnected: boolean;
    signalStrength?: string;
    ipAddress?: string;
  }> {
    return this.transport.invoke('getNetworkInfo');
  }

  /**
   * Lấy thông tin ngôn ngữ và khu vực thiết bị
   */
  public async getDeviceLanguage(): Promise<{
    language: string;
    languageCode: string;
    countryCode?: string;
    locale: string;
  }> {
    return this.transport.invoke('getDeviceLanguage');
  }

  /**
   * Lấy cấu hình giao diện từ Super App shell (theme, timezone, language...)
   */
  public async getSuperAppSettings(): Promise<{
    theme: string;
    language: string;
    timezone: string;
    gmtOffset: string;
    appName: string;
    shellVersion?: string;
  }> {
    return this.transport.invoke('getSuperAppSettings');
  }

  /**
   * Lấy thông tin phần cứng và hệ điều hành thiết bị
   */
  public async getSystemInfo(): Promise<{
    platform: string;
    osVersion: string;
    deviceModel: string;
    screenWidth: number;
    screenHeight: number;
    pixelRatio: number;
    brand?: string;
  }> {
    return this.transport.invoke('getSystemInfo');
  }

  /**
   * Lấy thông tin Mini App hiện tại theo manifest
   */
  public async getAppInfo(): Promise<{
    appId: string;
    name: string;
    version: string;
    category: string;
    runtimeType: string;
    description?: string;
  }> {
    return this.transport.invoke('getAppInfo');
  }

  /**
   * Lấy thông tin pin thiết bị
   */
  public async getBatteryInfo(): Promise<{
    level: number;
    isCharging: boolean;
    status?: string;
  }> {
    return this.transport.invoke('getBatteryInfo');
  }

  /**
   * Lấy danh sách danh bạ máy (yêu cầu quyền 'contacts')
   */
  public async getContacts(): Promise<{
    contacts: Array<{
      id: string;
      name: string;
      phone: string;
      email?: string;
      department?: string;
    }>;
    total: number;
  }> {
    return this.transport.invoke('getContacts');
  }

  /**
   * Đóng Mini App và quay lại Launcher
   */
  public async closeApp(): Promise<{ success: boolean; message: string }> {
    return this.transport.invoke('closeApp');
  }
}
