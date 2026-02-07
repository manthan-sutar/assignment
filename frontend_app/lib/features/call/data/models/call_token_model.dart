import '../../domain/entities/call_token_entity.dart';

/// API response model for Agora RTC token.
class CallTokenModel extends CallTokenEntity {
  const CallTokenModel({
    required super.token,
    required super.channelName,
    required super.uid,
    required super.appId,
    required super.expiresIn,
  });

  factory CallTokenModel.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    final channelName = json['channelName'] as String?;
    final appId = json['appId'] as String?;
    if (token == null || token.trim().isEmpty) {
      throw FormatException('Token response missing or empty "token"', json);
    }
    if (channelName == null || channelName.trim().isEmpty) {
      throw FormatException(
        'Token response missing or empty "channelName"',
        json,
      );
    }
    if (appId == null || appId.trim().isEmpty) {
      throw FormatException('Token response missing or empty "appId"', json);
    }
    final uidRaw = json['uid'];
    final uid = uidRaw is num
        ? uidRaw.toInt()
        : int.tryParse(uidRaw?.toString() ?? '') ?? 0;
    if (uid <= 0) {
      throw FormatException('Token response invalid "uid"', json);
    }
    final expiresIn = (json['expiresIn'] as num?)?.toInt() ?? 3600;
    return CallTokenModel(
      token: token,
      channelName: channelName,
      uid: uid,
      appId: appId,
      expiresIn: expiresIn,
    );
  }
}
