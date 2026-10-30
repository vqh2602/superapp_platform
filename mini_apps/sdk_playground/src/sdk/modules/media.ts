import { BridgeTransport } from '../bridgeTransport';

export class MediaModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Quét mã QR và Mã vạch (EAN-13, Code-128, QR Code...) bằng camera hoặc ảnh
   */
  public async scanQr(options: { formats?: string[] } = {}): Promise<{
    content: string;
    format: string;
    timestamp: number;
  }> {
    return this.transport.invoke('scanQr', options);
  }

  /**
   * Chụp ảnh từ camera hoặc chọn 1 ảnh từ thư viện
   */
  public async getPhoto(options: { source?: 'camera' | 'gallery' } = {}): Promise<{
    uri: string;
    mimeType: string;
    source: string;
    width: number;
    height: number;
    sizeBytes: number;
  }> {
    return this.transport.invoke('getPhoto', options);
  }

  /**
   * Chọn nhiều ảnh từ thư viện
   */
  public async pickImages(options: { maxCount?: number } = {}): Promise<{
    images: Array<{
      uri: string;
      mimeType: string;
      width: number;
      height: number;
      sizeBytes: number;
      fileName: string;
    }>;
    count: number;
  }> {
    return this.transport.invoke('pickImages', options);
  }

  /**
   * Lưu 1 ảnh vào thư viện ảnh máy
   */
  public async saveImageToGallery(uri: string): Promise<{ success: boolean; savedUri: string }> {
    return this.transport.invoke('saveImageToGallery', { uri });
  }

  /**
   * Chọn 1 video từ thư viện
   */
  public async pickVideo(): Promise<{
    uri: string;
    mimeType: string;
    durationSec: number;
    sizeBytes: number;
    fileName: string;
    width: number;
    height: number;
  }> {
    return this.transport.invoke('pickVideo');
  }

  /**
   * Lưu video vào thư viện máy
   */
  public async saveVideoToGallery(uri: string): Promise<{ success: boolean; savedUri: string }> {
    return this.transport.invoke('saveVideoToGallery', { uri });
  }
}
