import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { PermissionsService } from './permissions.service';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus } from '../../entities/enums';

describe('User permission intersection', () => {
  let app: any; let version: any; let decisions: any[]; let manager: any; let service: PermissionsService;
  beforeEach(() => {
    app = { id: 'demo_app', name: 'Demo', status: MiniAppStatus.PUBLISHED, activePublishedVersion: '1.0.0', capabilities: ['user.getProfile', 'device.getLocation'] };
    version = { manifest: { permissions: ['user.getProfile', 'navigation.close'] } };
    decisions = [{ capability: 'user.getProfile', granted: true }, { capability: 'device.getLocation', granted: true }, { capability: 'navigation.close', granted: false }];
    manager = {
      findOneBy: jest.fn(async entity => entity === MiniAppEntity ? app : entity === MiniAppVersionEntity ? version : null),
      find: jest.fn(async () => decisions), findOne: jest.fn(async () => ({ id: 'user-a' })),
      upsert: jest.fn(), update: jest.fn(),
    };
    manager.transaction = async callback => callback(manager);
    service = new PermissionsService({ manager, find: jest.fn(async () => [{ appId: 'demo_app' }]) } as any);
  });
  it('requires manifest, platform and user approval simultaneously', async () => {
    const state = await service.state('user-a', 'demo_app');
    expect(state.effectivePermissions).toEqual(['user.getProfile']);
    expect(manager.find).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({ where: { userId: 'user-a', appId: 'demo_app' } }));
  });
  it('removes effective permissions while an app is hidden', async () => {
    app.status = MiniAppStatus.UNPUBLISHED;
    expect((await service.state('user-a', 'demo_app')).effectivePermissions).toEqual([]);
    await expect(service.decide('user-a', 'demo_app', { permissions: ['user.getProfile'], granted: true })).rejects.toThrow(ForbiddenException);
  });
  it('rejects grants beyond the manifest even if approved by the platform', async () => {
    await expect(service.decide('user-a', 'demo_app', { permissions: ['device.getLocation'], granted: true })).rejects.toThrow(BadRequestException);
    expect(manager.upsert).not.toHaveBeenCalled();
  });
  it('records refusal/revocation without requiring the app to stay published', async () => {
    app.status = MiniAppStatus.UNPUBLISHED;
    await service.decide('user-a', 'demo_app', { permissions: ['user.getProfile'], granted: false });
    expect(manager.upsert).toHaveBeenCalledWith(expect.anything(), { userId: 'user-a', appId: 'demo_app', capability: 'user.getProfile', granted: false }, ['userId', 'appId', 'capability']);
  });
  it('keeps seed apps compatible when they predate package manifests', async () => {
    version = { manifest: null };
    expect((await service.state('user-a', 'demo_app')).effectivePermissions).toEqual(['user.getProfile', 'device.getLocation']);
  });
  it('does not fall back to platform grants when a package explicitly requests none', async () => {
    version.manifest.permissions = [];
    expect((await service.state('user-a', 'demo_app')).effectivePermissions).toEqual([]);
  });
});
