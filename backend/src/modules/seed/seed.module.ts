import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { UserEntity } from '../../entities/user.entity';
import { SeedService } from './seed.service';

@Module({
  imports: [TypeOrmModule.forFeature([MiniAppEntity, MiniAppVersionEntity, UserEntity])],
  providers: [SeedService],
  exports: [SeedService],
})
export class SeedModule {}
