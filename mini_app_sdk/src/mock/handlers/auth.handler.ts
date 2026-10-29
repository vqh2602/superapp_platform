import { MockStateStore } from '../store.js';

export class AuthMockHandler {
  constructor(private store: MockStateStore) {}

  public async login(payload: { scopes?: string[]; prompt?: boolean } = {}): Promise<any> {
    const user = this.store.getUser();
    const session = this.store.createSession();
    const authCode = `AUTH_${Math.random().toString(36).substring(2, 10).toUpperCase()}`;

    return {
      authCode,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
      user: {
        id: user.id,
        name: user.name,
        avatarUrl: user.avatarUrl,
        phone: payload.scopes?.includes('user.phone') ? user.phone : user.phone,
        email: payload.scopes?.includes('user.email') ? user.email : user.email,
        role: user.role,
        walletBalance: user.walletBalance,
      },
    };
  }

  public async requestCode(payload: { scopes?: string[] } = {}): Promise<any> {
    const user = this.store.getUser();
    const authCode = `AUTH_${Math.random().toString(36).substring(2, 10).toUpperCase()}`;
    return {
      authCode,
      userId: user.id,
      expiresIn: 60,
    };
  }

  public async exchangeCode(payload: { authCode?: string } = {}): Promise<any> {
    const user = this.store.getUser();
    const session = this.store.createSession();
    return {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      tokenType: 'Bearer',
      expiresIn: 3600,
      userId: user.id,
      user: {
        id: user.id,
        name: user.name,
        avatarUrl: user.avatarUrl,
        phone: user.phone,
        email: user.email,
        role: user.role,
        walletBalance: user.walletBalance,
      },
    };
  }

  public async getAccessToken(): Promise<any> {
    const session = this.store.getSession();
    if (!session) {
      throw {
        code: 'TOKEN_EXPIRED',
        message: 'Current access token has expired. Call auth.login() again.',
      };
    }
    return {
      accessToken: session.accessToken,
      tokenType: session.tokenType,
      expiresIn: Math.max(0, Math.floor((session.issuedAt + session.expiresIn * 1000 - Date.now()) / 1000)),
    };
  }

  public async getUserProfile(): Promise<any> {
    const user = this.store.getUser();
    return {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      avatarUrl: user.avatarUrl,
      role: user.role,
      isVerified: user.isVerified,
      walletBalance: user.walletBalance,
    };
  }

  public async getProfile(): Promise<any> {
    return this.getUserProfile();
  }

  public async getBasicInfo(): Promise<any> {
    const user = this.store.getUser();
    return {
      id: user.id,
      name: user.name,
      avatarUrl: user.avatarUrl,
    };
  }

  public async refreshToken(payload: { refreshToken?: string } = {}): Promise<any> {
    const session = this.store.createSession();
    return {
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
    };
  }

  public async logout(): Promise<any> {
    this.store.clearSession();
    return { success: true, message: 'Logged out successfully' };
  }
}
