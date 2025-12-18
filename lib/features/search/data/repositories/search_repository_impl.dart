import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
import 'package:moonlight/features/search/data/models/search_models.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<SearchResult>>> search(String query) async {
    try {
      final rawResults = await remoteDataSource.search(query);

      final List<SearchResult> results = [];

      for (final item in rawResults) {
        if (item is UserModel) {
          results.add(
            UserResult(
              id: item.id,
              name: item.name,
              username: item.username,
              avatarUrl: item.avatarUrl,
              followersCount: item.followersCount,
              isFollowing: item.isFollowing,
            ),
          );
        } else if (item is ClubModel) {
          results.add(
            ClubResult(
              id: item.id,
              name: item.name,
              description: item.description,
              membersCount: item.membersCount,
              coverImageUrl: item.coverImageUrl,
              isMember: item.isMember,
            ),
          );
        } else if (item is TagModel) {
          results.add(
            TagResult(
              id: item.id,
              name: item.name,
              usageCount: item.usageCount,
            ),
          );
        }
      }

      return Right(results);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (_) {
      return Left(ServerFailure('Unexpected search error'));
    }
  }

  @override
  Future<Either<Failure, List<TagResult>>> getTrendingTags() async {
    try {
      final tags = await remoteDataSource.getTrendingTags();
      return Right(
        tags
            .map(
              (t) =>
                  TagResult(id: t.id, name: t.name, usageCount: t.usageCount),
            )
            .toList(),
      );
    } on ServerException {
      return Left(ServerFailure("Failed to get trending tags"));
    }
  }

  @override
  Future<Either<Failure, List<UserResult>>> getSuggestedUsers() async {
    try {
      final users = await remoteDataSource.getSuggestedUsers();
      return Right(
        users
            .map(
              (u) => UserResult(
                id: u.id,
                name: u.name,
                username: u.username,
                avatarUrl: u.avatarUrl,
                followersCount: u.followersCount,
                isFollowing: u.isFollowing,
              ),
            )
            .toList(),
      );
    } on ServerException {
      return Left(ServerFailure("Failed to get suggested users"));
    }
  }

  @override
  Future<Either<Failure, List<ClubResult>>> getPopularClubs() async {
    try {
      final clubs = await remoteDataSource.getPopularClubs();
      return Right(
        clubs
            .map(
              (c) => ClubResult(
                id: c.id,
                name: c.name,
                description: c.description,
                membersCount: c.membersCount,
                coverImageUrl: c.coverImageUrl,
                isMember: c.isMember,
              ),
            )
            .toList(),
      );
    } on ServerException {
      return Left(ServerFailure("Failed to get popular clubs"));
    }
  }
}
