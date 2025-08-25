// lib/features/home/presentation/widgets/live_now_section.dart
import 'package:flutter/material.dart';
import 'live_card.dart';

class LiveNowSection extends StatelessWidget {
  const LiveNowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = _items[i];
          return LiveCard(
            thumbnailUrl: it.thumbnailUrl,
            handle: it.handle,
            role: it.role,
            countryCode: it.countryCode,
            viewers: it.viewers,
          );
        },
      ),
    );
  }
}

class _LiveItem {
  final String thumbnailUrl, handle, role, countryCode, viewers;
  _LiveItem(
    this.thumbnailUrl,
    this.handle,
    this.role,
    this.countryCode,
    this.viewers,
  );
}

final _items = <_LiveItem>[
  _LiveItem(
    'https://images.pexels.com/photos/2773941/pexels-photo-2773941.jpeg?auto=compress&w=800',
    '@sarah_gam...',
    'Active member',
    '🇳🇬',
    '2.4K',
  ),
  _LiveItem(
    'https://images.pexels.com/photos/4253312/pexels-photo-4253312.jpeg?auto=compress&w=800',
    '@chef_dami',
    'Superstar',
    '🇺🇸',
    '2.4K',
  ),
  _LiveItem(
    'https://images.pexels.com/photos/2773941/pexels-photo-2773941.jpeg?auto=compress&w=800',
    '@sarah_gam...',
    'Active member',
    '🇳🇬',
    '2.4K',
  ),
  _LiveItem(
    'https://images.pexels.com/photos/4253312/pexels-photo-4253312.jpeg?auto=compress&w=800',
    '@chef_dami',
    'Superstar',
    '🇺🇸',
    '2.4K',
  ),
  _LiveItem(
    'https://images.pexels.com/photos/2773941/pexels-photo-2773941.jpeg?auto=compress&w=800',
    '@sarah_gam...',
    'Active member',
    '🇳🇬',
    '2.4K',
  ),
  _LiveItem(
    'https://images.pexels.com/photos/4253312/pexels-photo-4253312.jpeg?auto=compress&w=800',
    '@chef_dami',
    'Superstar',
    '🇺🇸',
    '2.4K',
  ),
];
