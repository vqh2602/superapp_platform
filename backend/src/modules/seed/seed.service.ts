import { Injectable, OnApplicationBootstrap, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { UserEntity } from '../../entities/user.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { hashPassword } from '../auth/auth.crypto';
import { sampleSchemas } from './sample-schemas';
import { PackageService, ValidatedPackage } from '../registry/packages/package.service';
import { createHash } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { testIcon } from '../registry/packages/test-package';

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    @InjectRepository(MiniAppEntity)
    private readonly appRepo: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity)
    private readonly versionRepo: Repository<MiniAppVersionEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @Optional()
    private readonly packageService?: PackageService,
  ) {}

  async onApplicationBootstrap() {
    await this.seedExistingApps();
    await this.seedDemoUser();
  }

  async seedDemoUser() {
    const email = 'test_demo@example.com';
    const existingUser = await this.userRepo.findOne({ where: { email } });
    if (!existingUser) {
      this.logger.log(`Seeding demo user: ${email}...`);
      const passwordHash = await hashPassword('demo-password-123');
      const user = this.userRepo.create({
        email,
        passwordHash,
        displayName: 'Demo User',
        avatarUrl: '',
      });
      await this.userRepo.save(user);
      this.logger.log(`Demo user ${email} seeded successfully.`);
    }
  }

  private getMiniAppBundle(appId: string): { html: Buffer; icon: Buffer } {
    const candidates = [
      path.resolve(process.cwd(), '../mini_apps', appId),
      path.resolve(process.cwd(), 'mini_apps', appId),
      path.resolve(__dirname, '../../../../mini_apps', appId),
    ];
    for (const dir of candidates) {
      const htmlPath = path.join(dir, 'dist/index.html');
      const iconPath = path.join(dir, 'icon.png');
      if (fs.existsSync(htmlPath)) {
        const html = fs.readFileSync(htmlPath);
        const icon = fs.existsSync(iconPath) ? fs.readFileSync(iconPath) : testIcon;
        return { html, icon };
      }
    }
    return {
      html: Buffer.from(`<!doctype html><html><head><meta charset="utf-8"><title>${appId}</title></head><body><div id="root"><h3>${appId} loaded</h3></div></body></html>`),
      icon: testIcon,
    };
  }

  private async ensurePackageStored(appId: string, version: string, manifest: any): Promise<string | undefined> {
    if (!this.packageService) return undefined;
    try {
      const existingVer = await this.versionRepo.findOne({ where: { appId, version } });
      if (existingVer?.packageKey) {
        try {
          await this.packageService.file(existingVer.packageKey, 'dist/index.html');
          return existingVer.packageKey;
        } catch (_) {
          // File missing from storage, proceed to re-store
        }
      }

      const bundle = this.getMiniAppBundle(appId);
      const files = new Map<string, Buffer>();
      files.set('app.json', Buffer.from(JSON.stringify(manifest, null, 2)));
      files.set('icon.png', bundle.icon);
      files.set('dist/index.html', bundle.html);

      const checksum = createHash('sha256').update(bundle.html).digest('hex');
      const validatedPkg: ValidatedPackage = {
        manifest,
        files,
        checksum,
        size: bundle.html.length + bundle.icon.length,
      };

      const packageKey = await this.packageService.store(validatedPkg);
      this.logger.log(`Stored backend package for ${appId} v${version} with key: ${packageKey}`);
      return packageKey;
    } catch (err: any) {
      this.logger.warn(`Could not store package for ${appId}: ${err?.message || err}`);
      return undefined;
    }
  }

  async seedExistingApps() {
    this.logger.log('Checking & seeding initial Mini Apps in Registry (Remote Backend Hosted)...');

    // 0. Seed Schema Runtime (Host engine for all No-Code schema apps)
    const schemaRuntimeManifest = {
      manifestVersion: 1,
      appId: 'schema_runtime',
      name: 'Schema Runtime Engine',
      description: 'Dynamic No-Code Schema execution engine for SuperApp',
      category: 'Developer Tools',
      version: '1.0.0',
      runtimeType: MiniAppRuntimeType.WEB,
      entry: 'dist/index.html',
      icon: 'icon.png',
      permissions: ['navigation.close', 'navigation.openMiniApp', 'showToast', 'configAppView'],
    };
    const schemaRuntimePkgKey = await this.ensurePackageStored('schema_runtime', '1.0.0', schemaRuntimeManifest);

    let schemaRuntimeApp = await this.appRepo.findOne({ where: { id: 'schema_runtime' } });
    if (!schemaRuntimeApp) {
      schemaRuntimeApp = this.appRepo.create({
        id: 'schema_runtime',
        name: 'Schema Runtime Engine',
        description: 'Dynamic No-Code Schema execution engine for SuperApp',
        icon: 'code',
        category: 'Developer Tools',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
        entryUrl: '/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html',
        isAsset: false,
        capabilities: schemaRuntimeManifest.permissions,
      });
      await this.appRepo.save(schemaRuntimeApp);

      const ver = this.versionRepo.create({
        appId: 'schema_runtime',
        version: '1.0.0',
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: '/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html',
        capabilities: schemaRuntimeManifest.permissions,
        packageKey: schemaRuntimePkgKey,
        manifest: schemaRuntimeManifest,
        reviewNotes: 'Seeded schema runtime package',
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else if (schemaRuntimePkgKey && !schemaRuntimeApp.entryUrl.includes('/api/v1/miniapps/')) {
      schemaRuntimeApp.entryUrl = '/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html';
      schemaRuntimeApp.isAsset = false;
      await this.appRepo.save(schemaRuntimeApp);
    }

    // 1. Seed SDK Playground
    const playgroundManifest = {
      manifestVersion: 1,
      appId: 'sdk_playground',
      name: 'SDK Playground',
      description: 'React + TypeScript Mini App test bed with interactive SDK runner',
      category: 'Developer Tools',
      version: '1.0.0',
      runtimeType: MiniAppRuntimeType.WEB,
      entry: 'dist/index.html',
      icon: 'icon.png',
      permissions: [
        'auth.requestCode',
        'user.getProfile',
        'user.getBasicInfo',
        'navigation.openNativePage',
        'navigation.close',
        'navigation.openMiniApp',
        'device.scanQRCode',
        'device.getLocation',
        'device.pickImage',
        'permission.request',
        'permission.getPermissions',
        'storage.setSecureItem',
        'storage.getSecureItem',
        'storage.removeSecureItem',
        'storage.clear',
        'storage.setCredentials',
        'storage.getCredentials',
        'storage.deleteCredentials',
        'storage.secure',
        'contacts',
        'device.scanQr',
        'scanQr',
        'device.scanBarcode',
        'scanBarcode',
        'getPhoto',
        'pickImages',
        'saveImageToGallery',
        'pickVideo',
        'saveVideoToGallery',
        'saveFile',
        'pickFile',
        'filePreview',
        'showToast',
        'vibrate',
        'copyToClipboard',
        'setBrightness',
        'setStatusBarStyle',
        'setStatusBarColor',
        'setNavigationBarColor',
        'configAppView',
        'showMiniappMenu',
        'closeApp',
        'getNetworkInfo',
        'getDeviceLanguage',
        'getSuperAppSettings',
        'getSystemInfo',
        'getAppInfo',
        'getBatteryInfo',
        'getContacts',
        'setSecretData',
        'getSecretData',
        'removeSecretData',
        'microphone',
        'openPhone',
        'openSMS',
        'openExternalBrowser',
        'openDeepLink',
        'speechToText',
        'hideKeyboard',
        'debug.echo',
        'debug.simulateFailure',
      ],
    };
    const playgroundPkgKey = await this.ensurePackageStored('sdk_playground', '1.0.0', playgroundManifest);

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
        entryUrl: '/api/v1/miniapps/sdk_playground/1.0.0/dist/index.html',
        isAsset: false,
        capabilities: playgroundManifest.permissions,
      });
      await this.appRepo.save(playground);

      const ver = this.versionRepo.create({
        appId: 'sdk_playground',
        version: '1.0.0',
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: '/api/v1/miniapps/sdk_playground/1.0.0/dist/index.html',
        capabilities: playground.capabilities,
        packageKey: playgroundPkgKey,
        manifest: playgroundManifest,
        reviewNotes: 'Seeded system initial app',
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      // Migrate legacy asset URLs if previously seeded as asset
      if (existingPlayground.isAsset || existingPlayground.entryUrl.startsWith('assets/')) {
        this.logger.log('Migrating sdk_playground from assets/ to BE remote package URL...');
        existingPlayground.entryUrl = '/api/v1/miniapps/sdk_playground/1.0.0/dist/index.html';
        existingPlayground.isAsset = false;
        await this.appRepo.save(existingPlayground);

        const ver = await this.versionRepo.findOne({ where: { appId: 'sdk_playground', version: '1.0.0' } });
        if (ver) {
          ver.entryUrl = '/api/v1/miniapps/sdk_playground/1.0.0/dist/index.html';
          if (playgroundPkgKey) ver.packageKey = playgroundPkgKey;
          await this.versionRepo.save(ver);
        }
      }
    }

    // 2. Seed Sample Store
    const storeManifest = {
      manifestVersion: 1,
      appId: 'sample_store',
      name: 'Sample Mini App 2 (Store)',
      description: 'Secondary Mini App to demonstrate cross-mini-app native switching',
      category: 'Food & Beverage',
      version: '1.0.0',
      runtimeType: MiniAppRuntimeType.WEB,
      entry: 'dist/index.html',
      icon: 'icon.png',
      permissions: ['user.getBasicInfo', 'navigation.close'],
    };
    const storePkgKey = await this.ensurePackageStored('sample_store', '1.0.0', storeManifest);

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
        entryUrl: '/api/v1/miniapps/sample_store/1.0.0/dist/index.html',
        isAsset: false,
        capabilities: storeManifest.permissions,
      });
      await this.appRepo.save(store);

      const ver = this.versionRepo.create({
        appId: 'sample_store',
        version: '1.0.0',
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: '/api/v1/miniapps/sample_store/1.0.0/dist/index.html',
        capabilities: store.capabilities,
        packageKey: storePkgKey,
        manifest: storeManifest,
        reviewNotes: 'Seeded system store app',
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      if (existingStore.isAsset || existingStore.entryUrl.startsWith('assets/')) {
        this.logger.log('Migrating sample_store from assets/ to BE remote package URL...');
        existingStore.entryUrl = '/api/v1/miniapps/sample_store/1.0.0/dist/index.html';
        existingStore.isAsset = false;
        await this.appRepo.save(existingStore);

        const ver = await this.versionRepo.findOne({ where: { appId: 'sample_store', version: '1.0.0' } });
        if (ver) {
          ver.entryUrl = '/api/v1/miniapps/sample_store/1.0.0/dist/index.html';
          if (storePkgKey) ver.packageKey = storePkgKey;
          await this.versionRepo.save(ver);
        }
      }
    }

    // 3. Seed Schema Mini Apps (Shopee, TikTok, Coffee House, Viettel Tammi, Free Fire, CapCut, Messenger...)
    const schemaEntryUrl = '/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html';
    for (const [appId, data] of Object.entries(sampleSchemas)) {
      const existing = await this.appRepo.findOne({ where: { id: appId } });
      if (!existing) {
        this.logger.log(`Seeding Schema Mini App: ${appId} (schema)...`);
        const schemaApp = this.appRepo.create({
          id: appId,
          name: data.name,
          description: data.description,
          icon: data.icon,
          category: data.category,
          tenantId: 'system_core',
          runtimeType: MiniAppRuntimeType.SCHEMA,
          status: MiniAppStatus.PUBLISHED,
          activePublishedVersion: '1.0.0',
          entryUrl: schemaEntryUrl,
          isAsset: false,
          capabilities: data.capabilities,
        });
        await this.appRepo.save(schemaApp);

        const version = this.versionRepo.create({
          appId,
          version: '1.0.0',
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          schema: data.schema,
          entryUrl: schemaEntryUrl,
          capabilities: data.capabilities,
          reviewNotes: `Seeded ${data.name} schema app`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(version);
      } else {
        if (existing.isAsset || existing.entryUrl.startsWith('assets/')) {
          existing.entryUrl = schemaEntryUrl;
          existing.isAsset = false;
          await this.appRepo.save(existing);

          const ver = await this.versionRepo.findOne({ where: { appId, version: '1.0.0' } });
          if (ver) {
            ver.entryUrl = schemaEntryUrl;
            await this.versionRepo.save(ver);
          }
        }
      }
    }

    this.logger.log('Seeding completed successfully: all Mini Apps configured for remote Backend hosting.');
  }
}
