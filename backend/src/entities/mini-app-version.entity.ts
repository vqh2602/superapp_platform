import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { MiniAppStatus } from './enums';
import { MiniAppEntity } from './mini-app.entity';

@Entity('mini_app_versions')
@Index(['appId', 'version'], { unique: true })
export class MiniAppVersionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 64 })
  appId: string;

  @ManyToOne(() => MiniAppEntity, (app) => app.versions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'appId' })
  miniApp: MiniAppEntity;

  @Column({ type: 'varchar', length: 32 })
  version: string; // e.g. "1.0.0"

  @Column({ type: 'int', default: 1 })
  schemaVersion: number;

  @Column({
    type: 'varchar',
    length: 20,
    default: MiniAppStatus.SUBMITTED,
  })
  status: MiniAppStatus;

  @Column({ type: 'jsonb', nullable: true })
  schema?: Record<string, any> | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  entryUrl?: string | null;

  @Column({ type: 'simple-array', default: '' })
  capabilities: string[];

  @Column({ type: 'text', nullable: true })
  reviewNotes?: string | null;

  @Column({ type: 'jsonb', nullable: true })
  manifest?: Record<string, any> | null;

  @Column({ type: 'varchar', length: 36, nullable: true })
  packageKey?: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  checksum?: string | null;

  @Column({ type: 'int', nullable: true })
  packageSize?: number | null;

  @CreateDateColumn()
  createdAt: Date;

  @Column({ type: 'timestamp', nullable: true })
  submittedAt?: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  reviewedAt?: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  publishedAt?: Date | null;
}
