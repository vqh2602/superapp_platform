import { BadRequestException, ConflictException, NotFoundException, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import * as request from 'supertest';
import { RegistryService } from './registry.service';
import { RegistryController } from './registry.controller';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';

const schema = { schemaVersion: 1, pages: [{ id: 'home', components: [] }] };

describe('Demo registry', () => {
  let service: RegistryService;
  let app: any;
  let repo: any;
  let manager: any;
  beforeEach(() => {
    app = {
      id: 'coffee_shop', name: 'Coffee', runtimeType: MiniAppRuntimeType.SCHEMA,
      status: MiniAppStatus.UNPUBLISHED, draftSchema: schema,
      capabilities: ['navigation.close'], entryUrl: 'assets/mini_apps/schema_runtime/index.html',
      isAsset: true,
    };
    manager = {
      findOne: jest.fn(async () => app),
      findOneBy: jest.fn(async () => null),
      create: jest.fn((_, data) => data),
      save: jest.fn(async (_, data) => data),
    };
    repo = {
      manager: { transaction: jest.fn(callback => callback(manager)) },
      findOneBy: jest.fn(async () => null),
      create: jest.fn(data => data),
      save: jest.fn(async data => data),
      find: jest.fn(async () => [app]),
    };
    service = new RegistryService(repo);
  });

  it('creates hidden apps with the bundled schema runtime', async () => {
    const saved = await service.createApp({ id: 'new_app', name: 'New App' });
    expect(saved.status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(saved.isAsset).toBe(true);
    expect(saved.entryUrl).toBe('assets/mini_apps/schema_runtime/index.html');
  });

  it('rejects duplicate IDs', async () => {
    repo.findOneBy.mockResolvedValue(app);
    await expect(service.createApp({ id: app.id, name: 'Duplicate' })).rejects.toThrow(ConflictException);
  });

  it('uploads and activates directly without review while keeping hidden apps hidden', async () => {
    const saved = await service.uploadVersion(app.id, { version: '1.0.0' });
    expect(saved.activePublishedVersion).toBe('1.0.0');
    expect(saved.status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(manager.save).toHaveBeenCalledWith(MiniAppVersionEntity, expect.objectContaining({
      version: '1.0.0', schema, status: MiniAppStatus.PUBLISHED,
    }));
    expect(repo.manager.transaction).toHaveBeenCalledTimes(1);
  });

  it('updates legacy schema apps that have no runtime URL', async () => {
    app.entryUrl = null;
    app.isAsset = false;
    const saved = await service.uploadVersion(app.id, { version: '1.0.0' });
    expect(saved.entryUrl).toBe('assets/mini_apps/schema_runtime/index.html');
    expect(saved.isAsset).toBe(true);
  });

  it('keeps a visible app visible when updating its version', async () => {
    app.status = MiniAppStatus.PUBLISHED;
    const next = { schemaVersion: 2, pages: [{ id: 'new', components: [] }] };
    const saved = await service.uploadVersion(app.id, { version: '2.0.0', schema: next });
    expect(saved.status).toBe(MiniAppStatus.PUBLISHED);
    expect(saved.activePublishedVersion).toBe('2.0.0');
    expect(saved.draftSchema).toEqual(next);
  });

  it('rejects duplicate versions without changing the active version', async () => {
    app.activePublishedVersion = '1.0.0';
    manager.findOneBy.mockResolvedValue({ version: '2.0.0' });
    await expect(service.uploadVersion(app.id, { version: '2.0.0' })).rejects.toThrow(ConflictException);
    expect(app.activePublishedVersion).toBe('1.0.0');
    expect(manager.save).not.toHaveBeenCalled();
  });

  it('rejects missing apps', async () => {
    manager.findOne.mockResolvedValue(null);
    await expect(service.uploadVersion('missing', { version: '1.0.0' })).rejects.toThrow(NotFoundException);
  });

  it.each([{}, { pages: [] }, { pages: [{ id: 'home' }] }, { ...schema, schemaVersion: 'bad' }])('rejects invalid schema %p', async invalid => {
    await expect(service.uploadVersion(app.id, { version: '1.0.0', schema: invalid })).rejects.toThrow(BadRequestException);
    expect(manager.save).not.toHaveBeenCalled();
  });

  it('accepts hosted web entry URLs', async () => {
    app.runtimeType = MiniAppRuntimeType.WEB;
    const saved = await service.uploadVersion(app.id, { version: '1.0.0', entryUrl: 'https://example.com/app/', isAsset: false });
    expect(saved.entryUrl).toBe('https://example.com/app/');
    expect(saved.isAsset).toBe(false);
  });

  it.each(['javascript:alert(1)', 'https://', 'file:///tmp/app.html'])('rejects unsafe/invalid URL %s', async entryUrl => {
    await expect(service.uploadVersion(app.id, { version: '1.0.0', entryUrl, isAsset: false })).rejects.toThrow(BadRequestException);
  });

  it('requires an uploaded version before showing an app', async () => {
    await expect(service.setVisibility(app.id, true)).rejects.toThrow(BadRequestException);
    expect(manager.save).not.toHaveBeenCalled();
  });

  it('can show and hide an app without changing the selected version', async () => {
    app.activePublishedVersion = '1.0.0';
    expect((await service.setVisibility(app.id, true)).status).toBe(MiniAppStatus.PUBLISHED);
    expect((await service.setVisibility(app.id, false)).status).toBe(MiniAppStatus.UNPUBLISHED);
    expect(app.activePublishedVersion).toBe('1.0.0');
  });

  it('updates grants directly without editing historical version snapshots', async () => {
    app.activePublishedVersion = '1.0.0';
    const saved = await service.updateApp(app.id, { capabilities: [] });
    expect(saved.capabilities).toEqual([]);
    expect(saved.activePublishedVersion).toBe('1.0.0');
    expect(manager.save).toHaveBeenCalledTimes(1);
    expect(manager.save).toHaveBeenCalledWith(MiniAppEntity, app);
  });

  describe('HTTP validation', () => {
    let server: any;
    beforeEach(async () => {
      const module = await Test.createTestingModule({
        controllers: [RegistryController],
        providers: [RegistryService, { provide: getRepositoryToken(MiniAppEntity), useValue: repo }],
      }).compile();
      server = module.createNestApplication();
      server.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
      await server.init();
    });
    afterEach(async () => { await server.close(); });

    it('serves the simplified create/upload/show/update/hide flow', async () => {
      await request(server.getHttpServer()).post('/api/v1/registry/apps').send({ id: app.id, name: app.name }).expect(201);
      await request(server.getHttpServer()).post(`/api/v1/registry/apps/${app.id}/versions`).send({ version: '1.0.0', schema }).expect(201);
      await request(server.getHttpServer()).patch(`/api/v1/registry/apps/${app.id}/visibility`).send({ visible: true }).expect(200);
      await request(server.getHttpServer()).put(`/api/v1/registry/apps/${app.id}`).send({ capabilities: [] }).expect(200);
      await request(server.getHttpServer()).patch(`/api/v1/registry/apps/${app.id}/visibility`).send({ visible: false }).expect(200);
    });

    it.each([
      ['visibility', 'patch', { visible: 'true' }],
      ['versions', 'post', { version: 'bad' }],
      ['versions', 'post', { version: '1.0.0', schema: null }],
      ['', 'put', { capabilities: [123] }],
      ['', 'put', { capabilities: ['bad,capability'] }],
      ['', 'put', { capabilities: null }],
      ['', 'put', { status: 'PUBLISHED' }],
    ])('rejects malformed %s payload %p', async (suffix, method, body) => {
      await request(server.getHttpServer())[method](`/api/v1/registry/apps/${app.id}${suffix ? '/' + suffix : ''}`).send(body).expect(400);
    });
  });
});
