import { MockStateStore } from '../store.js';

export class DeviceMockHandler {
  constructor(private store: MockStateStore) {}

  public async getBatteryInfo(): Promise<any> {
    const dev = this.store.getDeviceState();
    return {
      batteryLevel: dev.batteryLevel,
      isCharging: dev.isCharging,
    };
  }

  public async getNetworkInfo(): Promise<any> {
    const net = this.store.getNetworkCondition();
    return {
      isConnected: net.online,
      networkType: net.type,
      isWifi: net.type === 'wifi',
      isMobile: net.type === '4g' || net.type === '5g' || net.type === '2g',
    };
  }

  public async getDeviceInfo(): Promise<any> {
    const dev = this.store.getDeviceState();
    return {
      model: dev.model,
      platform: dev.platform,
      systemName: dev.systemName,
      systemVersion: dev.systemVersion,
      language: dev.language,
      screenWidth: 390,
      screenHeight: 844,
      pixelRatio: 3,
    };
  }

  public async getSystemInfo(): Promise<any> {
    return this.getDeviceInfo();
  }

  public async vibrate(payload: { style?: 'light' | 'medium' | 'heavy' } = {}): Promise<any> {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      try {
        const pattern = payload.style === 'heavy' ? 80 : payload.style === 'medium' ? 40 : 15;
        navigator.vibrate(pattern);
      } catch (_) {}
    }
    return { success: true, style: payload.style || 'light' };
  }

  public async keepScreen(payload: { keepScreenOn?: boolean } = {}): Promise<any> {
    const keepScreenOn = payload.keepScreenOn !== false;
    return { success: true, keepScreenOn };
  }
}
