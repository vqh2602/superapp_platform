import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { MiniAppStatus, MiniAppRuntimeType } from './enums';
import { MiniAppVersionEntity } from './mini-app-version.entity';

@Entity('mini_apps')
export class MiniAppEntity {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  id: string; // e.g. "coffee_shop", "sdk_playground"

  @Column({ type: 'varchar', length: 128 })
  name: string;

  @Column({ type: 'text', default: '' })
  description: string;

  @Column({ type: 'varchar', length: 512, default: 'code' })
  icon: string;

  @Column({ type: 'varchar', length: 64, default: 'General' })
  category: string;

  @Column({ type: 'varchar', length: 64, default: 'default_tenant' })
  tenantId: string;

  @Column({
    type: 'varchar',
    length: 16,
    default: MiniAppRuntimeType.SCHEMA,
  })
  runtimeType: MiniAppRuntimeType;

  @Column({
    type: 'varchar',
    length: 20,
    default: MiniAppStatus.DRAFT,
  })
  status: MiniAppStatus;

  @Column({ type: 'varchar', length: 32, nullable: true })
  activePublishedVersion?: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  entryUrl?: string | null; // For web mini apps

  @Column({ type: 'boolean', default: false })
  isAsset: boolean; // Bundled inside Flutter assets?

  @Column({ type: 'simple-array', default: '' })
  capabilities: string[];

  @Column({ type: 'simple-array', default: '' })
  requestedPermissions: string[];

  @Column({ type: 'varchar', length: 128, default: '' })
  developerName: string;

  @Column({ type: 'varchar', length: 254, default: '' })
  supportEmail: string;

  @Column({ type: 'varchar', length: 512, default: '' })
  website: string;

  @Column({ type: 'varchar', length: 7, default: '#6366F1' })
  themeColor: string;

  // Legacy schema snapshots remain readable for existing demo apps.
  @Column({ type: 'jsonb', nullable: true })
  draftSchema?: Record<string, any> | null;

  @OneToMany(() => MiniAppVersionEntity, (v) => v.miniApp, { cascade: true })
  versions: MiniAppVersionEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
