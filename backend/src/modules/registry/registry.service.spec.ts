import { BadRequestException, ConflictException, NotFoundException, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as request from 'supertest';
import { RegistryService } from './registry.service';
import { RegistryController } from './registry.controller';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { PackageService } from './packages/package.service';
import { makePackage, testManifest } from './packages/test-package';

describe('Mini App management', () => {
  let service: RegistryService;
  let packages: PackageService;
  let app: any;
  let repo: any;
  let manager: any;
  beforeEach(() => {
    app = { id: testManifest.appId, name: 'Old name', runtimeType: MiniAppRuntimeType.WEB,
      status: MiniAppStatus.UNPUBLISHED, capabilities: ['navigation.close', 'old.permission'], requestedPermissions: [],
    };
    manager = {
      findOne: jest.fn(async () => app), findOneBy: jest.fn(async () => null),
      create: jest.fn((_, data) => data), save: jest.fn(async (_, data) => data),
    };
    repo = { manager: { findOneBy: manager.findOneBy, transaction: jest.fn(callback => callback(manager)) }, findOneBy: jest.fn(async () => null),
      create: jest.fn(data => data), save: jest.fn(async data => data), find: jest.fn(async () => [app]),
    };
    packages = new PackageService();
    jest.spyOn(packages, 'store').mockResolvedValue('11111111-1111-4111-8111-111111111111');
    jest.spyOn(packages, 'remove').mockResolvedValue(undefined);
    service = new RegistryService(repo, packages);
  });
  it('creates a hidden app with all descriptive metadata', async () => {
    const saved = await service.createApp({ id: 'new_app', name: 'New', developerName: 'Demo team', supportEmail: 'demo@example.com', icon: 'https://example.com/icon.png' });
    expect(saved.status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(saved.developerName).toBe('Demo team');
    expect(saved.requestedPermissions).toEqual([]);
    expect(saved.runtimeType).toBe(MiniAppRuntimeType.WEB);
  });
  it('rejects duplicate IDs', async () => {
    repo.findOneBy.mockResolvedValue(app);
    await expect(service.createApp({ id: app.id, name: 'Duplicate' })).rejects.toThrow(ConflictException);
  });
  it('uploads a package with its own version and metadata, preserving visibility', async () => {
    const saved = await service.uploadPackage(app.id, await makePackage(), 'First package');
    expect(saved.name).toBe(testManifest.name);
    expect(saved.activePublishedVersion).toBe('1.0.0');
    expect(saved.status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(saved.entryUrl).toBe('/api/v1/miniapps/coffee_shop/1.0.0/dist/index.html');
    expect(saved.icon).toBe('/api/v1/miniapps/coffee_shop/1.0.0/icon.png');
    expect(saved.requestedPermissions).toEqual(testManifest.permissions);
    // New requested permissions do not grant themselves, removed permissions are revoked.
    expect(saved.capabilities).toEqual(['navigation.close']);
    expect(manager.save).toHaveBeenCalledWith(MiniAppVersionEntity, expect.objectContaining({ manifest: expect.objectContaining({ manifestVersion: 1 }), checksum: expect.any(String), packageKey: expect.any(String) }));
  });
  it('keeps an app visible when replacing its package', async () => {
    app.status = MiniAppStatus.PUBLISHED;
    expect((await service.uploadPackage(app.id, await makePackage())).status).toBe(MiniAppStatus.PUBLISHED);
  });
  it('rejects duplicate versions before writing files', async () => {
    manager.findOneBy.mockResolvedValue({ version: '1.0.0' });
    await expect(service.uploadPackage(app.id, await makePackage())).rejects.toThrow(ConflictException);
    expect(packages.store).not.toHaveBeenCalled();
  });
  it('rejects runtime changes and missing apps', async () => {
    app.runtimeType = 'schema';
    await expect(service.uploadPackage(app.id, await makePackage())).rejects.toThrow(BadRequestException);
    manager.findOne.mockResolvedValue(null);
    await expect(service.uploadPackage(app.id, await makePackage())).rejects.toThrow(NotFoundException);
  });
  it('removes stored files if the database transaction fails', async () => {
    manager.save.mockRejectedValue(new Error('database unavailable'));
    await expect(service.uploadPackage(app.id, await makePackage())).rejects.toThrow('database unavailable');
    expect(packages.remove).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111');
  });
  it('requires an uploaded version before showing an app', async () => {
    await expect(service.setVisibility(app.id, true)).rejects.toThrow(BadRequestException);
  });
  it('shows and hides without changing the active version', async () => {
    app.activePublishedVersion = '1.0.0';
    expect((await service.setVisibility(app.id, true)).status).toBe(MiniAppStatus.PUBLISHED);
    expect((await service.setVisibility(app.id, false)).status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(app.activePublishedVersion).toBe('1.0.0');
  });
  it('only grants requested permissions for a packaged app', async () => {
    app.activePublishedVersion = '1.0.0'; app.requestedPermissions = ['navigation.close'];
    manager.findOneBy.mockResolvedValue({ manifest: testManifest });
    await expect(service.updateApp(app.id, { capabilities: ['payment.createOrder'] })).rejects.toThrow(BadRequestException);
    expect((await service.updateApp(app.id, { capabilities: [] })).capabilities).toEqual([]);
  });
  describe('HTTP contract', () => {
    let server: any;
    beforeEach(async () => {
      repo.findOneBy.mockResolvedValue(app);
      const module = await Test.createTestingModule({ controllers: [RegistryController], providers: [RegistryService,
        { provide: getRepositoryToken(MiniAppEntity), useValue: repo }, { provide: PackageService, useValue: packages }],
      }).compile();
      server = module.createNestApplication();
      server.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
      await server.init();
    });
    afterEach(async () => { await server.close(); });
    it('inspects and uploads multipart ZIPs', async () => {
      const zip = await makePackage();
      const inspected = await request(server.getHttpServer()).post(`/api/v1/registry/apps/${app.id}/packages/inspect`).attach('file', zip, 'miniapp.zip').expect(201);
      expect(inspected.body.manifest.version).toBe('1.0.0');
      expect(packages.store).not.toHaveBeenCalled();
      await request(server.getHttpServer()).post(`/api/v1/registry/apps/${app.id}/versions`).field('notes', 'Demo release').attach('file', zip, 'miniapp.zip').expect(201);
      expect(app.activePublishedVersion).toBe('1.0.0');
    });
    it('rejects the old arbitrary JSON upload API', async () => {
      await request(server.getHttpServer()).post(`/api/v1/registry/apps/${app.id}/versions`).send({ version: '1.0.0', entryUrl: 'https://example.com' }).expect(400);
    });
    it.each([{ capabilities: [123] }, { capabilities: null }, { status: 'PUBLISHED' }, { name: null }, { website: 'javascript:alert(1)' }])('validates metadata %p', async body => {
      await request(server.getHttpServer()).put(`/api/v1/registry/apps/${app.id}`).send(body).expect(400);
    });
    it('requires actual ZIP content rather than trusting the extension', async () => {
      await request(server.getHttpServer()).post(`/api/v1/registry/apps/${app.id}/versions`).attach('file', Buffer.from('{}'), 'fake.zip').expect(400);
    });
  });
});
