import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<SearchResult>>> search(String query) async {
    try {
      final results = await remoteDataSource.search(query);
      // Convert models to entities
      return Right([]);
    } on ServerException {
      return Left(ServerFailure("Server failed during searching"));
    }
  }

  @override
  Future<Either<Failure, List<TagResult>>> getTrendingTags() async {
    try {
      final tags = await remoteDataSource.getTrendingTags();
      return Right(
        tags
            .map(
              (tag) => TagResult(
                id: tag.id,
                name: tag.name,
                usageCount: tag.usageCount,
              ),
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
              (user) => UserResult(
                id: user.id,
                name: user.name,
                username: user.username,
                avatarUrl: user.avatarUrl,
                followersCount: user.followersCount,
                isFollowing: user.isFollowing,
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
              (club) => ClubResult(
                id: club.id,
                name: club.name,
                description: club.description,
                membersCount: club.membersCount,
                coverImageUrl: club.coverImageUrl,
                isMember: club.isMember,
              ),
            )
            .toList(),
      );
    } on ServerException {
      return Left(ServerFailure("Failed to get popular clubs"));
    }
  }
}
