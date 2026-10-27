import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateDraftDto } from './dto/update-draft.dto';
import { UploadVersionDto } from './dto/upload-version.dto';

@Injectable()
export class RegistryService {
  constructor(
    @InjectRepository(MiniAppEntity)
    private readonly appRepo: Repository<MiniAppEntity>,
  ) {}

  async createApp(dto: CreateMiniAppDto): Promise<MiniAppEntity> {
    if (await this.appRepo.findOneBy({ id: dto.id })) {
      throw new ConflictException(`Mini App "${dto.id}" already exists`);
    }
    const runtimeType = dto.runtimeType || MiniAppRuntimeType.SCHEMA;
    return this.appRepo.save(this.appRepo.create({
      ...dto,
      tenantId: 'demo',
      runtimeType,
      status: MiniAppStatus.UNPUBLISHED,
      capabilities: dto.capabilities || [],
      entryUrl: dto.entryUrl || (runtimeType === MiniAppRuntimeType.SCHEMA
        ? 'assets/mini_apps/schema_runtime/index.html' : null),
      isAsset: dto.isAsset ?? (runtimeType === MiniAppRuntimeType.SCHEMA),
      draftSchema: dto.draftSchema || null,
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

  async updateApp(appId: string, dto: UpdateDraftDto): Promise<MiniAppEntity> {
    return this.appRepo.manager.transaction(async (manager) => {
      const app = await manager.findOne(MiniAppEntity, {
        where: { id: appId }, lock: { mode: 'pessimistic_write' },
      });
      if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
      // Runtime content changes only through version upload; grants apply immediately.
      Object.assign(app, dto);
      return manager.save(MiniAppEntity, app);
    });
  }

  async setVisibility(appId: string, visible: boolean): Promise<MiniAppEntity> {
    return this.appRepo.manager.transaction(async (manager) => {
      const app = await manager.findOne(MiniAppEntity, {
        where: { id: appId }, lock: { mode: 'pessimistic_write' },
      });
      if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
      if (visible && !app.activePublishedVersion) {
        throw new BadRequestException('Upload a version before showing this Mini App');
      }
      app.status = visible ? MiniAppStatus.PUBLISHED : MiniAppStatus.UNPUBLISHED;
      return manager.save(MiniAppEntity, app);
    });
  }

  async uploadVersion(appId: string, dto: UploadVersionDto): Promise<MiniAppEntity> {
    try {
      return await this.appRepo.manager.transaction(async (manager) => {
        const app = await manager.findOne(MiniAppEntity, {
          where: { id: appId }, lock: { mode: 'pessimistic_write' },
        });
        if (!app) throw new NotFoundException(`Mini App "${appId}" not found`);
        if (await manager.findOneBy(MiniAppVersionEntity, { appId, version: dto.version })) {
          throw new ConflictException(`Version "${dto.version}" already exists`);
        }
        const schema = dto.schema ?? app.draftSchema;
        const useDefaultRuntime = app.runtimeType === MiniAppRuntimeType.SCHEMA && !app.entryUrl;
        const entryUrl = dto.entryUrl ?? (app.entryUrl ||
          (useDefaultRuntime ? 'assets/mini_apps/schema_runtime/index.html' : null));
        const isAsset = dto.isAsset ?? (useDefaultRuntime ? true : app.isAsset);
        if (app.runtimeType === MiniAppRuntimeType.SCHEMA &&
            (!schema || !Array.isArray(schema.pages) || !schema.pages.length ||
              schema.pages.some((page: any) => !page || typeof page.id !== 'string' ||
                !page.id.trim() || !Array.isArray(page.components)))) {
          throw new BadRequestException('Schema must contain pages with an id and components array');
        }
        if (schema?.schemaVersion !== undefined &&
            (!Number.isInteger(schema.schemaVersion) || schema.schemaVersion < 1)) {
          throw new BadRequestException('schemaVersion must be a positive integer');
        }
        if (!entryUrl || !(isAsset
          ? /^assets\/[a-zA-Z0-9_./-]+\.html$/.test(entryUrl) && !entryUrl.includes('..')
          : /^https?:\/\//.test(entryUrl))) {
          throw new BadRequestException('Provide an HTTP(S) entryUrl or a bundled assets/...html path');
        }
        if (!isAsset) {
          try { new URL(entryUrl); } catch { throw new BadRequestException('Invalid entryUrl'); }
        }
        const now = new Date();
        await manager.save(MiniAppVersionEntity, manager.create(MiniAppVersionEntity, {
          appId,
          version: dto.version,
          schemaVersion: schema?.schemaVersion || 1,
          status: MiniAppStatus.PUBLISHED,
          schema: app.runtimeType === MiniAppRuntimeType.SCHEMA ? schema : null,
          entryUrl,
          capabilities: [...app.capabilities],
          reviewNotes: dto.notes || '',
          publishedAt: now,
        }));
        app.activePublishedVersion = dto.version;
        app.entryUrl = entryUrl;
        app.isAsset = isAsset;
        if (app.runtimeType === MiniAppRuntimeType.SCHEMA) app.draftSchema = schema;
        // Upload keeps the current visibility; showing is an independent action.
        return manager.save(MiniAppEntity, app);
      });
    } catch (error) {
      if (error?.code === '23505') throw new ConflictException(`Version "${dto.version}" already exists`);
      throw error;
    }
  }
}
