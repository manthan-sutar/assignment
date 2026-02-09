import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/start_live_entity.dart';
import '../../domain/repositories/live_repository.dart';
import '../datasources/live_remote_datasource.dart';

class LiveRepositoryImpl implements LiveRepository {
  LiveRepositoryImpl({
    required Future<String?> Function() getIdToken,
    LiveRemoteDataSource? remote,
  })  : _getIdToken = getIdToken,
        _remote = remote ?? LiveRemoteDataSource();

  final Future<String?> Function() _getIdToken;
  final LiveRemoteDataSource _remote;

  @override
  Future<StartLiveEntity> startLive() async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw Exception('Unauthorized');
    return _remote.startLive(idToken);
  }

  @override
  Future<StartLiveEntity?> getHostToken() async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    return _remote.getHostToken(idToken);
  }

  @override
  Future<void> endLive() async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw Exception('Unauthorized');
    return _remote.endLive(idToken);
  }

  @override
  Future<List<LiveSessionEntity>> getSessions() async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw Exception('Unauthorized');
    return _remote.getSessions(idToken);
  }
}
