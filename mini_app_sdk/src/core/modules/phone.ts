import { ITransport } from '../../transport/index.js';

export class PhoneModule {
  constructor(private transport: ITransport) {}

  /**
   * Mở trình gọi điện thoại native
   */
  public async openPhone(phoneNumber: string): Promise<any> {
    return this.transport.invoke('phone.openPhone', { phoneNumber });
  }

  /**
   * Mở trình nhắn tin SMS native
   */
  public async openSMS(phoneNumber: string, body?: string): Promise<any> {
    return this.transport.invoke('phone.openSMS', { phoneNumber, body });
  }

  /**
   * Mở liên kết trên trình duyệt ngoài (Safari / Chrome)
   */
  public async openExternalBrowser(url: string): Promise<any> {
    return this.transport.invoke('phone.openExternalBrowser', { url });
  }

  /**
   * Mở Deep Link trong hệ sinh thái ứng dụng
   */
  public async openDeepLink(url: string): Promise<any> {
    return this.transport.invoke('phone.openDeepLink', { url });
  }
}
