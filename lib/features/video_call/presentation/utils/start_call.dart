// lib/features/video_call/presentation/utils/start_call.dart
//
// One place to start a call from anywhere (chat header, profile, …).
//  • Audio: free, anyone can call anyone they can chat with.
//  • Video: paid per minute — men call women who take calls (server rule),
//    so we explain early and let the caller pick a coin budget.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/outgoing_call_screen.dart';
import 'package:moonlight/features/video_call/presentation/utils/video_call_guard.dart';
import 'package:moonlight/features/video_call/presentation/widgets/duration_picker_sheet.dart';
import 'package:moonlight/widgets/top_snack.dart';

void _openCallScreen(
  BuildContext context, {
  required String calleeSlug,
  required String calleeName,
  String? calleeAvatar,
  required String initiatedFrom,
  required String kind,
  int minutes = 1,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: sl<VideoCallBloc>(),
        child: OutgoingCallScreen(
          calleeUserSlug: calleeSlug,
          calleeDisplayName: calleeName,
          calleeAvatarUrl: calleeAvatar,
          initiatedFrom: initiatedFrom,
          initialMinutes: minutes,
          kind: kind,
        ),
      ),
      fullscreenDialog: true,
    ),
  );
}

void startAudioCall(
  BuildContext context, {
  required String calleeSlug,
  required String calleeName,
  String? calleeAvatar,
  String initiatedFrom = 'chat',
}) {
  if (calleeSlug.isEmpty) return;
  _openCallScreen(
    context,
    calleeSlug: calleeSlug,
    calleeName: calleeName,
    calleeAvatar: calleeAvatar,
    initiatedFrom: initiatedFrom,
    kind: 'audio',
  );
}

Future<void> startVideoCall(
  BuildContext context, {
  required String calleeSlug,
  required String calleeName,
  String? calleeAvatar,
  String initiatedFrom = 'chat',
}) async {
  if (calleeSlug.isEmpty) return;
  if (!currentUserCanStartCall()) {
    await showLadiesCannotCallDialog(context);
    return;
  }
  int? balance;
  try {
    final res = await sl<DioClient>().dio.get('/api/v1/wallet');
    final data = res.data is Map ? (res.data as Map)['data'] : null;
    balance = int.tryParse('${data is Map ? data['balance'] : ''}');
  } catch (_) {}
  if (!context.mounted) return;
  if (balance == null) {
    TopSnack.error(context, 'Could not load your coin balance. Try again.');
    return;
  }
  final minutes = await DurationPickerSheet.show(
    context,
    calleeDisplayName: calleeName,
    ratePerMinute: kVideoCallCoinsPerMinute,
    callerCoinBalance: balance,
  );
  if (minutes == null || !context.mounted) return;
  _openCallScreen(
    context,
    calleeSlug: calleeSlug,
    calleeName: calleeName,
    calleeAvatar: calleeAvatar,
    initiatedFrom: initiatedFrom,
    kind: 'video',
    minutes: minutes,
  );
}
