import '../entities/call_token_entity.dart';
import '../entities/agora_client_role.dart';

/// Repository for call-related data (Agora tokens, config).
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
}
