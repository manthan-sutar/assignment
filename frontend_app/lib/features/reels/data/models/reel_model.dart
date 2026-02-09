import '../../domain/entities/reel_entity.dart';

/// Data model for reel (API JSON mapping).
class ReelModel extends ReelEntity {
  const ReelModel({
    required super.id,
    required super.title,
    required super.audioUrl,
    required super.imageUrl,
    required super.durationSeconds,
    required super.sortOrder,
    required super.createdAt,
    super.nativeSignedUrl,
    super.preferredSignedUrl,
  });

  /// Placeholder when API returns null for imageUrl (e.g. admin-uploaded reels).
  static const String imageUrlPlaceholder =
      'https://picsum.photos/seed/reel/800/1200';

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['imageUrl'];
    final audioUrl = json['audioUrl'] as String? ?? '';
    final preferred = json['preferredSignedUrl'] as String?;
    final native = json['nativeSignedUrl'] as String?;
    return ReelModel(
      id: json['id'] as String,
      title: json['title'] as String,
      audioUrl: preferred ?? native ?? audioUrl,
      imageUrl: imageUrl is String && imageUrl.isNotEmpty
          ? imageUrl
          : imageUrlPlaceholder,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      nativeSignedUrl: native,
      preferredSignedUrl: preferred,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'durationSeconds': durationSeconds,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
  };
}
