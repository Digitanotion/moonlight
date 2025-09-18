import 'package:moonlight/features/livestream/domain/entities/live_category.dart';
import 'package:moonlight/features/livestream/domain/entities/live_start_payload.dart';

typedef PreviewResult = ({
  bool ready,
  String bestTime,
  (int, int) estimatedViewers,
});

abstract class GoLiveRepository {
  Future<List<LiveCategory>> fetchCategories();

  Future<PreviewResult> getPreview({
    required String? title,
    required LiveCategory? category,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
  });

  Future<bool> isFirstStreamBonusEligible();

  /// Returns everything the host screen needs to bootstrap Agora + sockets.
  Future<LiveStartPayload> startStreaming({
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
