/**
 * Reel Response DTO
 * Shape of a single reel in API responses
 */
export class ReelResponseDto {
  id: string;
  title: string;
  audioUrl: string;
  imageUrl: string;
  durationSeconds: number;
  sortOrder: number;
  createdAt: string; // ISO date string
}
