import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/presentation/gift_bottom_sheet.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

/// Gift sheet for a livestream. Sends to the host by default; the sheet
/// lets the viewer (or a guest) pick someone in the box, or everyone in it.
void showGiftBottomSheet(BuildContext context, ViewerRepositoryImpl repo) {
  final bloc = context.read<ViewerBloc>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: bloc,
      child: GiftBottomSheet(
        toUserUuid: repo.hostUuid.toString(),
        livestreamId: repo.livestreamIdNumeric.toString(),
        repository: repo,
        hostName: 'Host',
      ),
    ),
  ).then((_) => bloc.add(const GiftSheetClosed()));
}
