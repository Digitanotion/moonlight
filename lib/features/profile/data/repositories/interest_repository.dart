// lib/features/interests/data/repositories/interest_repository.dart
import '../models/interest_model.dart';

abstract class InterestRepository {
  Future<List<Interest>> fetchInterests();
  Future<void> saveInterests(List<Interest> interests);
}
