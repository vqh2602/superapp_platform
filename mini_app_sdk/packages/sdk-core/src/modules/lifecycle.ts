import { ITransport } from '@superapp/sdk-transport';

export type LifecycleListener = (data?: any) => void;

export class LifecycleModule {
  constructor(private transport: ITransport) {}

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
}
