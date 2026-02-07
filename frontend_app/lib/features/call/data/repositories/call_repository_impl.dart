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
  }) : _remote = remoteDataSource,
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

  @override
  Future<Map<String, dynamic>> createOffer(String calleeUserId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();
    return _remote.createOffer(idToken: idToken, calleeUserId: calleeUserId);
  }

  @override
  Future<CallTokenEntity> acceptOffer(String callId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();
    return _remote.acceptOffer(idToken: idToken, callId: callId);
  }

  @override
  Future<void> declineOffer(String callId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();
    return _remote.declineOffer(idToken: idToken, callId: callId);
  }

  @override
  Future<void> cancelOffer(String callId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();
    return _remote.cancelOffer(idToken: idToken, callId: callId);
  }

  @override
  Future<Map<String, dynamic>?> getOffer(String callId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    return _remote.getOffer(idToken: idToken, callId: callId);
  }
}
