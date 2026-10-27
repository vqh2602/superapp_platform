import { BridgeTransport } from '../bridgeTransport';

export class UtilityModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Mở dialog ghi âm, chuyển giọng nói thành văn bản (cần quyền 'microphone')
   */
  public async speechToText(options: { lang?: string } = {}): Promise<{
    text: string;
    confidence: number;
    lang?: string;
    timestamp: number;
  }> {
    return this.transport.invoke('speechToText', options);
  }

  /**
   * Ẩn bàn phím đang hiện (nếu có)
   */
  public async hideKeyboard(): Promise<{ success: boolean; hidden: boolean }> {
    return this.transport.invoke('hideKeyboard');
  }
}
