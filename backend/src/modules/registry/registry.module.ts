import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { ReviewAuditEntity } from '../../entities/review-audit.entity';
import { RegistryService } from './registry.service';
import { RegistryController } from './registry.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      MiniAppEntity,
      MiniAppVersionEntity,
      ReviewAuditEntity,
    ]),
  ],
  controllers: [RegistryController],
  providers: [RegistryService],
  exports: [RegistryService],
})
export class RegistryModule {}
