import { BridgeTransport } from '../bridgeTransport';

export class DeviceModule {
  constructor(private transport: BridgeTransport) {}

  public async scanQRCode(): Promise<{ content: string; format: string; timestamp: number }> {
    return this.transport.invoke('device.scanQRCode');
  }

  public async getLocation(): Promise<{
    latitude: number;
    longitude: number;
    city?: string;
    country?: string;
    accuracy?: number;
    timestamp: number;
  }> {
    return this.transport.invoke('device.getLocation');
  }

  public async pickImage(): Promise<{
    uri: string;
    mimeType: string;
    width: number;
    height: number;
    sizeBytes: number;
    fileName: string;
    timestamp: number;
  }> {
    return this.transport.invoke('device.pickImage');
  }

  /**
   * Giữ màn hình luôn sáng / bật hoặc cho phép tắt
   */
  public async keepScreen(options: boolean | { keepScreenOn: boolean } = true): Promise<{ success: boolean; keepScreenOn: boolean }> {
    const payload = typeof options === 'boolean' ? { keepScreenOn: options } : options;
    return this.transport.invoke('keepScreen', payload);
  }
}
