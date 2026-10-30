import { ITransport } from '../../transport/index.js';

export class UserModule {
  constructor(private transport: ITransport) {}

  /**
   * Lấy toàn bộ thông tin tài khoản người dùng
   */
  public async getProfile(): Promise<any> {
    return this.transport.invoke('user.getProfile');
  }

  /**
   * Lấy thông tin cơ bản công khai của người dùng (tên, avatar)
   */
  public async getBasicInfo(): Promise<{ id: string; name: string; avatarUrl?: string }> {
    return this.transport.invoke('user.getBasicInfo');
  }
}
