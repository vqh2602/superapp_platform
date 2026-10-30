import { ITransport } from '../../transport/index.js';

export class StorageModule {
  constructor(private transport: ITransport) {}

  /**
   * Lưu trữ dữ liệu cách ly theo Mini App
   */
  public async setItem(key: string, value: any): Promise<any> {
    const serialized = typeof value === 'string' ? value : JSON.stringify(value);
    return this.transport.invoke('storage.setItem', { key, value: serialized });
  }

  /**
   * Lấy dữ liệu đã lưu
   */
  public async getItem(key: string): Promise<{key: string; value: string | null; exists: boolean; domain: string; securityLevel: string}> {
    return this.transport.invoke('storage.getItem', { key });
  }

  /**
   * Xoá một khoá lưu trữ
   */
  public async removeItem(key: string): Promise<any> {
    return this.transport.invoke('storage.removeItem', { key });
  }

  /**
   * Xoá toàn bộ dữ liệu của Mini App
   */
  public async clear(): Promise<any> {
    return this.transport.invoke('storage.clear');
  }

  /**
   * Lấy toàn bộ cặp key-value
   */
  public async getAll(): Promise<Record<string, string>> {
    return this.transport.invoke<Record<string, string>>('storage.getAll');
  }
}
