import { ITransport } from '../../transport/index.js';

export interface SecureStorageSetResult {
  key: string;
  domain: string;
  appId: string;
  success: boolean;
  securityLevel: string;
  updatedAt: string;
}

export interface SecureStorageGetResult {
  key: string;
  value: string | null;
  domain: string;
  exists: boolean;
  securityLevel: string;
}

export interface SecureStorageRemoveResult {
  key: string;
  domain: string;
  removed: boolean;
}

export interface SecureStorageClearResult {
  cleared: boolean;
  count: number;
}

export interface CredentialSetResult {
  domain: string;
  username: string;
  success: boolean;
  securityLevel: string;
  savedAt: string;
}

export interface CredentialGetResult {
  domain: string;
  username: string | null;
  password?: string | null;
  exists: boolean;
  securityLevel: string;
}

export interface CredentialDeleteResult {
  domain: string;
  deleted: boolean;
}

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
  public async clear(domain?: string): Promise<SecureStorageClearResult | any> {
    return this.transport.invoke('storage.clear', { domain });
  }

  /**
   * Lấy toàn bộ cặp key-value
   */
  public async getAll(): Promise<Record<string, string>> {
    return this.transport.invoke<Record<string, string>>('storage.getAll');
  }

  /**
   * Lưu cặp khóa - giá trị bảo mật (Keychain/Keystore) theo domain
   */
  public async setSecureItem(
    key: string,
    value: any,
    domain: string = 'default'
  ): Promise<SecureStorageSetResult> {
    const stringValue = typeof value === 'string' ? value : JSON.stringify(value);
    return this.transport.invoke('storage.setSecureItem', {
      key,
      value: stringValue,
      domain,
    });
  }

  /**
   * Lấy lại giá trị đã lưu theo khóa bảo mật (Keychain/Keystore)
   */
  public async getSecureItem(
    key: string,
    domain: string = 'default'
  ): Promise<SecureStorageGetResult> {
    return this.transport.invoke('storage.getSecureItem', {
      key,
      domain,
    });
  }

  /**
   * Xóa cặp khóa - giá trị bảo mật
   */
  public async removeSecureItem(
    key: string,
    domain: string = 'default'
  ): Promise<SecureStorageRemoveResult> {
    return this.transport.invoke('storage.removeSecureItem', {
      key,
      domain,
    });
  }

  /**
   * Lưu username/password an toàn (Keychain/Keystore) theo domain
   */
  public async setCredentials(
    domain: string,
    username: string,
    password: string
  ): Promise<CredentialSetResult> {
    return this.transport.invoke('storage.setCredentials', {
      domain,
      username,
      password,
    });
  }

  /**
   * Lấy lại username/password đã lưu an toàn theo domain
   */
  public async getCredentials(domain: string): Promise<CredentialGetResult> {
    return this.transport.invoke('storage.getCredentials', {
      domain,
    });
  }

  /**
   * Xoá username/password đã lưu an toàn theo domain
   */
  public async deleteCredentials(domain: string): Promise<CredentialDeleteResult> {
    return this.transport.invoke('storage.deleteCredentials', {
      domain,
    });
  }

  /**
   * Lưu dữ liệu nhạy cảm vào Keychain/Keystore (alias setSecretData)
   */
  public async setSecretData(key: string, value: any, domain: string = 'default'): Promise<SecureStorageSetResult> {
    return this.setSecureItem(key, value, domain);
  }

  /**
   * Đọc dữ liệu bảo mật đã lưu từ Keychain/Keystore (alias getSecretData)
   */
  public async getSecretData(key: string, domain: string = 'default'): Promise<SecureStorageGetResult> {
    return this.getSecureItem(key, domain);
  }

  /**
   * Xoá 1 khoá dữ liệu bảo mật (alias removeSecretData)
   */
  public async removeSecretData(key: string, domain: string = 'default'): Promise<SecureStorageRemoveResult> {
    return this.removeSecureItem(key, domain);
  }
}
