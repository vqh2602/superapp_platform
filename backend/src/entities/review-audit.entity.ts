import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';
import { ReviewAction } from './enums';

@Entity('review_audits')
export class ReviewAuditEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 64 })
  appId: string;

  @Column({ type: 'varchar', length: 32 })
  version: string;

  @Column({
    type: 'varchar',
    length: 24,
  })
  action: ReviewAction;

  @Column({ type: 'varchar', length: 64 })
  actorId: string;

  @Column({ type: 'varchar', length: 32, default: 'admin' })
  actorRole: string;

  @Column({ type: 'text', default: '' })
  reason: string;

  @CreateDateColumn()
  timestamp: Date;
}
