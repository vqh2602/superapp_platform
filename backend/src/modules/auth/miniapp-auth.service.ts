import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { timingSafeEqual } from 'crypto';
import { Repository } from 'typeorm';
import { MiniAppAuthCodeEntity } from '../../entities/miniapp-auth-code.entity';
import { AuthSessionEntity } from '../../entities/auth-session.entity';
import { AuthCodeRequestDto, ExchangeCodeDto } from './auth.dto';
import { AuthContext, AuthService } from './auth.service';
import { digest, miniAppOpenId, pkceChallenge, secret } from './auth.crypto';
import { PermissionsService } from './permissions.service';

@Injectable()
export class MiniAppAuthService {
  constructor(
    @InjectRepository(MiniAppAuthCodeEntity) private readonly codes: Repository<MiniAppAuthCodeEntity>,
    private readonly auth: AuthService,
    private readonly permissions: PermissionsService,
  ) {}

  async requestCode(context: AuthContext, dto: AuthCodeRequestDto) {
    this.auth.requireSuperApp(context);
    const state = await this.permissions.requireAvailable(context.user.id, dto.appId);
    const scopes = dto.scopes ?? state.effectivePermissions;
    if (scopes.some(scope => !state.effectivePermissions.includes(scope))) throw new ForbiddenException('Requested scopes require platform and user permission');
    const authCode = secret('code');
    await this.codes.save(this.codes.create({
      userId: context.user.id, appId: dto.appId, sessionId: context.session.id,
      codeHash: digest(authCode), codeChallenge: dto.codeChallenge, scopes,
      expiresAt: new Date(Date.now() + 60_000), consumedAt: null,
    }));
    return { authCode, appId: dto.appId, expiresIn: 60, scopes };
  }

  async exchange(dto: ExchangeCodeDto) {
    return this.codes.manager.transaction(async manager => {
      const code = await manager.findOne(MiniAppAuthCodeEntity, {
        where: { codeHash: digest(dto.authCode) }, lock: { mode: 'pessimistic_write' },
      });
      if (!code || code.appId !== dto.appId || code.consumedAt || code.expiresAt.getTime() <= Date.now()) throw new UnauthorizedException('Authorization code is invalid, expired or already used');
      const challenge = Buffer.from(pkceChallenge(dto.codeVerifier));
      const expected = Buffer.from(code.codeChallenge);
      if (challenge.length !== expected.length || !timingSafeEqual(challenge, expected)) throw new UnauthorizedException('Invalid PKCE verifier');
      const parent = await manager.findOneBy(AuthSessionEntity, { id: code.sessionId });
      if (!parent || parent.audience !== 'superapp' || parent.userId !== code.userId || parent.revokedAt || parent.expiresAt.getTime() <= Date.now()) throw new UnauthorizedException('Super App session is no longer active');
      const state = await this.permissions.requireAvailable(code.userId, code.appId, manager);
      if (code.scopes.some(scope => !state.effectivePermissions.includes(scope))) throw new ForbiddenException('Permissions changed; request a new authorization code');
      code.consumedAt = new Date();
      await manager.save(MiniAppAuthCodeEntity, code);
      return {
        ...await this.auth.issue(manager, code.userId, 'miniapp', code.appId, code.scopes, parent),
        openId: miniAppOpenId(code.userId, code.appId),
      };
    });
  }

  async tokenPermissions(context: AuthContext) {
    if (context.session.audience !== 'miniapp') throw new ForbiddenException('A Mini App access token is required');
    const state = await this.permissions.requireAvailable(context.user.id, context.session.appId);
    return {
      appId: state.appId, requestedPermissions: state.requestedPermissions,
      effectivePermissions: state.effectivePermissions.filter(scope => context.session.scopes.includes(scope)),
    };
  }

  async profile(context: AuthContext) {
    const state = await this.tokenPermissions(context);
    const full = state.effectivePermissions.includes('user.getProfile');
    if (!full && !state.effectivePermissions.includes('user.getBasicInfo')) throw new ForbiddenException('User profile permission is required');
    return {
      appId: context.session.appId, openId: miniAppOpenId(context.user.id, context.session.appId),
      name: context.user.displayName, avatarUrl: context.user.avatarUrl,
      ...(full ? { email: context.user.email } : {}),
    };
  }

  async launchContext(context: AuthContext, appId: string) {
    this.auth.requireSuperApp(context);
    const state = await this.permissions.requireAvailable(context.user.id, appId);
    return { ...state, openId: miniAppOpenId(context.user.id, appId) };
  }
}
