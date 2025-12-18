import 'package:flutter/material.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/club_context_menu.dart';

class ClubCard extends StatelessWidget {
  final Club club;

  const ClubCard({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          _Cover(club.coverImageUrl),
          const SizedBox(width: 12),
          Expanded(child: _Info(club)),
          ClubContextMenu(club: club),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover(this.url);

  bool get _valid =>
      url != null &&
      url!.isNotEmpty &&
      url != 'none' &&
      url!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white10,
      ),
      clipBehavior: Clip.antiAlias,
      child: _valid
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.groups, color: Colors.white54),
            )
          : const Icon(Icons.groups, color: Colors.white54),
    );
  }
}

class _Info extends StatelessWidget {
  final Club club;

  const _Info(this.club);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                club.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (club.isCreator)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified, size: 16, color: Colors.orange),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${club.membersCount} members',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
