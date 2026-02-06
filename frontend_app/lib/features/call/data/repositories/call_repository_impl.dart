import '../../../../core/errors/call_exceptions.dart';
import '../../domain/entities/agora_client_role.dart';
import '../../domain/entities/call_token_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_datasource.dart';

/// Implementation of [CallRepository] using backend API.
class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl({
    required CallRemoteDataSource remoteDataSource,
    required Future<String?> Function() getIdToken,
  })  : _remote = remoteDataSource,
        _getIdToken = getIdToken;

  final CallRemoteDataSource _remote;
  final Future<String?> Function() _getIdToken;

  @override
  Future<CallTokenEntity> getToken({
    required String channelName,
    int? uid,
    AgoraClientRole role = AgoraClientRole.publisher,
  }) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw CallUnauthorizedException();
    }
    return _remote.fetchToken(
      idToken: idToken,
      channelName: channelName,
      uid: uid,
      role: role,
    );
  }

  @override
  Future<String> getAppId() async {
    final idToken = await _getIdToken();
    return _remote.fetchAppId(idToken);
  }
}
