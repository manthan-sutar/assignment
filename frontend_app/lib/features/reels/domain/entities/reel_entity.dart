import 'package:equatable/equatable.dart';

/// Domain entity for an audio reel (audio + image background).
class ReelEntity extends Equatable {
  final String id;
  final String title;
  final String audioUrl;
  final String imageUrl;
  final int durationSeconds;
  final int sortOrder;
  final DateTime createdAt;

  const ReelEntity({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.imageUrl,
    required this.durationSeconds,
    required this.sortOrder,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, audioUrl, imageUrl, durationSeconds, sortOrder, createdAt];
}
