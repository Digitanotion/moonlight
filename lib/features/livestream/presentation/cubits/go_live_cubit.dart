import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/features/livestream/domain/entities/live_category.dart';
import 'package:moonlight/features/livestream/domain/repositories/go_live_repository.dart';
import 'package:moonlight/features/livestream/domain/services/audio_test_service.dart';
import 'package:moonlight/features/livestream/domain/services/camera_service.dart';
import 'go_live_state.dart';

class GoLiveCubit extends Cubit<GoLiveState> {
  final GoLiveRepository repo;
  final CameraService camera;
  final AudioTestService audio;
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<double>? _levelSub;

  GoLiveCubit(this.repo, this.camera, this.audio) : super(const GoLiveState());

  Future<void> init() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final cats = await repo.fetchCategories();
      final eligible = await repo.isFirstStreamBonusEligible();

      // Initialize devices according to default toggles
      final micReady = state.micOn ? await _ensureMicStarted() : false;
      final camReady = state.camOn ? await _ensureCamStarted() : false;

      emit(
        state.copyWith(
          categories: cats,
          eligibleBonus: eligible,
          loading: false,
          micReady: micReady,
          camReady: camReady,
        ),
      );

      await _refreshPreview();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> pickCover() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) emit(state.copyWith(coverPath: file.path));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void setTitle(String v) {
    emit(state.copyWith(title: v));
    _refreshPreview();
  }

  void setCategory(LiveCategory? c) {
    emit(state.copyWith(category: c));
    _refreshPreview();
  }

  void togglePremium(bool v) {
    emit(state.copyWith(premium: v));
    _refreshPreview();
  }

  void toggleGuestBox(bool v) {
    emit(state.copyWith(allowGuestBox: v));
    _refreshPreview();
  }

  void toggleComments(bool v) {
    emit(state.copyWith(comments: v));
    _refreshPreview();
  }

  void toggleShowCount(bool v) {
    emit(state.copyWith(showCount: v));
    _refreshPreview();
  }

  Future<bool> _ensureCamStarted() async {
    final ok = await camera.initialize();
    if (!ok) return false;
    await camera.start();
    return camera.isInitialized;
  }

  Future<bool> _ensureMicStarted() async {
    final ok = await audio.initialize();
    if (!ok) return false;
    await audio.start();
    await _levelSub?.cancel();
    _levelSub = audio.levelStream.listen((lvl) {
      emit(state.copyWith(micLevel: lvl));
    });
    return true;
  }

  Future<void> toggleCam() async {
    final to = !state.camOn;
    if (to) {
      final ready = await _ensureCamStarted();
      emit(state.copyWith(camOn: true, camReady: ready));
    } else {
      await camera.stop();
      emit(state.copyWith(camOn: false, camReady: false));
    }
  }

  Future<void> toggleMic() async {
    final to = !state.micOn;
    if (to) {
      final ready = await _ensureMicStarted();
      emit(state.copyWith(micOn: true, micReady: ready));
    } else {
      await _levelSub?.cancel();
      _levelSub = null;
      await audio.stop();
      emit(state.copyWith(micOn: false, micReady: false, micLevel: 0.0));
    }
  }

  Future<void> _refreshPreview() async {
    final p = await repo.getPreview(
      title: state.title,
      category: state.category,
      premium: state.premium,
      allowGuestBox: state.allowGuestBox,
      comments: state.comments,
      showCount: state.showCount,
    );
    emit(
      state.copyWith(
        previewReady: p.ready,
        bestTime: p.bestTime,
        estLow: p.estimatedViewers.$1,
        estHigh: p.estimatedViewers.$2,
      ),
    );
  }

  Future<void> start() async {
    if (!state.canStart || !state.devicesOk) return;

    // Double-check devices if toggled on but not ready
    if (state.camOn && !state.camReady) {
      final ok = await _ensureCamStarted();
      emit(state.copyWith(camReady: ok));
      if (!ok) return;
    }
    if (state.micOn && !state.micReady) {
      final ok = await _ensureMicStarted();
      emit(state.copyWith(micReady: ok));
      if (!ok) return;
    }

    emit(state.copyWith(starting: true));
    try {
      await audio.stopAndClean();
      await repo.startStreaming(
        title: state.title.trim(),
        categoryId: state.category!.id,
        premium: state.premium,
        allowGuestBox: state.allowGuestBox,
        comments: state.comments,
        showCount: state.showCount,
        coverPath: state.coverPath,
        micOn: state.micOn,
        camOn: state.camOn,
      );
      emit(state.copyWith(starting: false));
    } catch (e) {
      emit(state.copyWith(starting: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _levelSub?.cancel();
    await camera.dispose();
    await audio.dispose();
    return super.close();
  }
}
