import 'reel_entity.dart';

/// Result of a paginated reels feed request.
class ReelsPageResult {
  const ReelsPageResult({
    required this.reels,
    this.nextCursor,
  });

  final List<ReelEntity> reels;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
