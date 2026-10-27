import { AuthModule } from './modules/auth/auth.module';
import { UserEntity } from './entities/user.entity';
import { AuthSessionEntity } from './entities/auth-session.entity';
import { UserMiniAppPermissionEntity } from './entities/user-miniapp-permission.entity';
import { MiniAppAuthCodeEntity } from './entities/miniapp-auth-code.entity';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MiniAppEntity } from './entities/mini-app.entity';
import { MiniAppVersionEntity } from './entities/mini-app-version.entity';
import { ReviewAuditEntity } from './entities/review-audit.entity';
import { RegistryModule } from './modules/registry/registry.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { SeedModule } from './modules/seed/seed.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      username: process.env.DB_USERNAME || process.env.USER || 'vuongquanghuy',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_DATABASE || 'superapp_registry',
      entities: [MiniAppEntity, MiniAppVersionEntity, ReviewAuditEntity, UserEntity, AuthSessionEntity, UserMiniAppPermissionEntity, MiniAppAuthCodeEntity],
      synchronize: true, // Development schema auto-sync
      logging: false,
    }),
    AuthModule,
    RegistryModule,
    CatalogModule,
    SeedModule,
  ],
})
export class AppModule {}
