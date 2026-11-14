import { BadRequestException, Controller, ForbiddenException, Get, NotFoundException, Param, Req, Res } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Request, Response } from 'express';
import { extname } from 'path';
import { createHash } from 'crypto';
import { MiniAppEntity } from '../../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../../entities/mini-app-version.entity';
import { MiniAppStatus } from '../../../entities/enums';
import { PackageService, safePackagePath } from './package.service';

interface CachedAppSnapshot {
  app: MiniAppEntity | null;
  snapshot: MiniAppVersionEntity | null;
  expiresAt: number;
}

@Controller('api/v1/miniapps')
export class PackageAssetsController {
  private readonly appVersionCache = new Map<string, CachedAppSnapshot>();
  private static readonly CACHE_TTL_MS = 60 * 1000; // 60s cache eliminates N+1 DB queries per asset batch

  constructor(
    @InjectRepository(MiniAppEntity) private readonly apps: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity) private readonly versions: Repository<MiniAppVersionEntity>,
    private readonly packages: PackageService,
  ) {}

  private async getAppAndSnapshot(appId: string, version: string) {
    const cacheKey = `${appId}:${version}`;
    const now = Date.now();
    const cached = this.appVersionCache.get(cacheKey);
    if (cached && cached.expiresAt > now) {
      return [cached.app, cached.snapshot] as const;
    }

    const [app, snapshot] = await Promise.all([
      this.apps.findOneBy({ id: appId }),
      this.versions.findOneBy({ appId, version }),
    ]);

    this.appVersionCache.set(cacheKey, {
      app,
      snapshot,
      expiresAt: now + PackageAssetsController.CACHE_TTL_MS,
    });

    return [app, snapshot] as const;
  }

  @Get(':appId/:version/*')
  async file(
    @Param('appId') appId: string,
    @Param('version') version: string,
    @Param('0') filename: string,
    @Res() response: Response,
    @Req() request?: Request,
  ) {
    if (!safePackagePath(filename)) throw new BadRequestException('Invalid asset path');
    const [app, snapshot] = await this.getAppAndSnapshot(appId, version);
    if (!app || !snapshot) throw new NotFoundException('Mini App not found');
    if (filename !== snapshot.manifest?.icon && (app.status !== MiniAppStatus.PUBLISHED || app.activePublishedVersion !== version)) {
      throw new ForbiddenException('Mini App or version is not active');
    }
    const key = snapshot.packageKey || `${appId}-${version}`;
    try {
      const buffer = await this.packages.file(key, filename);
      const ext = extname(filename).toLowerCase();
      const etag = `"${createHash('sha256').update(buffer).digest('hex').substring(0, 16)}"`;

      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('ETag', etag);

      // HTML entrypoint requires revalidation so updates take effect immediately.
      // Versioned static assets (JS chunks, CSS, images, wasm, fonts) are immutable.
      if (filename === 'dist/index.html' || ext === '.html') {
        response.setHeader('Cache-Control', 'no-cache');
      } else {
        response.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      }

      if (request?.headers?.['if-none-match'] === etag) {
        return response.status(304).end();
      }

      response.type(ext).send(buffer);
    } catch (error: any) {
      if (error?.code === 'ENOENT' || error?.code === 'ENOTDIR') throw new NotFoundException('File not found');
      throw error;
    }
  }
}
