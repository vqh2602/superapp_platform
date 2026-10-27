import { BridgeTransport } from '../bridgeTransport';

export class PhoneModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Mở màn hình quay số điện thoại
   */
  public async openPhone(phoneNumber: string): Promise<{ success: boolean; phoneNumber: string; launched?: boolean }> {
    return this.transport.invoke('openPhone', { phoneNumber });
  }

  /**
   * Mở app nhắn tin SMS với số điện thoại & nội dung có sẵn
   */
  public async openSMS(
    phoneNumber: string,
    body?: string
  ): Promise<{ success: boolean; phoneNumber: string; body?: string; launched?: boolean }> {
    return this.transport.invoke('openSMS', { phoneNumber, body });
  }

  /**
   * Mở URL bằng trình duyệt ngoài (Safari/Chrome), rời khỏi SuperApp
   */
  public async openExternalBrowser(url: string): Promise<{ success: boolean; url: string; mode: string; launched?: boolean }> {
    return this.transport.invoke('openExternalBrowser', { url });
  }

  /**
   * Mở deep link / URL trong trình duyệt in-app của SuperApp
   */
  public async openDeepLink(url: string): Promise<{ success: boolean; url: string; mode: string; launched?: boolean }> {
    return this.transport.invoke('openDeepLink', { url });
  }
}
