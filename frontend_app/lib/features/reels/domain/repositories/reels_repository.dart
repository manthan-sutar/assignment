import '../entities/reel_entity.dart';

/// Contract for fetching reels. Implemented by data layer.
abstract class ReelsRepository {
  /// Returns reels ordered for feed display. Throws [ReelsException] on failure.
  Future<List<ReelEntity>> getReels();
}
