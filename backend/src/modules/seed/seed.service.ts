import { Injectable, OnApplicationBootstrap, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    @InjectRepository(MiniAppEntity)
    private readonly appRepo: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity)
    private readonly versionRepo: Repository<MiniAppVersionEntity>,
  ) {}

  async onApplicationBootstrap() {
    await this.seedExistingApps();
  }

  async seedExistingApps() {
    this.logger.log('Checking & seeding initial Mini Apps in Registry...');

    // 1. Seed SDK Playground
    const existingPlayground = await this.appRepo.findOne({
      where: { id: 'sdk_playground' },
    });

    if (!existingPlayground) {
      this.logger.log('Seeding existing Mini App: sdk_playground (web)...');
      const playground = this.appRepo.create({
        id: 'sdk_playground',
        name: 'SDK Playground',
        description: 'React + TypeScript Mini App test bed with interactive SDK runner',
        icon: 'code',
        category: 'Developer Tools',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
        entryUrl: 'assets/mini_apps/sdk_playground/index.html',
        isAsset: true,
        capabilities: [
          'auth.requestCode',
          'user.getProfile',
          'user.getBasicInfo',
          'navigation.openNativePage',
          'navigation.close',
          'navigation.openMiniApp',
          'device.scanQRCode',
          'device.getLocation',
          'device.pickImage',
          'payment.createOrder',
          'payment.openCheckout',
          'permission.request',
          'debug.echo',
          'debug.simulateFailure',
        ],
      });
      await this.appRepo.save(playground);

      const ver = this.versionRepo.create({
        appId: 'sdk_playground',
        version: '1.0.0',
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: 'assets/mini_apps/sdk_playground/index.html',
        capabilities: playground.capabilities,
        reviewNotes: 'Seeded system initial app',
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    }

    // 2. Seed Sample Store
    const existingStore = await this.appRepo.findOne({
      where: { id: 'sample_store' },
    });

    if (!existingStore) {
      this.logger.log('Seeding existing Mini App: sample_store (web)...');
      const store = this.appRepo.create({
        id: 'sample_store',
        name: 'Sample Mini App 2 (Store)',
        description: 'Secondary Mini App to demonstrate cross-mini-app native switching',
        icon: 'storefront',
        category: 'Food & Beverage',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
        entryUrl: 'assets/mini_apps/sample_store/index.html',
        isAsset: true,
        capabilities: [
          'user.getBasicInfo',
          'navigation.close',
          'payment.createOrder',
          'payment.openCheckout',
        ],
      });
      await this.appRepo.save(store);

      const ver = this.versionRepo.create({
        appId: 'sample_store',
        version: '1.0.0',
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: 'assets/mini_apps/sample_store/index.html',
        capabilities: store.capabilities,
        reviewNotes: 'Seeded system store app',
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    }

    this.logger.log('Seeding completed successfully.');
  }
}
