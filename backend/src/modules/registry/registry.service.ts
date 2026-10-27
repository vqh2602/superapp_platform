import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateMiniAppDto } from './dto/update-app.dto';
import { PackageService } from './packages/package.service';

@Injectable()
export class RegistryService {
  constructor(
    @InjectRepository(MiniAppEntity) private readonly appRepo: Repository<MiniAppEntity>,
    private readonly packages: PackageService,
  ) {}

  async createApp(dto: CreateMiniAppDto): Promise<MiniAppEntity> {
    if (await this.appRepo.findOneBy({ id: dto.id })) throw new ConflictException(`Mini App "${dto.id}" already exists`);
    // New permissions are requested by a package and explicitly granted by the manager.
    if (dto.capabilities?.length) throw new BadRequestException('Upload gói trước khi cấp quyền');
    return this.appRepo.save(this.appRepo.create({
      ...dto, tenantId: 'demo', runtimeType: dto.runtimeType || MiniAppRuntimeType.WEB,
      status: MiniAppStatus.UNPUBLISHED, capabilities: [], requestedPermissions: [],
      entryUrl: null, isAsset: false,
    }));
  }

  getAllApps(): Promise<MiniAppEntity[]> {
    return this.appRepo.find({ relations: ['versions'], order: { updatedAt: 'DESC' } });
  }

  async getAppDetails(appId: string): Promise<MiniAppEntity> {
    const app = await this.appRepo.findOne({ where: { id: appId }, relations: ['versions'] });
    if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
    app.versions.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    return app;
  }

  async updateApp(appId: string, dto: UpdateMiniAppDto): Promise<MiniAppEntity> {
    return this.appRepo.manager.transaction(async manager => {
      const app = await manager.findOne(MiniAppEntity, { where: { id: appId }, lock: { mode: 'pessimistic_write' } });
      if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
      if (dto.capabilities) {
        const active = app.activePublishedVersion && await manager.findOneBy(MiniAppVersionEntity, { appId, version: app.activePublishedVersion });
        // Old seed apps predate package manifests and retain their existing grant editor.
        if (active?.manifest && dto.capabilities.some(cap => !app.requestedPermissions.includes(cap))) {
          throw new BadRequestException('Chỉ cấp quyền đã được khai báo trong app.json của phiên bản đang dùng');
        }
      }
      Object.assign(app, dto);
      return manager.save(MiniAppEntity, app);
    });
  }

  async setVisibility(appId: string, visible: boolean): Promise<MiniAppEntity> {
    return this.appRepo.manager.transaction(async manager => {
      const app = await manager.findOne(MiniAppEntity, { where: { id: appId }, lock: { mode: 'pessimistic_write' } });
      if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
      if (visible && !app.activePublishedVersion) throw new BadRequestException('Upload a version before showing this Mini App');
      app.status = visible ? MiniAppStatus.PUBLISHED : MiniAppStatus.UNPUBLISHED;
      return manager.save(MiniAppEntity, app);
    });
  }

  async inspectPackage(appId: string, buffer: Buffer) {
    const app = await this.appRepo.findOneBy({ id: appId });
    if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
    const pkg = await this.packages.inspect(buffer, appId);
    if (pkg.manifest.runtimeType !== app.runtimeType) throw new BadRequestException('runtimeType trong app.json khác loại Mini App đã đăng ký');
    if (await this.appRepo.manager.findOneBy(MiniAppVersionEntity, { appId, version: pkg.manifest.version })) throw new ConflictException(`Version "${pkg.manifest.version}" already exists`);
    return { manifest: pkg.manifest, checksum: pkg.checksum, size: pkg.size, fileCount: pkg.files.size };
  }

  async uploadPackage(appId: string, buffer: Buffer, notes = ''): Promise<MiniAppEntity> {
    const pkg = await this.packages.inspect(buffer, appId);
    let packageKey: string | undefined;
    try {
      return await this.appRepo.manager.transaction(async manager => {
        const app = await manager.findOne(MiniAppEntity, { where: { id: appId }, lock: { mode: 'pessimistic_write' } });
        if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
        const manifest = pkg.manifest;
        if (manifest.runtimeType !== app.runtimeType) throw new BadRequestException('runtimeType trong app.json khác loại Mini App đã đăng ký');
        if (await manager.findOneBy(MiniAppVersionEntity, { appId, version: manifest.version })) throw new ConflictException(`Version "${manifest.version}" already exists`);
        packageKey = await this.packages.store(pkg);
        const base = `/api/v1/miniapps/${appId}/${manifest.version}/`;
        const entryUrl = manifest.runtimeType === MiniAppRuntimeType.WEB ? base + manifest.entry : 'assets/mini_apps/schema_runtime/index.html';
        await manager.save(MiniAppVersionEntity, manager.create(MiniAppVersionEntity, {
          appId, version: manifest.version, schemaVersion: pkg.schema?.schemaVersion || 1,
          status: MiniAppStatus.PUBLISHED, schema: pkg.schema || null, entryUrl,
          capabilities: manifest.permissions, reviewNotes: notes, publishedAt: new Date(),
          manifest, packageKey, checksum: pkg.checksum, packageSize: pkg.size,
        }));
        Object.assign(app, {
          name: manifest.name, description: manifest.description, category: manifest.category,
          icon: base + manifest.icon, developerName: manifest.developerName || '',
          supportEmail: manifest.supportEmail || '', website: manifest.website || '',
          themeColor: manifest.themeColor || '#6366F1',
          activePublishedVersion: manifest.version, entryUrl,
          isAsset: manifest.runtimeType === MiniAppRuntimeType.SCHEMA,
          requestedPermissions: manifest.permissions,
          capabilities: app.capabilities.filter(cap => manifest.permissions.includes(cap)),
        });
        // Preserve visibility. Requested permissions never grant themselves on upload.
        return manager.save(MiniAppEntity, app);
      });
    } catch (error) {
      if (packageKey) await this.packages.remove(packageKey);
      if (error?.code === '23505') throw new ConflictException(`Version "${pkg.manifest.version}" already exists`);
      throw error;
    }
  }
}
