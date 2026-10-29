import { ITransport } from '../../transport/index.js';
import { ChooseImageOptions, ChooseImageResult, QRCodeResult } from '../types/index.js';

export class MediaModule {
  constructor(private transport: ITransport) {}

  /**
   * Quét mã QR Code bằng camera của SuperApp
   */
  public async scanQRCode(prompt?: string): Promise<QRCodeResult> {
    return this.transport.invoke<QRCodeResult>('media.scanQRCode', { prompt });
  }

  /**
   * Chọn ảnh từ thư viện thiết bị
   */
  public async chooseImage(options: ChooseImageOptions = {}): Promise<ChooseImageResult> {
    return this.transport.invoke<ChooseImageResult>('media.chooseImage', options);
  }
}
