import { CanActivate, ExecutionContext, HttpException, Injectable } from '@nestjs/common';

/** Small per-process limiter for the demo's credential endpoints. */
@Injectable()
export class AuthRateLimitGuard implements CanActivate {
  private readonly windows = new Map<string, { count: number; expiresAt: number }>();
  canActivate(context: ExecutionContext) {
    const action = context.getHandler().name;
    const limit = ({ register: 10, login: 10, refresh: 60, exchange: 30, requestCode: 30 } as Record<string, number>)[action];
    if (!limit) return true;
    const request = context.switchToHttp().getRequest();
    const response = context.switchToHttp().getResponse();
    const now = Date.now();
    const key = `${request.ip || request.socket.remoteAddress}:${context.getClass().name}:${action}`;
    let window = this.windows.get(key);
    if (!window || window.expiresAt <= now) {
      if (this.windows.size >= 10_000) {
        for (const [storedKey, stored] of this.windows) if (stored.expiresAt <= now) this.windows.delete(storedKey);
        if (this.windows.size >= 10_000) throw new HttpException('Too many authentication requests', 429);
      }
      window = { count: 0, expiresAt: now + 60_000 };
      this.windows.set(key, window);
    }
    if (++window.count > limit) {
      response.setHeader('Retry-After', Math.ceil((window.expiresAt - now) / 1000));
      throw new HttpException('Too many authentication requests', 429);
    }
    return true;
  }
}
