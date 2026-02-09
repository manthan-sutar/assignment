import 'reel_model.dart';

/// Result of a single feed page request: reels and cursor for next page.
class ReelsFeedPageResult {
  const ReelsFeedPageResult({
    required this.reels,
    this.nextCursor,
  });

  final List<ReelModel> reels;
  final String? nextCursor;
}

/// Response shape of the reels feed API (separate server).
/// Contains followerJamme, followerJams, randomJamme, randomJams, nextCursor.
class ReelsFeedResponse {
  const ReelsFeedResponse({
    this.followerJamme = const [],
    this.followerJams = const [],
    this.randomJamme = const [],
    this.randomJams = const [],
    this.nextCursor,
  });

  final List<FeedItemModel> followerJamme;
  final List<FeedItemModel> followerJams;
  final List<FeedItemModel> randomJamme;
  final List<FeedItemModel> randomJams;
  final String? nextCursor;

  factory ReelsFeedResponse.fromJson(Map<String, dynamic> json) {
    return ReelsFeedResponse(
      followerJamme: _parseList(json['followerJamme']),
      followerJams: _parseList(json['followerJams']),
      randomJamme: _parseList(json['randomJamme']),
      randomJams: _parseList(json['randomJams']),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  static List<FeedItemModel> _parseList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((e) => FeedItemModel.fromJson(e))
        .toList();
  }

  /// Merges feed items into a single list for the feed: follower jamme/jams first, then random.
  /// Converts each item to [ReelModel] using [nativeSignedUrl] as the audio link.
  List<ReelModel> toReelModels() {
    final items = [
      ...followerJamme,
      ...followerJams,
      ...randomJamme,
      ...randomJams,
    ];
    return items.asMap().entries.map((e) => e.value.toReelModel(e.key)).toList();
  }
}

/// Single item in the feed (jamme or jam). Both share jamId, nativeSignedUrl, image_gcp_path, title_text_gcp_path, uploadedUser.
class FeedItemModel {
  const FeedItemModel({
    required this.jamId,
    required this.nativeSignedUrl,
    this.preferredSignedUrl,
    this.imageGcpPath,
    this.titleTextGcpPath,
    this.uploadedUser,
    this.repliedUser,
    this.stitchedAt,
    this.uploadedAt,
  });

  final String jamId;
  final String nativeSignedUrl;
  final String? preferredSignedUrl;
  final String? imageGcpPath;
  final String? titleTextGcpPath;
  final FeedUser? uploadedUser;
  final FeedUser? repliedUser;
  final String? stitchedAt;
  final String? uploadedAt;

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    final uploaded = json['uploadedUser'];
    final replied = json['repliedUser'];
    return FeedItemModel(
      jamId: json['jamId'] as String? ?? '',
      nativeSignedUrl: json['nativeSignedUrl'] as String? ?? '',
      preferredSignedUrl: json['preferredSignedUrl'] as String?,
      imageGcpPath: json['image_gcp_path'] as String?,
      titleTextGcpPath: json['title_text_gcp_path'] as String?,
      uploadedUser: uploaded is Map<String, dynamic>
          ? FeedUser.fromJson(uploaded)
          : null,
      repliedUser: replied is Map<String, dynamic>
          ? FeedUser.fromJson(replied)
          : null,
      stitchedAt: json['stitchedAt'] as String?,
      uploadedAt: json['uploadedAt'] as String?,
    );
  }

  ReelModel toReelModel(int sortOrder) {
    final createdAt = stitchedAt ?? uploadedAt;
    final defaultAudioUrl = preferredSignedUrl ?? nativeSignedUrl;
    return ReelModel(
      id: jamId,
      title: titleTextGcpPath?.isNotEmpty == true
          ? titleTextGcpPath!
          : 'Reel',
      audioUrl: defaultAudioUrl,
      imageUrl: ReelModel.imageUrlPlaceholder,
      durationSeconds: 0,
      sortOrder: sortOrder,
      createdAt: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
      nativeSignedUrl: nativeSignedUrl,
      preferredSignedUrl: preferredSignedUrl,
    );
  }
}

class FeedUser {
  const FeedUser({
    required this.id,
    this.profilePicture,
    this.username,
  });

  final String id;
  final String? profilePicture;
  final String? username;

  factory FeedUser.fromJson(Map<String, dynamic> json) {
    return FeedUser(
      id: json['id'] as String? ?? '',
      profilePicture: json['profilePicture'] as String?,
      username: json['username'] as String?,
    );
  }
}
