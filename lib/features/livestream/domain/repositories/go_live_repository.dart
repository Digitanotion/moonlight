import '../../domain/entities/live_category.dart';

abstract class GoLiveRepository {
  Future<List<LiveCategory>> fetchCategories();
  Future<({bool ready, String bestTime, (int, int) estimatedViewers})>
  getPreview({
    required String? title,
    required LiveCategory? category,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
  });
  Future<bool> isFirstStreamBonusEligible();
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
  });
}
