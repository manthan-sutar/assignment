import '../../domain/entities/reel_entity.dart';
import '../../domain/repositories/reels_repository.dart';
import '../datasources/reels_remote_datasource.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';

/// Implementation of [ReelsRepository]. Uses local auth for token, remote for API.
class ReelsRepositoryImpl implements ReelsRepository {
  ReelsRepositoryImpl({
    required ReelsRemoteDataSource remoteDataSource,
    required AuthLocalDataSource authLocalDataSource,
  })  : _remote = remoteDataSource,
        _authLocal = authLocalDataSource;

  final ReelsRemoteDataSource _remote;
  final AuthLocalDataSource _authLocal;

  @override
  Future<List<ReelEntity>> getReels() async {
    final token = await _authLocal.getToken();
    final models = await _remote.fetchReels(token);
    return models;
  }
}
