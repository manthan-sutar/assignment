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
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      title: json['title'] as String,
      audioUrl: json['audioUrl'] as String,
      imageUrl: json['imageUrl'] as String,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
