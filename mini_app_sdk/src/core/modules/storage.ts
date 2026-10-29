import { ITransport } from '../../transport/index.js';

export class StorageModule {
  constructor(private transport: ITransport) {}

  /**
   * Lưu trữ dữ liệu cách ly theo Mini App
   */
  public async setItem(key: string, value: any): Promise<void> {
    const serialized = typeof value === 'string' ? value : JSON.stringify(value);
    await this.transport.invoke('storage.setItem', { key, value: serialized });
  }

  /**
   * Lấy dữ liệu đã lưu
   */
  public async getItem<T = any>(key: string): Promise<T | null> {
    const res = await this.transport.invoke<{ key: string; value: string | null }>('storage.getItem', { key });
    if (!res || res.value === null) return null;
    try {
      return JSON.parse(res.value) as T;
    } catch {
      return res.value as unknown as T;
    }
  }

  /**
   * Xoá một khoá lưu trữ
   */
  public async removeItem(key: string): Promise<void> {
    await this.transport.invoke('storage.removeItem', { key });
  }

  /**
   * Xoá toàn bộ dữ liệu của Mini App
   */
  public async clear(): Promise<void> {
    await this.transport.invoke('storage.clear');
  }

  /**
   * Lấy toàn bộ cặp key-value
   */
  public async getAll(): Promise<Record<string, string>> {
    return this.transport.invoke<Record<string, string>>('storage.getAll');
  }
}
