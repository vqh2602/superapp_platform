import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from '../../entities/user.entity';
import { AuthSessionEntity } from '../../entities/auth-session.entity';
import { UserMiniAppPermissionEntity } from '../../entities/user-miniapp-permission.entity';
import { MiniAppAuthCodeEntity } from '../../entities/miniapp-auth-code.entity';
import { AuthController, MiniAppAuthController, UserAppsController } from './auth.controller';
import { AuthService } from './auth.service';
import { PermissionsService } from './permissions.service';
import { MiniAppAuthService } from './miniapp-auth.service';
import { NoStoreInterceptor } from './no-store.interceptor';
import { AuthRateLimitGuard } from './auth-rate-limit.guard';
import { AccessTokenGuard } from './access-token.guard';

@Module({
  imports: [TypeOrmModule.forFeature([UserEntity, AuthSessionEntity, UserMiniAppPermissionEntity, MiniAppAuthCodeEntity])],
  controllers: [AuthController, MiniAppAuthController, UserAppsController],
  providers: [AuthService, PermissionsService, MiniAppAuthService, AccessTokenGuard, AuthRateLimitGuard, NoStoreInterceptor],
  exports: [AuthService, PermissionsService, AccessTokenGuard],
})
export class AuthModule {}
