import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, IsNull } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus } from '../../entities/enums';

export interface CatalogQueryDto {
  category?: string;
  search?: string;
  page?: number;
  limit?: number;
}

export interface PublishedManifestDto {
  id: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  runtimeType: string;
  version: string;
  entryUrl?: string | null;
  isAsset: boolean;
  capabilities: string[];
  requestedPermissions?: string[];
  developerName?: string;
  supportEmail?: string;
  website?: string;
  themeColor?: string;
  packageBaseUrl?: string;
  schemaVersion?: number;
  schema?: Record<string, any> | null;
  updatedAt: string;
}

@Injectable()
export class CatalogService {
  constructor(
    @InjectRepository(MiniAppEntity)
    private readonly appRepo: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity)
    private readonly versionRepo: Repository<MiniAppVersionEntity>,
  ) {}

  /**
   * Get public catalog of published mini apps for Master App
   */
  async getPublishedApps(query: CatalogQueryDto): Promise<{
    items: PublishedManifestDto[];
    total: number;
    page: number;
    limit: number;
  }> {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(query.limit) || 20));

    const qb = this.appRepo
      .createQueryBuilder('app')
      .where('app.status = :status', { status: MiniAppStatus.PUBLISHED })
      .andWhere('app.activePublishedVersion IS NOT NULL');

    if (query.category && query.category !== 'All') {
      qb.andWhere('app.category = :category', { category: query.category });
    }

    if (query.search && query.search.trim()) {
      const term = `%${query.search.trim().toLowerCase()}%`;
      qb.andWhere('(LOWER(app.name) LIKE :term OR LOWER(app.description) LIKE :term)', { term });
    }

    qb.orderBy('app.updatedAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [apps, total] = await qb.getManyAndCount();

    // Map to public manifest
    const items: PublishedManifestDto[] = apps.map((app) => ({
      id: app.id,
      name: app.name,
      description: app.description,
      icon: app.icon,
      category: app.category,
      runtimeType: app.runtimeType,
      version: app.activePublishedVersion || '1.0.0',
      entryUrl: app.entryUrl,
      isAsset: app.isAsset,
      capabilities: app.capabilities || [],
      requestedPermissions: app.requestedPermissions || [],
      developerName: app.developerName,
      supportEmail: app.supportEmail,
      website: app.website,
      themeColor: app.themeColor,
      updatedAt: app.updatedAt.toISOString(),
    }));

    return { items, total, page, limit };
  }

  /**
   * Get single published app manifest & active version schema
   * Blocks direct launch if unpublished, suspended, or draft!
   */
  async getPublishedAppById(appId: string): Promise<PublishedManifestDto> {
    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    if (app.status === MiniAppStatus.SUSPENDED) {
      throw new ForbiddenException(`Mini App "${appId}" has been suspended by administration`);
    }

    if (app.status !== MiniAppStatus.PUBLISHED || !app.activePublishedVersion) {
      throw new ForbiddenException(`Mini App "${appId}" is not published (Current status: ${app.status})`);
    }

    const version = await this.versionRepo.findOne({
      where: { appId, version: app.activePublishedVersion },
    });

    return {
      id: app.id,
      name: app.name,
      description: app.description,
      icon: app.icon,
      category: app.category,
      runtimeType: app.runtimeType,
      version: app.activePublishedVersion,
      entryUrl: version?.entryUrl || app.entryUrl,
      isAsset: app.isAsset,
      capabilities: app.capabilities || [],
      requestedPermissions: app.requestedPermissions || [],
      developerName: app.developerName,
      supportEmail: app.supportEmail,
      website: app.website,
      themeColor: app.themeColor,
      packageBaseUrl: version?.packageKey ? `/api/v1/miniapps/${appId}/${app.activePublishedVersion}/` : undefined,
      schemaVersion: version?.schemaVersion || 1,
      schema: version?.schema || null,
      updatedAt: app.updatedAt.toISOString(),
    };
  }

  /**
   * List unique categories with at least one published mini app
   */
  async getCategories(): Promise<string[]> {
    const apps = await this.appRepo.find({
      where: { status: MiniAppStatus.PUBLISHED, activePublishedVersion: Not(IsNull()) },
      select: ['category'],
    });

    const set = new Set<string>();
    set.add('All');
    for (const app of apps) {
      if (app.category) set.add(app.category);
    }

    return Array.from(set);
  }
}
