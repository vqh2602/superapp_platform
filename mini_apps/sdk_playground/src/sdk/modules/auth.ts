import { BridgeTransport } from '../bridgeTransport';
import { MiniAppTokenResult } from '../types';
const verifiers = new Map<string, string>();
function url64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
export class AuthModule {
  constructor(private transport: BridgeTransport) {}
  public async requestCode(): Promise<{ authCode: string; expiresIn: number; appId: string; scopes: string[] }> {
    const verifier = url64(crypto.getRandomValues(new Uint8Array(32)));
    const challenge = url64(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))));
    const result = await this.transport.invoke<{authCode: string; expiresIn: number; appId: string; scopes: string[]}>('auth.requestCode', {
      codeChallenge: challenge, codeChallengeMethod: 'S256', scopes: ['user.getBasicInfo'],
    });
    verifiers.set(result.authCode, verifier);
    return result;
  }
  public logout(): Promise<{ status: string; timestamp: string }> { return this.transport.invoke('auth.logout'); }
}
export class AuthBackend {
  constructor(private transport: BridgeTransport) {}
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
