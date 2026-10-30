import { ITransport } from '../../transport/index.js';

export class PermissionsModule {
  constructor(private transport: ITransport) {}

  /**
   * Yêu cầu cấp quyền người dùng cho capability cụ thể (camera, location, contacts...)
   */
  public async request(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.request', { capability });
  }

  /**
   * Kiểm tra quyền đã được cấp hay chưa
   */
  public async check(capability: string): Promise<{ capability: string; granted: boolean }> {
    return this.transport.invoke('permission.check', { capability });
  }

  /**
   * Lấy toàn bộ danh sách trạng thái cấp quyền của Mini App
   */
  public async getAll(): Promise<Record<string, boolean>> {
    return this.transport.invoke('permission.getAll');
  }

  /**
   * Alias cho getAll()
   */
  public async getPermissions(): Promise<Record<string, boolean>> {
    return this.getAll();
  }
}
