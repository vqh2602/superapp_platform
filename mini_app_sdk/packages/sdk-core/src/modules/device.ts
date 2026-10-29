import { ITransport } from '@superapp/sdk-transport';
import { BatteryInfo, DeviceInfo, KeepScreenOptions, NetworkInfo } from '../types/index.js';

export class DeviceModule {
  constructor(private transport: ITransport) {}

  /**
   * Lấy mức pin và trạng thái sạc
   */
  public async getBatteryInfo(): Promise<BatteryInfo> {
    return this.transport.invoke<BatteryInfo>('device.getBatteryInfo');
  }

  /**
   * Lấy trạng thái mạng kết nối (WiFi, 4G, 5G, Offline)
   */
  public async getNetworkInfo(): Promise<NetworkInfo> {
    return this.transport.invoke<NetworkInfo>('device.getNetworkInfo');
  }

  /**
   * Lấy thông số thiết bị và màn hình
   */
  public async getDeviceInfo(): Promise<DeviceInfo> {
    return this.transport.invoke<DeviceInfo>('device.getDeviceInfo');
  }

  /**
   * Lấy thông số hệ điều hành
   */
  public async getSystemInfo(): Promise<DeviceInfo> {
    return this.transport.invoke<DeviceInfo>('device.getSystemInfo');
  }

  /**
   * Kích hoạt rung phản hồi xúc giác (Haptic Feedback)
   */
  public async vibrate(style: 'light' | 'medium' | 'heavy' = 'light'): Promise<void> {
    await this.transport.invoke('device.vibrate', { style });
  }

  /**
   * Giữ màn hình luôn bật / luôn sáng
   */
  public async keepScreen(options?: KeepScreenOptions | boolean): Promise<{ success: boolean; keepScreenOn: boolean }> {
    const payload = typeof options === 'boolean'
      ? { keepScreenOn: options }
      : (options || { keepScreenOn: true });
    return this.transport.invoke<{ success: boolean; keepScreenOn: boolean }>('device.keepScreen', payload);
  }
}
