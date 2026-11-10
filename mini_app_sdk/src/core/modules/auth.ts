import { ITransport } from '../../transport/index.js';
import { AccessTokenResult, AuthLoginOptions, AuthLoginResult, MiniAppTokenResult, UserProfile } from '../types/index.js';

export interface PkceEntry {
  verifier: string;
  createdAt: number;
  expiresAt: number;
  timer?: any;
}

export interface PkceStoreConfig {
  defaultTtlMs?: number;
  maxPendingSessions?: number;
}

/**
 * PkceVerifierStore enforces lifecycle constraints on generated PKCE code verifiers:
 * 1. Time-To-Live (TTL): Automatically evicts and cleans up timers after expiry (default: 5 minutes).
 * 2. Capacity bounds: Caps pending verifier sessions (default: max 20) with FIFO eviction of oldest entries.
 * 3. Single-use consumption: Retrieving a verifier immediately burns it from the store.
 * 4. Explicit teardown: Cleans up all pending verifiers on logout, error, or SDK destruction.
 */
export class PkceVerifierStore {
  private entries: Map<string, PkceEntry> = new Map();
  private defaultTtlMs: number;
  private maxPendingSessions: number;

  constructor(config: PkceStoreConfig = {}) {
    this.defaultTtlMs = config.defaultTtlMs ?? 5 * 60 * 1000; // 5 minutes default
    this.maxPendingSessions = config.maxPendingSessions ?? 20; // max 20 pending requests
  }

  public set(authCode: string, verifier: string, ttlMs?: number): void {
    if (!authCode || !verifier) return;

    this.cleanExpired();

    // Enforce capacity bounds: evict oldest entry if limit reached
    if (this.entries.size >= this.maxPendingSessions) {
      const oldestKey = this.getOldestKey();
      if (oldestKey) {
        this.delete(oldestKey);
      }
    }

    const effectiveTtl = ttlMs && ttlMs > 0 ? ttlMs : this.defaultTtlMs;
    const now = Date.now();
    const expiresAt = now + effectiveTtl;

    const timer = setTimeout(() => {
      this.delete(authCode);
    }, effectiveTtl);

    if (timer && typeof timer === 'object' && typeof (timer as any).unref === 'function') {
      (timer as any).unref();
    }

    this.entries.set(authCode, {
      verifier,
      createdAt: now,
      expiresAt,
      timer,
    });
  }

  public get(authCode: string): string | undefined {
    const entry = this.entries.get(authCode);
    if (!entry) return undefined;

    if (Date.now() > entry.expiresAt) {
      this.delete(authCode);
      return undefined;
    }

    return entry.verifier;
  }

  public consume(authCode: string): string | undefined {
    const entry = this.entries.get(authCode);
    if (!entry) return undefined;

    this.delete(authCode);

    if (Date.now() > entry.expiresAt) {
      return undefined;
    }

    return entry.verifier;
  }

  public delete(authCode: string): boolean {
    const entry = this.entries.get(authCode);
    if (!entry) return false;

    if (entry.timer) {
      clearTimeout(entry.timer);
    }
    return this.entries.delete(authCode);
  }

  public has(authCode: string): boolean {
    const entry = this.entries.get(authCode);
    if (!entry) return false;

    if (Date.now() > entry.expiresAt) {
      this.delete(authCode);
      return false;
    }

    return true;
  }

  public size(): number {
    this.cleanExpired();
    return this.entries.size;
  }

  public clear(): void {
    for (const entry of this.entries.values()) {
      if (entry.timer) {
        clearTimeout(entry.timer);
      }
    }
    this.entries.clear();
  }

  private cleanExpired(): void {
    const now = Date.now();
    for (const [key, entry] of this.entries.entries()) {
      if (now > entry.expiresAt) {
        if (entry.timer) clearTimeout(entry.timer);
        this.entries.delete(key);
      }
    }
  }

  private getOldestKey(): string | undefined {
    let oldestKey: string | undefined;
    let oldestTime = Infinity;
    for (const [key, entry] of this.entries.entries()) {
      if (entry.createdAt < oldestTime) {
        oldestTime = entry.createdAt;
        oldestKey = key;
      }
    }
    return oldestKey;
  }
}

