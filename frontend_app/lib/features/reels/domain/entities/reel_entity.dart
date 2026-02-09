import 'package:equatable/equatable.dart';

/// Domain entity for an audio reel (audio + image background).
/// [audioUrl] is the default/effective URL (preferred when available).
/// [nativeSignedUrl] and [preferredSignedUrl] are optional; when both present,
/// UI can toggle between them.
class ReelEntity extends Equatable {
  final String id;
  final String title;
  final String audioUrl;
  final String imageUrl;
  final int durationSeconds;
  final int sortOrder;
  final DateTime createdAt;
  final String? nativeSignedUrl;
  final String? preferredSignedUrl;

  const ReelEntity({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.imageUrl,
    required this.durationSeconds,
    required this.sortOrder,
    required this.createdAt,
    this.nativeSignedUrl,
    this.preferredSignedUrl,
  });

  @override
  List<Object?> get props =>
      [id, title, audioUrl, imageUrl, durationSeconds, sortOrder, createdAt, nativeSignedUrl, preferredSignedUrl];
}
