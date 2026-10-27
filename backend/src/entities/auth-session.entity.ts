import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { UserEntity } from './user.entity';

export type TokenAudience = 'superapp' | 'miniapp';

@Entity('auth_sessions')
@Index(['userId'])
export class AuthSessionEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'uuid' }) userId: string;
  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' }) @JoinColumn({ name: 'userId' }) user: UserEntity;
  @Column({ type: 'varchar', length: 16 }) audience: TokenAudience;
  @Column({ type: 'varchar', length: 64, nullable: true }) appId: string | null;
  @Column({ type: 'uuid', nullable: true }) parentSessionId: string | null;
  @ManyToOne(() => AuthSessionEntity, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'parentSessionId' }) parentSession?: AuthSessionEntity;
  @Column({ type: 'simple-array', default: '' }) scopes: string[];
  @Column({ type: 'varchar', length: 64, unique: true, select: false }) accessTokenHash: string;
  @Column({ type: 'varchar', length: 64, unique: true, select: false }) refreshTokenHash: string;
  @Column({ type: 'timestamptz' }) expiresAt: Date;
  @Column({ type: 'timestamptz' }) refreshExpiresAt: Date;
  @Column({ type: 'timestamptz', nullable: true }) revokedAt: Date | null;
  @CreateDateColumn() createdAt: Date;
}
