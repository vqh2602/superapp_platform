import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { AuthSessionEntity } from './auth-session.entity';
import { MiniAppEntity } from './mini-app.entity';
import { UserEntity } from './user.entity';

@Entity('miniapp_auth_codes')
export class MiniAppAuthCodeEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 64, unique: true, select: false }) codeHash: string;
  @Column({ type: 'uuid' }) userId: string;
  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'userId' }) user: UserEntity;
  @Column({ type: 'varchar', length: 64 }) appId: string;
  @ManyToOne(() => MiniAppEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'appId' }) miniApp: MiniAppEntity;
  @Column({ type: 'uuid' }) sessionId: string;
  @ManyToOne(() => AuthSessionEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'sessionId' }) session: AuthSessionEntity;
  @Column({ type: 'varchar', length: 43 }) codeChallenge: string;
  @Column({ type: 'simple-array', default: '' }) scopes: string[];
  @Column({ type: 'timestamptz' }) expiresAt: Date;
  @Column({ type: 'timestamptz', nullable: true }) consumedAt: Date | null;
  @CreateDateColumn() createdAt: Date;
}
