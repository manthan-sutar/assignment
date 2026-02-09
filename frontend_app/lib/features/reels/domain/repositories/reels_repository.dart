import '../entities/reel_entity.dart';
import '../entities/reels_page_result.dart';

/// Contract for fetching reels. Implemented by data layer.
abstract class ReelsRepository {
  /// Fetches a page of reels. [cursor] is UTC time for next page (omit for first page).
  /// [limit] is the number of audios per page. Returns reels and [nextCursor] for load more.
  Future<ReelsPageResult> getReels({String? cursor, int? limit});
}
