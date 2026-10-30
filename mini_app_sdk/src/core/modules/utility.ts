import { ITransport } from '../../transport/index.js';

export class UtilityModule {
  constructor(private transport: ITransport) {}

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
