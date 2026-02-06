import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
} from 'typeorm';

/**
 * Reel Entity
 * Audio reel with image background (Instagram-style, consumption-only).
 * Media stored in Firebase Storage; this table holds metadata and URLs.
 */
@Entity('reels')
export class Reel {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  /** Firebase Storage (or any) URL for the audio file */
  @Column({ name: 'audio_url', type: 'varchar', length: 2048 })
  audioUrl: string;

  /** Firebase Storage (or any) URL for the background image; null for admin-uploaded (app uses placeholder) */
  @Column({ name: 'image_url', type: 'varchar', length: 2048, nullable: true })
  imageUrl: string | null;

  /** Duration in seconds (for progress UI) */
  @Column({ name: 'duration_seconds', type: 'int', default: 0 })
  durationSeconds: number;

  /** Display order (lower = first) */
  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
