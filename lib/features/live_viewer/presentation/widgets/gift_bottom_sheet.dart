import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/presentation/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

void showGiftBottomSheet(BuildContext context, ViewerRepositoryImpl repo) {
  final bloc = context.read<ViewerBloc>();

  // Get the necessary IDs from repository
  final String livestreamId = repo.livestreamIdNumeric.toString();
  final String hostUuid = repo.hostUuid.toString();

  // Check if there's an active guest (for sending gifts to guest)
  final state = bloc.state;
  final hasActiveGuest = state.activeGuestUuid != null;
  final iAmGuest =
      state.currentRole == 'guest' || state.currentRole == 'cohost';

  String toUserUuid = hostUuid; // Default to host
  String toUserName = "Host";

  // If there's an active guest and current user is NOT that guest,
  // allow sending gift to the guest
  if (hasActiveGuest && !iAmGuest) {
    // We need to get the guest UUID - you might need to store it in state
    toUserUuid = state.activeGuestUuid!;
    toUserName = "Guest";
  }

  // Show the gift bottom sheet
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return BlocProvider.value(
        value: bloc,
        child: GiftBottomSheet(
          toUserUuid: toUserUuid,
          livestreamId: livestreamId,
        ),
      );
    },
  ).then((_) {
    // Clean up when sheet is closed
    bloc.add(const GiftSheetClosed());
  });
}
