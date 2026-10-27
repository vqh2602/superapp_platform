import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { AuthCodeRequestDto, ExchangeCodeDto, PermissionDecisionDto, RegisterDto, UpdateProfileDto } from './auth.dto';

const errors = (type: any, value: any) => validateSync(plainToInstance(type, value) as object, { whitelist: true, forbidNonWhitelisted: true });
describe('Auth request contract', () => {
  it('normalizes email and display name, preserves the exact password', () => {
    const dto = plainToInstance(RegisterDto, { email: ' Alice@Example.com ', password: ' demo-password ', displayName: ' Alice ' });
    expect(dto.email).toBe('alice@example.com'); expect(dto.displayName).toBe('Alice');
    expect(dto.password).toBe(' demo-password '); expect(errors(RegisterDto, dto)).toHaveLength(0);
  });
  it.each([
    { email: 'alice@example.com', password: 'short', displayName: 'Alice' },
    { email: 'alice@example.com', password: '12345678', displayName: '   ' },
    { email: 'alice@example.com', password: '12345678', displayName: 'Alice', role: 'admin' },
  ])('rejects invalid account data %p', body => { expect(errors(RegisterDto, body).length).toBeGreaterThan(0); });
  it.each([
    { permissions: ['user.getProfile'], granted: 'true' },
    { permissions: ['user.getProfile', 'user.getProfile'], granted: true },
    { permissions: [42], granted: true },
    { permissions: ['wrong,capability'], granted: true },
    { permissions: [], granted: true, userId: 'victim' },
    { permissions: null, granted: true },
  ])('rejects malformed or cross-user permission updates %p', body => { expect(errors(PermissionDecisionDto, body).length).toBeGreaterThan(0); });
  it('requires PKCE S256 and high-entropy verifier syntax', () => {
    const body = { appId: 'demo_app', codeChallenge: 'a'.repeat(43), codeChallengeMethod: 'S256', scopes: [] };
    expect(errors(AuthCodeRequestDto, body)).toHaveLength(0);
    expect(errors(AuthCodeRequestDto, { ...body, codeChallengeMethod: 'plain' }).length).toBeGreaterThan(0);
    expect(errors(ExchangeCodeDto, { appId: 'demo_app', authCode: 'code_' + 'a'.repeat(43), codeVerifier: 'short' }).length).toBeGreaterThan(0);
  });
  it('allows clearing an avatar but rejects invalid URLs and null names', () => {
    expect(errors(UpdateProfileDto, { avatarUrl: '' })).toHaveLength(0);
    expect(errors(UpdateProfileDto, { avatarUrl: 'javascript:alert(1)' }).length).toBeGreaterThan(0);
    expect(errors(UpdateProfileDto, { displayName: null }).length).toBeGreaterThan(0);
  });
});
