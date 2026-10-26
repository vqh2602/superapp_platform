import { BridgeTransport } from '../bridgeTransport';

export class DeviceModule {
  constructor(private transport: BridgeTransport) {}

  public async scanQRCode(): Promise<{ content: string; format: string; timestamp: number; isMock: boolean }> {
    return this.transport.invoke('device.scanQRCode');
  }

  public async getLocation(): Promise<{
    latitude: number;
    longitude: number;
    city?: string;
    country?: string;
    accuracy?: number;
    timestamp: number;
    isMock: boolean;
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
    isMock: boolean;
  }> {
    return this.transport.invoke('device.pickImage');
  }
}
