// lib/features/live_viewer/presentation/services/role_change_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

enum RoleChangeState { idle, promoting, promoted, demoting, demoted, failed }

class RoleChangeResult {
  final RoleChangeState state;
  final String? newRole;
  final String? error;
  final DateTime timestamp;

  const RoleChangeResult({
    required this.state,
    this.newRole,
    this.error,
    required this.timestamp,
  });
}

/// Handles safe role transitions with state machine to prevent race conditions
class RoleChangeService with ChangeNotifier {
  final LiveStreamService _liveStreamService;

  RoleChangeState _currentState = RoleChangeState.idle;
  String? _currentRole = 'audience';
  String? _targetRole;
  StreamController<RoleChangeResult> _resultCtrl = StreamController.broadcast();

  // Guest controls state
  final ValueNotifier<bool> _guestMicEnabled = ValueNotifier(true);
  final ValueNotifier<bool> _guestCamEnabled = ValueNotifier(true);
  final ValueNotifier<bool> _guestAudioMuted = ValueNotifier(
    true,
  ); // Default muted
  final ValueNotifier<bool> _guestVideoMuted = ValueNotifier(
    true,
  ); // Default muted

  RoleChangeService(this._liveStreamService);

  // ============ PUBLIC API ============

  Stream<RoleChangeResult> watchRoleChanges() => _resultCtrl.stream;

  RoleChangeState get currentState => _currentState;
  String? get currentRole => _currentRole;

  ValueListenable<bool> get guestMicEnabled => _guestMicEnabled;
  ValueListenable<bool> get guestCamEnabled => _guestCamEnabled;
  ValueListenable<bool> get guestAudioMuted => _guestAudioMuted;
  ValueListenable<bool> get guestVideoMuted => _guestVideoMuted;

  Future<void> promoteToGuest() async {
    await _safeRoleChange('guest');
  }

  Future<void> promoteToCoHost() async {
    await _safeRoleChange('cohost');
  }

  Future<void> demoteToViewer() async {
    await _safeRoleChange('audience');
  }

  Future<void> safeRoleChange(String newRole) async {
    await _safeRoleChange(newRole);
  }

  Future<void> toggleGuestMic() async {
    if (_currentRole != 'guest' && _currentRole != 'cohost') {
      debugPrint('⚠️ Cannot toggle mic - not in guest mode');
      return;
    }

    final newState = !_guestAudioMuted.value;
    _guestAudioMuted.value = newState;

    try {
      await _liveStreamService.setMicEnabled(!newState);
      debugPrint('🎤 Guest mic ${newState ? 'muted' : 'unmuted'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle mic: $e');
      _guestAudioMuted.value = !newState; // Revert
    }
  }

  Future<void> toggleGuestCamera() async {
    if (_currentRole != 'guest' && _currentRole != 'cohost') {
      debugPrint('⚠️ Cannot toggle camera - not in guest mode');
      return;
    }

    final newState = !_guestVideoMuted.value;
    _guestVideoMuted.value = newState;

    try {
      await _liveStreamService.setCamEnabled(!newState);
      debugPrint('📷 Guest camera ${newState ? 'muted' : 'unmuted'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle camera: $e');
      _guestVideoMuted.value = !newState; // Revert
    }
  }

  GuestControlsState getGuestControlsState() {
    return GuestControlsState(
      isMicEnabled: _guestMicEnabled.value,
      isCamEnabled: _guestCamEnabled.value,
      isAudioMuted: _guestAudioMuted.value,
      isVideoMuted: _guestVideoMuted.value,
    );
  }

  // ============ PRIVATE METHODS ============

  Future<void> _safeRoleChange(String newRole) async {
    // Prevent concurrent role changes
    if (_currentState != RoleChangeState.idle) {
      debugPrint('⚠️ Role change already in progress ($_currentState)');
      _emitResult(
        RoleChangeResult(
          state: RoleChangeState.failed,
          error: 'Role change already in progress',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // Validate role transition
    if (!_isValidTransition(_currentRole, newRole)) {
      debugPrint('⚠️ Invalid role transition: $_currentRole → $newRole');
      _emitResult(
        RoleChangeResult(
          state: RoleChangeState.failed,
          error: 'Invalid role transition',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    _targetRole = newRole;
    _currentState = newRole == 'audience'
        ? RoleChangeState.demoting
        : RoleChangeState.promoting;

    debugPrint('🔄 Starting role change: $_currentRole → $newRole');

    try {
      // Add small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Perform the actual role change
      await _performRoleChange(newRole);

      // Update state
      _currentRole = newRole;
      _currentState = newRole == 'audience'
          ? RoleChangeState.demoted
          : RoleChangeState.promoted;

      // Reset guest controls based on new role
      if (newRole == 'guest' || newRole == 'cohost') {
        _initializeGuestControls();
      } else {
        _resetGuestControls();
      }

      debugPrint('✅ Role change successful: $_currentRole');

      _emitResult(
        RoleChangeResult(
          state: _currentState,
          newRole: newRole,
          timestamp: DateTime.now(),
        ),
      );

      // Reset to idle after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentState != RoleChangeState.failed) {
          _currentState = RoleChangeState.idle;
          _targetRole = null;
          notifyListeners();
        }
      });
    } catch (e, stack) {
      debugPrint('❌ Role change failed: $e');
      debugPrint('Stack: $stack');

      _currentState = RoleChangeState.failed;
      _targetRole = null;

      _emitResult(
        RoleChangeResult(
          state: RoleChangeState.failed,
          error: e.toString(),
          timestamp: DateTime.now(),
        ),
      );

      // Reset to idle after error
      Future.delayed(const Duration(seconds: 2), () {
        _currentState = RoleChangeState.idle;
        notifyListeners();
      });

      rethrow;
    }
  }

  Future<void> _performRoleChange(String newRole) async {
    // This would integrate with your actual role change logic
    // For now, we'll simulate the delay and rely on external triggers

    debugPrint('🎯 Performing role change to: $newRole');

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // The actual role change should be triggered by external events
    // (Pusher events, repository calls, etc.)
    // This service just manages the state machine

    debugPrint('🎯 Role change action completed for: $newRole');
  }

  bool _isValidTransition(String? fromRole, String toRole) {
    // Define valid transitions
    const validTransitions = {
      'audience': ['guest', 'cohost'],
      'guest': ['audience', 'cohost'],
      'cohost': ['audience', 'guest'],
    };

    final from = fromRole ?? 'audience';
    return validTransitions[from]?.contains(toRole) ?? false;
  }

  void _initializeGuestControls() {
    // Default guest controls: enabled but muted for privacy
    _guestMicEnabled.value = true;
    _guestCamEnabled.value = true;
    _guestAudioMuted.value = true;
    _guestVideoMuted.value = true;

    debugPrint('🎤 Initialized guest controls (muted for privacy)');
    notifyListeners();
  }

  void _resetGuestControls() {
    // Reset controls when not in guest mode
    _guestMicEnabled.value = false;
    _guestCamEnabled.value = false;
    _guestAudioMuted.value = true;
    _guestVideoMuted.value = true;

    debugPrint('🎤 Reset guest controls (not in guest mode)');
    notifyListeners();
  }

  void _emitResult(RoleChangeResult result) {
    _resultCtrl.add(result);
    notifyListeners();
  }

  // ============ CLEANUP ============

  @override
  void dispose() {
    _resultCtrl.close();
    super.dispose();
    debugPrint('🔄 RoleChangeService disposed');
  }
}
