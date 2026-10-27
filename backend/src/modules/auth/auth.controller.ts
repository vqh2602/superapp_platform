import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Put, Req, UseGuards, UseInterceptors } from '@nestjs/common';
import { NoStoreInterceptor } from './no-store.interceptor';
import { AuthRateLimitGuard } from './auth-rate-limit.guard';
import { AccessTokenGuard, AuthRequest } from './access-token.guard';
import { AuthService } from './auth.service';
import { AuthCodeRequestDto, ExchangeCodeDto, LoginDto, PermissionDecisionDto, RefreshTokenDto, RegisterDto, UpdateProfileDto } from './auth.dto';
import { MiniAppAuthService } from './miniapp-auth.service';
import { PermissionsService } from './permissions.service';

@Controller('api/v1/auth')
@UseGuards(AuthRateLimitGuard)
@UseInterceptors(NoStoreInterceptor)
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Post('register') register(@Body() dto: RegisterDto) { return this.auth.register(dto); }
  @Post('login') @HttpCode(200) login(@Body() dto: LoginDto) { return this.auth.login(dto); }
  @Post('refresh') @HttpCode(200) refresh(@Body() dto: RefreshTokenDto) { return this.auth.refresh(dto.refreshToken); }
  @Get('me') @UseGuards(AccessTokenGuard) me(@Req() request: AuthRequest) {
    this.auth.requireSuperApp(request.auth);
    return this.auth.publicUser(request.auth.user);
  }
  @Patch('me') @UseGuards(AccessTokenGuard) updateProfile(@Req() request: AuthRequest, @Body() dto: UpdateProfileDto) { return this.auth.updateProfile(request.auth, dto); }
  @Post('logout') @HttpCode(200) @UseGuards(AccessTokenGuard) logout(@Req() request: AuthRequest) { return this.auth.logout(request.auth); }
  @Post('logout-all') @HttpCode(200) @UseGuards(AccessTokenGuard) logoutAll(@Req() request: AuthRequest) { return this.auth.logoutAll(request.auth); }
}

@Controller('api/v1/users/me/apps')
@UseGuards(AccessTokenGuard)
@UseInterceptors(NoStoreInterceptor)
export class UserAppsController {
  constructor(private readonly auth: AuthService, private readonly permissions: PermissionsService) {}
  @Get() list(@Req() request: AuthRequest) {
    this.auth.requireSuperApp(request.auth);
    return this.permissions.listApps(request.auth.user.id);
  }
  @Get(':appId/permissions') permissionsForApp(@Req() request: AuthRequest, @Param('appId') appId: string) {
    this.auth.requireSuperApp(request.auth);
    return this.permissions.state(request.auth.user.id, appId);
  }
  @Put(':appId/permissions') decide(@Req() request: AuthRequest, @Param('appId') appId: string, @Body() dto: PermissionDecisionDto) {
    this.auth.requireSuperApp(request.auth);
    return this.permissions.decide(request.auth.user.id, appId, dto);
  }
  @Delete(':appId/permissions') revokeAll(@Req() request: AuthRequest, @Param('appId') appId: string) {
    this.auth.requireSuperApp(request.auth);
    return this.permissions.revokeAll(request.auth.user.id, appId);
  }
}

@Controller('api/v1/miniapp')
@UseGuards(AuthRateLimitGuard)
@UseInterceptors(NoStoreInterceptor)
export class MiniAppAuthController {
  constructor(private readonly miniapp: MiniAppAuthService) {}
  @Post('auth/code') @UseGuards(AccessTokenGuard) requestCode(@Req() request: AuthRequest, @Body() dto: AuthCodeRequestDto) { return this.miniapp.requestCode(request.auth, dto); }
  @Post('auth/token') @HttpCode(200) exchange(@Body() dto: ExchangeCodeDto) { return this.miniapp.exchange(dto); }
  @Get('me') @UseGuards(AccessTokenGuard) profile(@Req() request: AuthRequest) { return this.miniapp.profile(request.auth); }
  @Get('permissions') @UseGuards(AccessTokenGuard) permissions(@Req() request: AuthRequest) { return this.miniapp.tokenPermissions(request.auth); }
  @Get('apps/:appId/launch-context') @UseGuards(AccessTokenGuard) launchContext(@Req() request: AuthRequest, @Param('appId') appId: string) { return this.miniapp.launchContext(request.auth, appId); }
}
