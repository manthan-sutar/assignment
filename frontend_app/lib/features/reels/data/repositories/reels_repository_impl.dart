import '../../domain/entities/reels_page_result.dart';
import '../../domain/repositories/reels_repository.dart';
import '../datasources/reels_remote_datasource.dart';

/// Implementation of [ReelsRepository]. Uses reels feed API with cursor + limit.
class ReelsRepositoryImpl implements ReelsRepository {
  ReelsRepositoryImpl({
    required ReelsRemoteDataSource remoteDataSource,
  }) : _remote = remoteDataSource;

  final ReelsRemoteDataSource _remote;

  @override
  Future<ReelsPageResult> getReels({String? cursor, int? limit}) async {
    final result = await _remote.fetchReels(cursor: cursor, limit: limit);
    return ReelsPageResult(
      reels: result.reels,
      nextCursor: result.nextCursor,
    );
  }
}
