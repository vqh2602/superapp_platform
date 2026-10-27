import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { UserEntity } from '../../entities/user.entity';
import { UserMiniAppPermissionEntity } from '../../entities/user-miniapp-permission.entity';
import { MiniAppStatus } from '../../entities/enums';
import { PermissionDecisionDto } from './auth.dto';

@Injectable()
export class PermissionsService {
  constructor(@InjectRepository(UserMiniAppPermissionEntity) private readonly grants: Repository<UserMiniAppPermissionEntity>) {}

  async state(userId: string, appId: string, manager: EntityManager = this.grants.manager) {
    const app = await manager.findOneBy(MiniAppEntity, { id: appId });
    if (!app) throw new NotFoundException('Mini App not found');
    const version = app.activePublishedVersion && await manager.findOneBy(MiniAppVersionEntity, { appId, version: app.activePublishedVersion });
    const requestedPermissions: string[] = version?.manifest?.permissions ?? app.capabilities;
    const platformPermissions = requestedPermissions.filter(permission => app.capabilities.includes(permission));
    const decisions = await manager.find(UserMiniAppPermissionEntity, { where: { userId, appId }, order: { capability: 'ASC' } });
    const userPermissions = decisions.filter(decision => decision.granted).map(decision => decision.capability);
    const isAvailable = app.status === MiniAppStatus.PUBLISHED && !!app.activePublishedVersion;
    const effectivePermissions = isAvailable ? platformPermissions.filter(permission => userPermissions.includes(permission)) : [];
    return {
      appId, name: app.name, icon: app.icon, version: app.activePublishedVersion, isAvailable,
      requestedPermissions, platformPermissions, userPermissions, effectivePermissions,
      hasUserConsent: userPermissions.length > 0, isAuthorized: effectivePermissions.length > 0,
      decisions: decisions.map(({ capability, granted, updatedAt }) => ({ capability, granted, updatedAt })),
    };
  }

  async requireAvailable(userId: string, appId: string, manager?: EntityManager) {
    const state = await this.state(userId, appId, manager);
    if (!state.isAvailable) throw new ForbiddenException('Mini App is not published');
    return state;
  }

  async listApps(userId: string) {
    const rows = await this.grants.find({ where: { userId }, select: ['appId'] });
    return Promise.all([...new Set(rows.map(row => row.appId))].map(appId => this.state(userId, appId)));
  }

  async decide(userId: string, appId: string, dto: PermissionDecisionDto) {
    return this.grants.manager.transaction(async manager => {
      // Serialize decisions by user so grant/revoke requests cannot lose each other's updates.
      await manager.findOne(UserEntity, { where: { id: userId }, lock: { mode: 'pessimistic_write' } });
      const state = await this.state(userId, appId, manager);
      if (dto.granted && !state.isAvailable) throw new ForbiddenException('Mini App is not published');
      if (dto.granted && dto.permissions.some(permission => !state.platformPermissions.includes(permission))) {
        throw new BadRequestException('Cannot grant permissions outside the active manifest and platform grants');
      }
      for (const capability of dto.permissions) {
        await manager.upsert(UserMiniAppPermissionEntity, { userId, appId, capability, granted: dto.granted }, ['userId', 'appId', 'capability']);
      }
      return this.state(userId, appId, manager);
    });
  }

  async revokeAll(userId: string, appId: string) {
    return this.grants.manager.transaction(async manager => {
      await manager.findOne(UserEntity, { where: { id: userId }, lock: { mode: 'pessimistic_write' } });
      await this.state(userId, appId, manager);
      await manager.update(UserMiniAppPermissionEntity, { userId, appId }, { granted: false });
      return this.state(userId, appId, manager);
    });
  }
}
