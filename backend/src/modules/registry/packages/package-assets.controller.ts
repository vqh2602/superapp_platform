import { BadRequestException, Controller, ForbiddenException, Get, NotFoundException, Param, Res } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Response } from 'express';
import { extname } from 'path';
import { MiniAppEntity } from '../../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../../entities/mini-app-version.entity';
import { MiniAppStatus } from '../../../entities/enums';
import { PackageService, safePackagePath } from './package.service';

@Controller('api/v1/miniapps')
export class PackageAssetsController {
  constructor(
    @InjectRepository(MiniAppEntity) private readonly apps: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity) private readonly versions: Repository<MiniAppVersionEntity>,
    private readonly packages: PackageService,
  ) {}

  @Get(':appId/:version/*')
  async file(@Param('appId') appId: string, @Param('version') version: string, @Param('0') filename: string, @Res() response: Response) {
    if (!safePackagePath(filename)) throw new BadRequestException('Invalid asset path');
    const [app, snapshot] = await Promise.all([
      this.apps.findOneBy({ id: appId }), this.versions.findOneBy({ appId, version }),
    ]);
    if (!app || !snapshot?.packageKey) throw new NotFoundException('Package not found');
    // Icons remain visible in management while the app itself is hidden.
    if (filename !== snapshot.manifest?.icon && (app.status !== MiniAppStatus.PUBLISHED || app.activePublishedVersion !== version)) {
      throw new ForbiddenException('Mini App or version is not active');
    }
    try {
      const buffer = await this.packages.file(snapshot.packageKey, filename);
      response.setHeader('X-Content-Type-Options', 'nosniff');
      response.setHeader('Cache-Control', 'no-store');
      response.type(extname(filename)).send(buffer);
    } catch (error) {
      if (error.code === 'ENOENT' || error.code === 'ENOTDIR') throw new NotFoundException('File not found');
      throw error;
    }
  }
}
