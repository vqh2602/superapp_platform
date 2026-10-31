import { Injectable, OnApplicationBootstrap, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { UserEntity } from '../../entities/user.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { sampleSchemas } from './sample-schemas';
import { PackageService, ValidatedPackage } from '../registry/packages/package.service';
import { createHash } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

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
  }

  private getSystemManifest(appId: string, version: string) {
    for (const root of ['seed-bundles', '../mini_apps', 'mini_apps']) {
      const file = path.resolve(process.cwd(), root, appId, 'app.json');
      if (fs.existsSync(file)) {
        const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
        if (manifest.appId !== appId || manifest.version !== version) {
          throw new Error(`System Mini App manifest mismatch: ${appId} v${version}`);
        }
        return manifest;
      }
    }
    throw new Error(`Missing system Mini App manifest: ${appId}`);
  }

  private getMiniAppBundle(appId: string): { html: Buffer; icon: Buffer; allFiles: Map<string, Buffer> } {
    const candidates = [
      path.resolve(process.cwd(), 'seed-bundles', appId),
      path.resolve(process.cwd(), '../mini_apps', appId),
      path.resolve(process.cwd(), 'mini_apps', appId),
      path.resolve(__dirname, '../../../../mini_apps', appId),
    ];
    for (const dir of candidates) {
      const htmlPath = path.join(dir, 'dist/index.html');
      const iconPath = path.join(dir, 'icon.png');
      const distDir = path.join(dir, 'dist');
      if (fs.existsSync(htmlPath)) {
        const html = fs.readFileSync(htmlPath);
        if (!fs.existsSync(iconPath)) throw new Error(`Missing icon for ${appId}`);
        const icon = fs.readFileSync(iconPath);
        const allFiles = new Map<string, Buffer>();

        const collectFiles = (curDir: string, relPrefix: string = '') => {
          if (!fs.existsSync(curDir)) return;
          const entries = fs.readdirSync(curDir, { withFileTypes: true });
          for (const ent of entries) {
            const full = path.join(curDir, ent.name);
            const rel = relPrefix ? `${relPrefix}/${ent.name}` : ent.name;
            if (ent.isDirectory()) {
              collectFiles(full, rel);
            } else if (ent.isFile()) {
              allFiles.set(`dist/${rel}`, fs.readFileSync(full));
            }
          }
        };

        collectFiles(distDir);
        return { html, icon, allFiles };
      }
    }
    throw new Error(`Missing built bundle for ${appId}. Run npm run build:miniapps before deploying the backend.`);
  }

  private async ensurePackageStored(appId: string, version: string, manifest: any): Promise<string | undefined> {
    if (!this.packageService) return undefined;
    try {
      const bundle = this.getMiniAppBundle(appId);
      const existingVer = await this.versionRepo.findOne({ where: { appId, version } });
      const files = new Map<string, Buffer>();
      files.set('app.json', Buffer.from(JSON.stringify(manifest, null, 2)));
      files.set('icon.png', bundle.icon);
      for (const [filePath, content] of bundle.allFiles) {
        files.set(filePath, content);
      }

      if (existingVer?.packageKey) {
        try {
          const unchanged = await Promise.all([...files].map(async ([name, content]) =>
            (await this.packageService.file(existingVer.packageKey, name)).equals(content)));
          if (unchanged.every(Boolean)) return existingVer.packageKey;
        } catch (_) {
          // Missing/stale assets (including JS/WASM) must trigger a complete repair.
        }
      }
      const hash = createHash('sha256');
      let totalSize = 0;
      for (const name of [...files.keys()].sort()) {
        const content = files.get(name)!;
        hash.update(name).update('\0').update(String(content.length)).update('\0').update(content);
        totalSize += content.length;
      }
      const checksum = hash.digest('hex');

      const validatedPkg: ValidatedPackage = {
        manifest,
        files,
        checksum,
        size: totalSize,
      };

      const packageKey = await this.packageService.store(validatedPkg);
      if (existingVer) {
        existingVer.packageKey = packageKey;
        existingVer.checksum = checksum;
        existingVer.packageSize = validatedPkg.size;
        existingVer.manifest = manifest;
        existingVer.capabilities = manifest.permissions;
        await this.versionRepo.save(existingVer);
      }
      this.logger.log(`Stored backend package for ${appId} v${version} with key: ${packageKey}`);
      return packageKey;
    } catch (err: any) {
      this.logger.warn(`Could not store package for ${appId}: ${err?.message || err}`);
      throw err;
    }
  }

  async seedExistingApps() {
    this.logger.log('Checking & seeding initial Mini Apps in Registry v1.0.5 (Remote Backend Hosted)...');
    const targetVersion = '1.0.5';

    // 0. Seed Schema Runtime (Host engine for all No-Code schema apps)
    const schemaRuntimeManifest = this.getSystemManifest('schema_runtime', targetVersion);
    const schemaRuntimePkgKey = await this.ensurePackageStored('schema_runtime', targetVersion, schemaRuntimeManifest);

    let schemaRuntimeApp = await this.appRepo.findOne({ where: { id: 'schema_runtime' } });
    if (!schemaRuntimeApp) {
      schemaRuntimeApp = this.appRepo.create({
        id: 'schema_runtime',
        name: schemaRuntimeManifest.name,
        description: schemaRuntimeManifest.description,
        icon: 'code',
        category: 'Developer Tools',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: targetVersion,
        entryUrl: `/api/v1/miniapps/schema_runtime/${targetVersion}/dist/index.html`,
        isAsset: false,
        capabilities: schemaRuntimeManifest.permissions,
      });
      await this.appRepo.save(schemaRuntimeApp);

      const ver = this.versionRepo.create({
        appId: 'schema_runtime',
        version: targetVersion,
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: `/api/v1/miniapps/schema_runtime/${targetVersion}/dist/index.html`,
        capabilities: schemaRuntimeManifest.permissions,
        packageKey: schemaRuntimePkgKey,
        manifest: schemaRuntimeManifest,
        reviewNotes: `Seeded schema runtime package v${targetVersion}`,
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      schemaRuntimeApp.name = schemaRuntimeManifest.name;
      schemaRuntimeApp.description = schemaRuntimeManifest.description;
      schemaRuntimeApp.category = schemaRuntimeManifest.category;
      schemaRuntimeApp.capabilities = schemaRuntimeManifest.permissions;
      schemaRuntimeApp.activePublishedVersion = targetVersion;
      schemaRuntimeApp.entryUrl = `/api/v1/miniapps/schema_runtime/${targetVersion}/dist/index.html`;
      schemaRuntimeApp.isAsset = false;
      await this.appRepo.save(schemaRuntimeApp);

      let ver = await this.versionRepo.findOne({ where: { appId: 'schema_runtime', version: targetVersion } });
      if (!ver) {
        ver = this.versionRepo.create({
          appId: 'schema_runtime',
          version: targetVersion,
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          entryUrl: `/api/v1/miniapps/schema_runtime/${targetVersion}/dist/index.html`,
          capabilities: schemaRuntimeManifest.permissions,
          packageKey: schemaRuntimePkgKey,
          manifest: schemaRuntimeManifest,
          reviewNotes: `Seeded schema runtime package v${targetVersion}`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(ver);
      } else if (schemaRuntimePkgKey && !ver.packageKey) {
        ver.packageKey = schemaRuntimePkgKey;
        await this.versionRepo.save(ver);
      }
    }

    // 1. Seed SDK Playground
    const playgroundManifest = this.getSystemManifest('sdk_playground', targetVersion);
    const playgroundPkgKey = await this.ensurePackageStored('sdk_playground', targetVersion, playgroundManifest);

    let existingPlayground = await this.appRepo.findOne({
      where: { id: 'sdk_playground' },
    });

    if (!existingPlayground) {
      this.logger.log(`Seeding existing Mini App: sdk_playground (web v${targetVersion})...`);
      existingPlayground = this.appRepo.create({
        id: 'sdk_playground',
        name: playgroundManifest.name,
        description: playgroundManifest.description,
        icon: 'code',
        category: 'Developer Tools',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: targetVersion,
        entryUrl: `/api/v1/miniapps/sdk_playground/${targetVersion}/dist/index.html`,
        isAsset: false,
        capabilities: playgroundManifest.permissions,
      });
      await this.appRepo.save(existingPlayground);

      const ver = this.versionRepo.create({
        appId: 'sdk_playground',
        version: targetVersion,
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: `/api/v1/miniapps/sdk_playground/${targetVersion}/dist/index.html`,
        capabilities: existingPlayground.capabilities,
        packageKey: playgroundPkgKey,
        manifest: playgroundManifest,
        reviewNotes: `Seeded system initial app v${targetVersion}`,
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      existingPlayground.name = playgroundManifest.name;
      existingPlayground.description = playgroundManifest.description;
      existingPlayground.category = playgroundManifest.category;
      existingPlayground.capabilities = playgroundManifest.permissions;
      existingPlayground.activePublishedVersion = targetVersion;
      existingPlayground.entryUrl = `/api/v1/miniapps/sdk_playground/${targetVersion}/dist/index.html`;
      existingPlayground.isAsset = false;
      await this.appRepo.save(existingPlayground);

      let ver = await this.versionRepo.findOne({ where: { appId: 'sdk_playground', version: targetVersion } });
      if (!ver) {
        ver = this.versionRepo.create({
          appId: 'sdk_playground',
          version: targetVersion,
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          entryUrl: `/api/v1/miniapps/sdk_playground/${targetVersion}/dist/index.html`,
          capabilities: existingPlayground.capabilities,
          packageKey: playgroundPkgKey,
          manifest: playgroundManifest,
          reviewNotes: `Seeded system initial app v${targetVersion}`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(ver);
      } else if (playgroundPkgKey && !ver.packageKey) {
        ver.packageKey = playgroundPkgKey;
        await this.versionRepo.save(ver);
      }
    }

    // 2. Seed Sample Store
    const storeManifest = this.getSystemManifest('sample_store', targetVersion);
    const storePkgKey = await this.ensurePackageStored('sample_store', targetVersion, storeManifest);

    let existingStore = await this.appRepo.findOne({
      where: { id: 'sample_store' },
    });

    if (!existingStore) {
      this.logger.log(`Seeding existing Mini App: sample_store (web v${targetVersion})...`);
      existingStore = this.appRepo.create({
        id: 'sample_store',
        name: storeManifest.name,
        description: storeManifest.description,
        icon: 'storefront',
        category: 'Food & Beverage',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: targetVersion,
        entryUrl: `/api/v1/miniapps/sample_store/${targetVersion}/dist/index.html`,
        isAsset: false,
        capabilities: storeManifest.permissions,
      });
      await this.appRepo.save(existingStore);

      const ver = this.versionRepo.create({
        appId: 'sample_store',
        version: targetVersion,
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: `/api/v1/miniapps/sample_store/${targetVersion}/dist/index.html`,
        capabilities: existingStore.capabilities,
        packageKey: storePkgKey,
        manifest: storeManifest,
        reviewNotes: `Seeded system store app v${targetVersion}`,
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      existingStore.name = storeManifest.name;
      existingStore.description = storeManifest.description;
      existingStore.category = storeManifest.category;
      existingStore.capabilities = storeManifest.permissions;
      existingStore.activePublishedVersion = targetVersion;
      existingStore.entryUrl = `/api/v1/miniapps/sample_store/${targetVersion}/dist/index.html`;
      existingStore.isAsset = false;
      await this.appRepo.save(existingStore);

      let ver = await this.versionRepo.findOne({ where: { appId: 'sample_store', version: targetVersion } });
      if (!ver) {
        ver = this.versionRepo.create({
          appId: 'sample_store',
          version: targetVersion,
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          entryUrl: `/api/v1/miniapps/sample_store/${targetVersion}/dist/index.html`,
          capabilities: existingStore.capabilities,
          packageKey: storePkgKey,
          manifest: storeManifest,
          reviewNotes: `Seeded system store app v${targetVersion}`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(ver);
      } else if (storePkgKey && !ver.packageKey) {
        ver.packageKey = storePkgKey;
        await this.versionRepo.save(ver);
      }
    }

    // 2b. Seed Flutter Web Scanner (Native Bridge QR & Barcode Scanner)
    const scannerManifest = this.getSystemManifest('flutter_scanner', targetVersion);
    const scannerPkgKey = await this.ensurePackageStored('flutter_scanner', targetVersion, scannerManifest);

    let existingScanner = await this.appRepo.findOne({ where: { id: 'flutter_scanner' } });
    if (!existingScanner) {
      this.logger.log(`Seeding existing Mini App: flutter_scanner (flutter web v${targetVersion})...`);
      existingScanner = this.appRepo.create({
        id: 'flutter_scanner',
        name: scannerManifest.name,
        description: scannerManifest.description,
        icon: 'qr_code_scanner',
        category: 'Utilities',
        tenantId: 'system_core',
        runtimeType: MiniAppRuntimeType.WEB,
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: targetVersion,
        entryUrl: `/api/v1/miniapps/flutter_scanner/${targetVersion}/dist/index.html`,
        isAsset: false,
        capabilities: scannerManifest.permissions,
      });
      await this.appRepo.save(existingScanner);

      const ver = this.versionRepo.create({
        appId: 'flutter_scanner',
        version: targetVersion,
        schemaVersion: 1,
        status: MiniAppStatus.PUBLISHED,
        entryUrl: `/api/v1/miniapps/flutter_scanner/${targetVersion}/dist/index.html`,
        capabilities: existingScanner.capabilities,
        packageKey: scannerPkgKey,
        manifest: scannerManifest,
        reviewNotes: `Seeded system flutter scanner app v${targetVersion}`,
        publishedAt: new Date(),
      });
      await this.versionRepo.save(ver);
    } else {
      existingScanner.name = scannerManifest.name;
      existingScanner.description = scannerManifest.description;
      existingScanner.category = scannerManifest.category;
      existingScanner.capabilities = scannerManifest.permissions;
      existingScanner.activePublishedVersion = targetVersion;
      existingScanner.entryUrl = `/api/v1/miniapps/flutter_scanner/${targetVersion}/dist/index.html`;
      existingScanner.isAsset = false;
      await this.appRepo.save(existingScanner);

      let ver = await this.versionRepo.findOne({ where: { appId: 'flutter_scanner', version: targetVersion } });
      if (!ver) {
        ver = this.versionRepo.create({
          appId: 'flutter_scanner',
          version: targetVersion,
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          entryUrl: `/api/v1/miniapps/flutter_scanner/${targetVersion}/dist/index.html`,
          capabilities: existingScanner.capabilities,
          packageKey: scannerPkgKey,
          manifest: scannerManifest,
          reviewNotes: `Seeded system flutter scanner app v${targetVersion}`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(ver);
      } else if (scannerPkgKey && !ver.packageKey) {
        ver.packageKey = scannerPkgKey;
        await this.versionRepo.save(ver);
      }
    }

    // 3. Seed Schema Mini Apps (Shopee, TikTok, Coffee House, Viettel Tammi, Free Fire, CapCut, Messenger...)
    const schemaEntryUrl = `/api/v1/miniapps/schema_runtime/${targetVersion}/dist/index.html`;
    for (const [appId, data] of Object.entries(sampleSchemas)) {
      let existing = await this.appRepo.findOne({ where: { id: appId } });
      if (!existing) {
        this.logger.log(`Seeding Schema Mini App: ${appId} (schema v${targetVersion})...`);
        existing = this.appRepo.create({
          id: appId,
          name: data.name,
          description: data.description,
          icon: data.icon,
          category: data.category,
          tenantId: 'system_core',
          runtimeType: MiniAppRuntimeType.SCHEMA,
          status: MiniAppStatus.PUBLISHED,
          activePublishedVersion: targetVersion,
          entryUrl: schemaEntryUrl,
          isAsset: false,
          capabilities: data.capabilities,
        });
        await this.appRepo.save(existing);

        const version = this.versionRepo.create({
          appId,
          version: targetVersion,
          schemaVersion: 1,
          status: MiniAppStatus.PUBLISHED,
          schema: data.schema,
          entryUrl: schemaEntryUrl,
          capabilities: data.capabilities,
          reviewNotes: `Seeded ${data.name} schema app v${targetVersion}`,
          publishedAt: new Date(),
        });
        await this.versionRepo.save(version);
      } else {
        existing.activePublishedVersion = targetVersion;
        existing.entryUrl = schemaEntryUrl;
        existing.isAsset = false;
        await this.appRepo.save(existing);

        let ver = await this.versionRepo.findOne({ where: { appId, version: targetVersion } });
        if (!ver) {
          ver = this.versionRepo.create({
            appId,
            version: targetVersion,
            schemaVersion: 1,
            status: MiniAppStatus.PUBLISHED,
            schema: data.schema,
            entryUrl: schemaEntryUrl,
            capabilities: data.capabilities,
            reviewNotes: `Seeded ${data.name} schema app v${targetVersion}`,
            publishedAt: new Date(),
          });
          await this.versionRepo.save(ver);
        } else {
          ver.entryUrl = schemaEntryUrl;
          await this.versionRepo.save(ver);
        }
      }
    }

    this.logger.log(`Seeding completed successfully: all Mini Apps configured for remote Backend hosting (v${targetVersion}).`);
  }
}
