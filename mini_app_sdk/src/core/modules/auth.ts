import { ITransport } from '../../transport/index.js';
import { AccessTokenResult, AuthLoginOptions, AuthLoginResult, MiniAppTokenResult, UserProfile } from '../types/index.js';

const verifiers = new Map<string, string>();

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
      verifiers.set(result.authCode, verifier);
      return result;
    }

    return this.transport.invoke('auth.requestCode', {
      ...options,
      codeChallenge: challenge,
      codeChallengeMethod: 'S256',
    });
  }

  public async exchangeCode(options: { authCode: string; codeVerifier?: string }): Promise<MiniAppTokenResult> {
    const codeVerifier = options.codeVerifier || verifiers.get(options.authCode);
    if (!codeVerifier) {
      throw { code: 'INVALID_PARAMS', message: 'Request a PKCE auth code first or provide codeVerifier' };
    }
    const result = await this.transport.invoke<MiniAppTokenResult>('auth.exchangeCode', {
      authCode: options.authCode,
      codeVerifier,
    });
    verifiers.delete(options.authCode);
    return result;
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
   * Đăng xuất phiên làm việc hiện tại
   */
  public async logout(): Promise<{ status: string; timestamp: string }> {
    return this.transport.invoke<{ status: string; timestamp: string }>('auth.logout');
  }
}

export class AuthBackend {
  constructor(private transport: ITransport) {}

  public async exchangeCode(authCode: string): Promise<MiniAppTokenResult> {
    const codeVerifier = verifiers.get(authCode);
    if (!codeVerifier) throw { code: 'INVALID_PARAMS', message: 'Request a PKCE auth code first' };
    const result = await this.transport.invoke<MiniAppTokenResult>('auth.exchangeCode', { authCode, codeVerifier });
    verifiers.delete(authCode);
    return result;
  }

  public refreshToken(refreshToken: string): Promise<MiniAppTokenResult> {
    return this.transport.invoke('auth.refreshToken', { refreshToken });
  }
}
