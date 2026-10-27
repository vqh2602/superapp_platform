import { AuthRateLimitGuard } from './auth-rate-limit.guard';

const context = (ip = '127.0.0.1') => ({
  getHandler: () => ({ name: 'login' }), getClass: () => ({ name: 'AuthController' }),
  switchToHttp: () => ({ getRequest: () => ({ ip }), getResponse: () => ({ setHeader: jest.fn() }) }),
} as any);
describe('Credential rate limiting', () => {
  it('limits repeated login attempts per IP and permits another IP', () => {
    const guard = new AuthRateLimitGuard();
    for (let i = 0; i < 10; i++) expect(guard.canActivate(context())).toBe(true);
    expect(() => guard.canActivate(context())).toThrow('Too many');
    expect(guard.canActivate(context('127.0.0.2'))).toBe(true);
  });
  it('expires the fixed window', () => {
    const now = jest.spyOn(Date, 'now').mockReturnValue(1_000_000);
    try {
      const guard = new AuthRateLimitGuard();
      for (let i = 0; i < 10; i++) guard.canActivate(context());
      now.mockReturnValue(1_060_001);
      expect(guard.canActivate(context())).toBe(true);
    } finally { now.mockRestore(); }
  });
});
