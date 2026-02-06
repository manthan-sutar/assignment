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
    return CallTokenModel(
      token: json['token'] as String,
      channelName: json['channelName'] as String,
      uid: (json['uid'] as num).toInt(),
      appId: json['appId'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
    );
  }
}
