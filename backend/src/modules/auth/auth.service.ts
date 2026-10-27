import { BadRequestException, ConflictException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';
import { AuthSessionEntity, TokenAudience } from '../../entities/auth-session.entity';
import { UserEntity } from '../../entities/user.entity';
import { LoginDto, RegisterDto, UpdateProfileDto } from './auth.dto';
import { digest, hashPassword, secret, verifyPassword } from './auth.crypto';
import { PermissionsService } from './permissions.service';

export const SUPERAPP_TOKEN_TTL = 3600;
export const MINIAPP_TOKEN_TTL = 900;
export const REFRESH_TOKEN_TTL = 30 * 24 * 3600;
const DUMMY_HASH = `scrypt$${'0'.repeat(32)}$${'0'.repeat(128)}`;
export interface AuthContext { user: UserEntity; session: AuthSessionEntity; }

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UserEntity) private readonly users: Repository<UserEntity>,
    @InjectRepository(AuthSessionEntity) private readonly sessions: Repository<AuthSessionEntity>,
    private readonly permissions: PermissionsService,
  ) {}

  publicUser(user: UserEntity) {
    return { id: user.id, email: user.email, displayName: user.displayName, avatarUrl: user.avatarUrl, createdAt: user.createdAt };
  }

  async register(dto: RegisterDto) {
    const passwordHash = await hashPassword(dto.password);
    try {
      return await this.users.manager.transaction(async manager => {
        const user = await manager.save(UserEntity, manager.create(UserEntity, {
          email: dto.email.trim().toLowerCase(), displayName: dto.displayName.trim(), passwordHash,
        }));
        return { user: this.publicUser(user), ...await this.issue(manager, user.id, 'superapp') };
      });
    } catch (error) {
      if (error.code === '23505') throw new ConflictException('Email already registered');
      throw error;
    }
  }

  async login(dto: LoginDto) {
    const user = await this.users.findOne({
      where: { email: dto.email.trim().toLowerCase() },
      select: ['id', 'email', 'displayName', 'avatarUrl', 'createdAt', 'passwordHash'],
    });
    const valid = await verifyPassword(dto.password, user?.passwordHash || DUMMY_HASH);
    if (!user || !valid) throw new UnauthorizedException('Invalid email or password');
    return { user: this.publicUser(user), ...await this.issue(this.sessions.manager, user.id, 'superapp') };
  }

  async issue(manager: EntityManager, userId: string, audience: TokenAudience, appId: string | null = null, scopes: string[] = [], parent?: AuthSessionEntity) {
    const session = manager.create(AuthSessionEntity, {
      userId, audience, appId, scopes, parentSessionId: parent?.id || null, revokedAt: null,
      refreshExpiresAt: new Date(Math.min(Date.now() + REFRESH_TOKEN_TTL * 1000, parent?.refreshExpiresAt.getTime() ?? Infinity)),
    });
    return this.rotate(manager, session);
  }

  private async rotate(manager: EntityManager, session: AuthSessionEntity) {
    const accessToken = secret('access');
    const refreshToken = secret('refresh');
    const expiresIn = session.audience === 'superapp' ? SUPERAPP_TOKEN_TTL : MINIAPP_TOKEN_TTL;
    session.accessTokenHash = digest(accessToken);
    session.refreshTokenHash = digest(refreshToken);
    session.expiresAt = new Date(Math.min(Date.now() + expiresIn * 1000, session.refreshExpiresAt.getTime()));
    await manager.save(AuthSessionEntity, session);
    return {
      accessToken, refreshToken, tokenType: 'Bearer',
      expiresIn: Math.max(0, Math.floor((session.expiresAt.getTime() - Date.now()) / 1000)),
      refreshExpiresIn: Math.max(0, Math.floor((session.refreshExpiresAt.getTime() - Date.now()) / 1000)),
      audience: session.audience, appId: session.appId, scopes: session.scopes,
    };
  }

  async authenticate(token: string): Promise<AuthContext> {
    if (!/^access_[a-zA-Z0-9_-]{43}$/.test(token)) throw new UnauthorizedException('Invalid access token');
    const session = await this.sessions.findOne({ where: { accessTokenHash: digest(token) }, relations: ['user'] });
    if (!session || session.revokedAt || session.expiresAt.getTime() <= Date.now() || !session.user) {
      throw new UnauthorizedException('Access token is expired or revoked');
    }
    if (session.audience === 'miniapp') {
      await this.requireParent(session, this.sessions.manager);
      await this.permissions.requireAvailable(session.userId, session.appId);
    }
    return { session, user: session.user };
  }

  async requireParent(session: AuthSessionEntity, manager: EntityManager) {
    const parent = session.parentSessionId && await manager.findOneBy(AuthSessionEntity, { id: session.parentSessionId });
    if (!parent || parent.audience !== 'superapp' || parent.userId !== session.userId || parent.revokedAt || parent.refreshExpiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException('Super App session is no longer active');
    }
  }

  async refresh(refreshToken: string) {
    return this.sessions.manager.transaction(async manager => {
      const session = await manager.findOne(AuthSessionEntity, {
        where: { refreshTokenHash: digest(refreshToken) }, lock: { mode: 'pessimistic_write' },
      });
      if (!session || session.revokedAt || session.refreshExpiresAt.getTime() <= Date.now()) throw new UnauthorizedException('Refresh token is expired or revoked');
      if (session.audience === 'miniapp') {
        await this.requireParent(session, manager);
        const state = await this.permissions.requireAvailable(session.userId, session.appId, manager);
        session.scopes = session.scopes.filter(scope => state.effectivePermissions.includes(scope));
      }
      return this.rotate(manager, session);
    });
  }

  requireSuperApp(context: AuthContext) {
    if (context.session.audience !== 'superapp') throw new ForbiddenException('A Super App access token is required');
  }

  async updateProfile(context: AuthContext, dto: UpdateProfileDto) {
    this.requireSuperApp(context);
    if (!Object.keys(dto).length) throw new BadRequestException('Provide displayName or avatarUrl');
    await this.users.update({ id: context.user.id }, dto);
    return this.publicUser(await this.users.findOneByOrFail({ id: context.user.id }));
  }

  async logout(context: AuthContext) {
    await this.sessions.update({ id: context.session.id, userId: context.user.id }, { revokedAt: new Date() });
    return { success: true };
  }

  async logoutAll(context: AuthContext) {
    this.requireSuperApp(context);
    await this.sessions.update({ userId: context.user.id }, { revokedAt: new Date() });
    return { success: true };
  }
}
