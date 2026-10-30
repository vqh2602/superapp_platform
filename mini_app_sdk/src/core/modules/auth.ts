import { ITransport } from '../../transport/index.js';
import { AccessTokenResult, AuthLoginOptions, AuthLoginResult, UserProfile } from '../types/index.js';

export class AuthModule {
  constructor(private transport: ITransport) {}
  public requestCode(options: {codeChallenge: string; scopes?: string[]}): Promise<any> {
    return this.transport.invoke('auth.requestCode', {...options, codeChallengeMethod: 'S256'});
  }
  public exchangeCode(options: {authCode: string; codeVerifier: string}): Promise<any> {
    return this.transport.invoke('auth.exchangeCode', options);
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
