import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class UserEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column({ type: 'varchar', length: 254, unique: true }) email: string;
  @Column({ type: 'varchar', length: 256, select: false }) passwordHash: string;
  @Column({ type: 'varchar', length: 128 }) displayName: string;
  @Column({ type: 'varchar', length: 512, default: '' }) avatarUrl: string;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
