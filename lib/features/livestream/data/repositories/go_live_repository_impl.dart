import 'dart:async';
import '../../domain/entities/live_category.dart';
import '../../domain/repositories/go_live_repository.dart';

class GoLiveRepositoryImpl implements GoLiveRepository {
  @override
  Future<List<LiveCategory>> fetchCategories() async {
    // TODO: swap with API call
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      LiveCategory(id: '1', name: 'Gaming'),
      LiveCategory(id: '2', name: 'Music'),
      LiveCategory(id: '3', name: 'Lifestyle'),
      LiveCategory(id: '4', name: 'Sports'),
      LiveCategory(id: '5', name: 'Talk Show'),
    ];
  }

  @override
  Future<({bool ready, String bestTime, (int, int) estimatedViewers})>
  getPreview({
    required String? title,
    required LiveCategory? category,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
  }) async {
    // TODO: replace with API scoring/forecast
    await Future.delayed(const Duration(milliseconds: 250));
    final base =
        (title?.isNotEmpty == true ? 15 : 8) + (category != null ? 5 : 0);
    final low = base;
    final high = (base * 1.6).round();
    return (ready: true, bestTime: "Now", estimatedViewers: (low, high));
  }

  @override
  Future<bool> isFirstStreamBonusEligible() async {
    // TODO: query profile status
    await Future.delayed(const Duration(milliseconds: 200));
    return true; // eligible by default for MVP UI
  }

  @override
  Future<void> startStreaming({
    required String title,
    required String categoryId,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
    required String? coverPath,
    required bool micOn,
    required bool camOn,
  }) async {
    // TODO: call your Laravel endpoint to create/prepare the livestream
    await Future.delayed(const Duration(milliseconds: 500));
    return;
  }
}
