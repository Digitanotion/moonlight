import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';

abstract class SearchRepository {
  Future<Either<Failure, List<SearchResult>>> search(String query);
  Future<Either<Failure, List<TagResult>>> getTrendingTags();
  Future<Either<Failure, List<UserResult>>> getSuggestedUsers();
  Future<Either<Failure, List<ClubResult>>> getPopularClubs();
}
