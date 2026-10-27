import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { PackageService } from './packages/package.service';
import { PackageAssetsController } from './packages/package-assets.controller';
import { RegistryService } from './registry.service';
import { RegistryController } from './registry.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MiniAppEntity,
      MiniAppVersionEntity,
    ]),
  ],
  controllers: [RegistryController, PackageAssetsController],
  providers: [RegistryService, PackageService],
  exports: [RegistryService],
})
export class RegistryModule {}
