import { ITransport } from '../../transport/index.js';

export type ShareOptions = (
  | { text: string; url?: string }
  | { text?: string; url: string }
) & { title?: string; subject?: string };

export interface ShareResult {
  status: 'success' | 'dismissed' | 'unavailable';
}

export class UtilityModule {
  constructor(private transport: ITransport) {}

  /** Mở bảng chia sẻ hệ thống với văn bản hoặc liên kết HTTP(S). */
  public share(options: ShareOptions): Promise<ShareResult> {
    return this.transport.invoke('utility.share', options);
  }

  /**
   * Nhận diện giọng nói thành văn bản
   */
  public async speechToText(options: { lang?: string } = {}): Promise<{
    text: string;
    confidence?: number;
    lang: string;
  }> {
    return this.transport.invoke('utility.speechToText', options);
  }

  /**
   * Ẩn bàn phím ảo trên màn hình
   */
  public async hideKeyboard(): Promise<{ success: boolean; hidden: boolean }> {
    return this.transport.invoke('utility.hideKeyboard');
  }
}
