import { ITransport } from '../../transport/index.js';
import { ContactsResult, DeviceInfo, NetworkInfo } from '../types/index.js';

export class SystemModule {
  constructor(private transport: ITransport) {}

  /**
   * Lấy thông tin kết nối mạng hiện tại (wifi, cellular, none)
   */
  public async getNetworkInfo(): Promise<NetworkInfo> {
    return this.transport.invoke<NetworkInfo>('getNetworkInfo');
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
  public async getSystemInfo(): Promise<DeviceInfo> {
    return this.transport.invoke<DeviceInfo>('getSystemInfo');
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
  public async getContacts(options: { query?: string } = {}): Promise<ContactsResult> {
    return this.transport.invoke<ContactsResult>('getContacts', options);
  }

  /**
   * Đóng Mini App và quay lại Launcher
   */
  public async closeApp(): Promise<{ success: boolean; message: string }> {
    return this.transport.invoke('closeApp');
  }
}
