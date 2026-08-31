// lib/features/video_call/presentation/utils/video_call_guard.dart
//
// Client-side mirror of the server rule in VideoCallService::initiate():
// only male users may START a video call. Checking here as well lets us
// show a friendly explanation BEFORE navigating to the calling screen,
// instead of letting the user watch a "Calling…" screen that silently
// fails with a raw 422 a second later.
//
// The server remains the source of truth — this is purely UX. If the
// caller's gender is not known locally (profile not yet hydrated) we let
// the request through and rely on the backend's own rejection.

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// Whether the signed-in user is allowed to initiate a video call.
/// Returns `true` when the gender is unknown so we never wrongly block a
/// legitimate caller on a hydration race — the backend still enforces it.
bool currentUserCanStartCall() {
  final gender =
      sl<CurrentUserService>().currentUser?.gender?.toLowerCase().trim();
  if (gender == null || gender.isEmpty) return true;
  return gender == 'male';
}

/// Friendly, non-technical explanation shown when a female user taps a
/// call button. Matches issue 8's requested copy.
Future<void> showLadiesCannotCallDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary2),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Calls not available',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: const Text(
        'Sorry, ladies are not allowed to start a call. You can still '
        'receive calls and reply to messages.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(
            'Got it',
            style: TextStyle(
              color: AppColors.primary2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