export const pkceStore = new PkceVerifierStore();

function url64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export class AuthModule {
  constructor(private transport: ITransport) {}

  public async requestCode(options: { codeChallenge?: string; scopes?: string[] } = {}): Promise<{
    authCode: string;
    expiresIn: number;
    appId: string;
    scopes: string[];
  }> {
    let challenge = options.codeChallenge;
    if (!challenge) {
      const verifier = url64(crypto.getRandomValues(new Uint8Array(32)));
      challenge = url64(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))));
      const result = await this.transport.invoke<{ authCode: string; expiresIn: number; appId: string; scopes: string[] }>(
        'auth.requestCode',
        { codeChallenge: challenge, codeChallengeMethod: 'S256', scopes: options.scopes || ['user.getBasicInfo'] }
      );

      const ttlMs = result.expiresIn && result.expiresIn > 0 && result.expiresIn <= 3600
        ? result.expiresIn * 1000
        : undefined;

      pkceStore.set(result.authCode, verifier, ttlMs);
      return result;
    }

    return this.transport.invoke('auth.requestCode', {
      ...options,
      codeChallenge: challenge,
      codeChallengeMethod: 'S256',
    });
  }

  public async exchangeCode(options: { authCode: string; codeVerifier?: string }): Promise<MiniAppTokenResult> {
    const codeVerifier = options.codeVerifier || pkceStore.consume(options.authCode);
    if (!codeVerifier) {
      throw { code: 'INVALID_PARAMS', message: 'Request a PKCE auth code first or provide codeVerifier' };
    }

    try {
      const result = await this.transport.invoke<MiniAppTokenResult>('auth.exchangeCode', {
        authCode: options.authCode,
        codeVerifier,
      });
      return result;
    } catch (error) {
      pkceStore.delete(options.authCode);
      throw error;
    } finally {
      pkceStore.delete(options.authCode);
    }
  }

  /**
   * Yêu cầu người dùng đăng nhập & cấp quyền truy cập
   */
  public async login(options: AuthLoginOptions = {}): Promise<AuthLoginResult> {
    return this.transport.invoke<AuthLoginResult>('auth.login', options);
  }

  /**
   * Lấy Access Token hiện tại
   */
  public async getAccessToken(): Promise<AccessTokenResult> {
    return this.transport.invoke<AccessTokenResult>('auth.getAccessToken');
  }

  /**
   * Lấy thông tin hồ sơ người dùng
   */
  public async getUserProfile(): Promise<UserProfile> {
    return this.transport.invoke<UserProfile>('auth.getUserProfile');
  }

  /**
   * Làm mới Access Token
   */
  public async refreshToken(refreshToken?: string): Promise<AccessTokenResult> {
    return this.transport.invoke<AccessTokenResult>('auth.refreshToken', { refreshToken });
  }

  /**
   * Đăng xuất phiên làm việc hiện tại và hủy toàn bộ phiên PKCE đang chờ
   */
  public async logout(): Promise<{ status: string; timestamp: string }> {
    try {
      return await this.transport.invoke<{ status: string; timestamp: string }>('auth.logout');
    } finally {
      pkceStore.clear();
    }
  }

  public destroy(): void {
    pkceStore.clear();
  }

  public dispose(): void {
    this.destroy();
  }
}

export class AuthBackend {
  constructor(private transport: ITransport) {}

  public async exchangeCode(authCode: string): Promise<MiniAppTokenResult> {
    const codeVerifier = pkceStore.consume(authCode);
    if (!codeVerifier) throw { code: 'INVALID_PARAMS', message: 'Request a PKCE auth code first' };
    try {
      const result = await this.transport.invoke<MiniAppTokenResult>('auth.exchangeCode', { authCode, codeVerifier });
      return result;
    } finally {
      pkceStore.delete(authCode);
    }
  }

  public refreshToken(refreshToken: string): Promise<MiniAppTokenResult> {
    return this.transport.invoke('auth.refreshToken', { refreshToken });
  }

  public destroy(): void {
    pkceStore.clear();
  }

  public dispose(): void {
    this.destroy();
  }
}
