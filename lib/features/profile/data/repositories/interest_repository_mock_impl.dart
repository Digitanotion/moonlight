import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../../domain/entities/interest.dart';
import '../../domain/repositories/interest_repository.dart';
import '../datasources/interests_local_data_source.dart';

class InterestRepositoryMockImpl implements InterestRepository {
  final InterestsLocalDataSource local;
  InterestRepositoryMockImpl({required this.local});

  static const List<Interest> _mock = [
    Interest(id: '1', title: 'Music', emoji: '🎵'),
    Interest(id: '2', title: 'Gaming', emoji: '🎮'),
    Interest(id: '3', title: 'Sports', emoji: '⚽'),
    Interest(id: '4', title: 'Technology', emoji: '🧠'),
    Interest(id: '5', title: 'Business', emoji: '💼'),
    Interest(id: '6', title: 'Lifestyle', emoji: '🌿'),
    Interest(id: '7', title: 'Comedy', emoji: '😂'),
    Interest(id: '8', title: 'Art & Design', emoji: '🎨'),
    Interest(id: '9', title: 'Movies', emoji: '🎬'),
  ];

  @override
  Future<Either<Failure, List<Interest>>> getInterests() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return Right(_mock);
  }

  @override
  Future<Either<Failure, Unit>> saveUserInterests(
    List<String> selectedIds,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await local.setCompleted(true);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, bool>> hasCompletedSelection() async {
    final completed = await local.getCompleted();
    return Right(completed);
  }
}
