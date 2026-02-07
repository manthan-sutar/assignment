/// A currently active live stream (host info + channel).
class LiveSessionEntity {
  const LiveSessionEntity({
    required this.sessionId,
    required this.channelName,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.startedAt,
  });

  final String sessionId;
  final String channelName;
  final String hostUserId;
  final String hostDisplayName;
  final String startedAt;
}
