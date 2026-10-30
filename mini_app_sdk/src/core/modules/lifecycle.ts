import { ITransport } from '../../transport/index.js';

export type LifecycleListener = (data?: any) => void;

export class LifecycleModule {
  constructor(private transport: ITransport) {}

  /**
   * Đăng ký lắng nghe sự kiện bất kỳ từ SuperApp
   */
  public on(event: string, callback: (payload: any) => void): () => void {
    return this.transport.on(event, callback);
  }

  /**
   * Huỷ lắng nghe sự kiện
   */
  public off(event: string, callback: (payload: any) => void): void {
    this.transport.off(event, callback);
  }

  /**
   * Phát sự kiện trong Mini App
   */
  public emit(event: string, payload: any): void {
    this.transport.emit(event, payload);
  }

  /**
   * Đăng ký lắng nghe sự kiện khi Mini App hiển thị ra màn hình chính (Foreground)
   */
  public onAppShow(callback: LifecycleListener): () => void {
    return this.transport.on('appShow', callback);
  }

  /**
   * Đăng ký lắng nghe sự kiện khi Mini App bị ẩn xuống nền (Background)
   */
  public onAppHide(callback: LifecycleListener): () => void {
    return this.transport.on('appHide', callback);
  }

  /**
   * Đăng ký lắng nghe lỗi hệ thống
   */
  public onError(callback: LifecycleListener): () => void {
    return this.transport.on('appError', callback);
  }

  /**
   * Lắng nghe sự kiện thay đổi phiên đăng nhập (login / logout)
   */
  public onSessionChanged(callback: (payload: { state: 'logged_in' | 'logged_out'; userId?: string }) => void): () => void {
    return this.transport.on('auth.sessionChanged', callback);
  }

  /**
   * Lắng nghe trạng thái thanh toán đơn hàng cập nhật
   */
  public onPaymentStatusChanged(callback: (payload: any) => void): () => void {
    return this.transport.on('payment.statusChanged', callback);
  }
}
