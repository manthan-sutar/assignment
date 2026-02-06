/// Agora RTC credentials to join a channel (calling or live streaming).
class CallTokenEntity {
  const CallTokenEntity({
    required this.token,
    required this.channelName,
    required this.uid,
    required this.appId,
    required this.expiresIn,
  });

  final String token;
  final String channelName;
  final int uid;
  final String appId;
  final int expiresIn;
}
