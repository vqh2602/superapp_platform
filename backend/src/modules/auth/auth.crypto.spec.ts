import { digest, hashPassword, miniAppOpenId, pkceChallenge, secret, verifyPassword } from './auth.crypto';

describe('Credentials and tokens', () => {
  it('salts each scrypt password and verifies without storing plaintext', async () => {
    const first = await hashPassword('demo-password-123');
    const second = await hashPassword('demo-password-123');
    expect(first).not.toBe(second);
    expect(first).not.toContain('demo-password-123');
    expect(await verifyPassword('demo-password-123', first)).toBe(true);
    expect(await verifyPassword('different-password', first)).toBe(false);
    expect(await verifyPassword('demo-password-123', 'malformed')).toBe(false);
  });
  it('creates unique random opaque tokens and SHA256 digests', () => {
    const first = secret('access');
    expect(first).toMatch(/^access_[A-Za-z0-9_-]{43}$/);
    expect(secret('access')).not.toBe(first);
    expect(digest(first)).toMatch(/^[a-f0-9]{64}$/);
  });
  it('implements the RFC 7636 S256 test vector', () => {
    expect(pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk')).toBe('E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });
  it('binds pseudonymous open IDs to both the user and miniapp', () => {
    expect(miniAppOpenId('user-a', 'app-a')).toBe(miniAppOpenId('user-a', 'app-a'));
    expect(miniAppOpenId('user-a', 'app-a')).not.toBe(miniAppOpenId('user-b', 'app-a'));
    expect(miniAppOpenId('user-a', 'app-a')).not.toBe(miniAppOpenId('user-a', 'app-b'));
  });
});
