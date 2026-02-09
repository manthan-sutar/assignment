import '../entities/live_session_entity.dart';
import '../entities/start_live_entity.dart';

abstract class LiveRepository {
  /// Start a live stream. Returns Agora token and channel info for the host.
  Future<StartLiveEntity> startLive();

  /// Get a new host token for your current live session (re-enter host screen). Returns null if not live.
  Future<StartLiveEntity?> getHostToken();

  /// End the current user's live stream.
  Future<void> endLive();

  /// List all active live streams.
  Future<List<LiveSessionEntity>> getSessions();
}
