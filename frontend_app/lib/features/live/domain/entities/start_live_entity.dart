/// Response from start live: Agora credentials for the host (publisher).
class StartLiveEntity {
  const StartLiveEntity({
    required this.sessionId,
    required this.channelName,
    required this.token,
    required this.appId,
    required this.uid,
    required this.expiresIn,
  });

  final String sessionId;
  final String channelName;
  final String token;
  final String appId;
  final int uid;
  final int expiresIn;
}
