import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';

class SearchContent {
  final SearchRepository repository;

  SearchContent(this.repository);

  Future<Either<Failure, List<SearchResult>>> call(String query) async {
    return await repository.search(query);
  }
}
