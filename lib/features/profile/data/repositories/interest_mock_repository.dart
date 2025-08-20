// lib/features/interests/data/repositories/interest_mock_repository.dart
import 'dart:async';
import '../models/interest_model.dart';
import 'interest_repository.dart';

class InterestMockRepository implements InterestRepository {
  final List<Interest> _mockInterests = [
    Interest(id: '1', name: 'Technology'),
    Interest(id: '2', name: 'Sports'),
    Interest(id: '3', name: 'Music'),
    Interest(id: '4', name: 'Business'),
  ];

  @override
  Future<List<Interest>> fetchInterests() async {
    await Future.delayed(Duration(milliseconds: 500)); // simulate network delay
    return _mockInterests;
  }

  @override
  Future<void> saveInterests(List<Interest> interests) async {
    await Future.delayed(Duration(milliseconds: 200));
    print(
      "Saved Interests: ${interests.where((i) => i.isSelected).map((e) => e.name).toList()}",
    );
  }
}
