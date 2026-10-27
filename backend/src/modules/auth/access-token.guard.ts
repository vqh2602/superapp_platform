import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Request } from 'express';
import { AuthContext, AuthService } from './auth.service';

export interface AuthRequest extends Request { auth: AuthContext; }

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}
  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<AuthRequest>();
    const header = request.headers.authorization;
    const match = typeof header === 'string' && /^Bearer (\S+)$/i.exec(header);
    if (!match) throw new UnauthorizedException('Bearer access token is required');
    request.auth = await this.auth.authenticate(match[1]);
    return true;
  }
}
