import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';

Future<void> showDeleteClubDialog(BuildContext context, String club) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0A0A0F),
      title: const Text('Delete Club', style: TextStyle(color: Colors.white)),
      content: const Text(
        'This action cannot be undone.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            await context.read<ClubsRepository>().deleteClub(club: club);
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
