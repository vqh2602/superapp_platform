import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { UserEntity } from './user.entity';
import { MiniAppEntity } from './mini-app.entity';

@Entity('user_miniapp_permissions')
@Index(['userId', 'appId', 'capability'], { unique: true })
export class UserMiniAppPermissionEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'uuid' }) userId: string;
  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'userId' }) user: UserEntity;
  @Column({ type: 'varchar', length: 64 }) appId: string;
  @ManyToOne(() => MiniAppEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'appId' }) miniApp: MiniAppEntity;
  @Column({ type: 'varchar', length: 128 }) capability: string;
  @Column({ type: 'boolean' }) granted: boolean;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
