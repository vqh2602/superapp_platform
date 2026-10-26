import { BridgeTransport } from '../bridgeTransport';
import { MiniAppTokenResult } from '../types';

export class AuthModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Flow A: Request single-use 60s authorization code from Master App
   */
  public async requestCode(): Promise<{ authCode: string; expiresIn: number; userId: string; createdAt: string }> {
    return this.transport.invoke('auth.requestCode');
  }

  /**
   * Flow D: Invalidate active Master App session
   */
  public async logout(): Promise<{ status: string; timestamp: string }> {
    return this.transport.invoke('auth.logout');
  }
}

/**
 * Mock Auth Backend Service (simulating the external auth server)
 */
export class MockAuthBackend {
  constructor(private transport: BridgeTransport) {}

  /**
   * Flow B: Exchange authorization code for Mini App tokens
   */
  public async exchangeCode(authCode: string): Promise<MiniAppTokenResult> {
    return this.transport.invoke('auth.exchangeCode', { authCode });
  }

  /**
   * Flow C: Refresh mini app access token
   */
  public async refreshToken(refreshToken: string, simulateError: boolean = false): Promise<MiniAppTokenResult> {
    return this.transport.invoke('auth.refreshToken', { refreshToken, simulateError });
  }
}
