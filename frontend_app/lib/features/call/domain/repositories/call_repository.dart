import '../entities/call_token_entity.dart';
import '../entities/agora_client_role.dart';

/// Repository for call-related data (Agora tokens, config, offer/accept/decline).
abstract class CallRepository {
  /// Fetches an RTC token for the given channel.
  /// [channelName] must match for caller and callee.
  /// [role] defaults to publisher (can publish audio); use subscriber for audience.
  Future<CallTokenEntity> getToken({
    required String channelName,
    int? uid,
    AgoraClientRole role = AgoraClientRole.publisher,
  });

  /// Fetches Agora App ID (e.g. for engine creation before joining).
  Future<String> getAppId();

  /// Create a call offer to [calleeUserId]. Returns map with callId, channelName, status.
  Future<Map<String, dynamic>> createOffer(String calleeUserId);

  /// Callee accepts the call. Returns token entity for joining channel.
  Future<CallTokenEntity> acceptOffer(String callId);

  /// Callee declines the call.
  Future<void> declineOffer(String callId);

  /// Caller cancels the call.
  Future<void> cancelOffer(String callId);

  /// Get call offer by id (for validating when app opened from notification). Returns null if not found/expired.
  Future<Map<String, dynamic>?> getOffer(String callId);
}
