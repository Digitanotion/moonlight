import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';

void showTransferOwnershipSheet(
  BuildContext context,
  String club,
  String identifier,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0A0A0F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Transfer Ownership',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This action is irreversible.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ClubsRepository>().transferOwnership(
                club: club,
                identifier: identifier,
              );
              Navigator.pop(context);
            },
            child: const Text('Confirm Transfer'),
          ),
        ],
      ),
    ),
  );
}
