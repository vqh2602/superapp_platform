import { MockStateStore } from '../store.js';

export class StorageMockHandler {
  constructor(private store: MockStateStore) {}

  public async getItem(appId: string, payload: { key: string }): Promise<any> {
    if (!payload?.key) {
      throw { code: 'INVALID_KEY', message: 'Storage key is required' };
    }
    const val = this.store.getStorageItem(appId, payload.key);
    return { key: payload.key, value: val };
  }

  public async setItem(appId: string, payload: { key: string; value: string }): Promise<any> {
    if (!payload?.key) {
      throw { code: 'INVALID_KEY', message: 'Storage key is required' };
    }
    this.store.setStorageItem(appId, payload.key, String(payload.value));
    return { success: true, key: payload.key };
  }

  public async removeItem(appId: string, payload: { key: string }): Promise<any> {
    if (!payload?.key) {
      throw { code: 'INVALID_KEY', message: 'Storage key is required' };
    }
    this.store.removeStorageItem(appId, payload.key);
    return { success: true, key: payload.key };
  }

  public async clear(appId: string): Promise<any> {
    this.store.clearStorage(appId);
    return { success: true };
  }

  public async getAll(appId: string): Promise<any> {
    const map = this.store.getStorage(appId);
    const obj: Record<string, string> = {};
    map.forEach((v, k) => {
      obj[k] = v;
    });
    return obj;
  }
}
