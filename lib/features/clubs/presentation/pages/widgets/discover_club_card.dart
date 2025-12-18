import 'package:flutter/material.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';

class DiscoverClubCard extends StatelessWidget {
  final Club club;
  final bool joining;
  final VoidCallback onJoin;

  const DiscoverClubCard({
    super.key,
    required this.club,
    required this.joining,
    required this.onJoin,
  });
  //ASAS

  @override
  Widget build(BuildContext context) {
    final joined = club.isMember;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  club.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  '${club.membersCount} members',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _JoinButton(
            joined: joined,
            joining: joining,
            onPressed: joined ? null : onJoin,
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final bool joined;
  final bool joining;
  final VoidCallback? onPressed;

  const _JoinButton({
    required this.joined,
    required this.joining,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (joined) {
      return _pill(
        label: 'Joined Club',
        color: Colors.white24,
        textColor: Colors.white70,
      );
    }

    return GestureDetector(
      onTap: joining ? null : onPressed,
      child: _pill(
        label: joining ? 'Joining…' : 'Join',
        color: const Color(0xFFFF7A00),
        textColor: Colors.white,
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  const _Cover(this.url);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white10,
        image: (url != null && url!.startsWith('http'))
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url == null
          ? const Icon(Icons.groups, color: Colors.white54)
          : null,
    );
  }
}
