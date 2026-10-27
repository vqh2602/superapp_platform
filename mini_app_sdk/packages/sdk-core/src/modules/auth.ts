import { ITransport } from '@superapp/sdk-transport';
import { AccessTokenResult, AuthLoginOptions, AuthLoginResult, UserProfile } from '../types/index.js';

export class AuthModule {
  constructor(private transport: ITransport) {}

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
  public async logout(): Promise<{ success: boolean; message: string }> {
    return this.transport.invoke<{ success: boolean; message: string }>('auth.logout');
  }
}
