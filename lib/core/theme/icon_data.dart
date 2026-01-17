import 'package:flutter/material.dart';

IconData clubPlaceholderIcon({
  required String name,
  required String slug,
  String? description,
}) {
  final text = _normalize('$name $slug ${description ?? ''}');

  // ───────────────── CATEGORY DEFINITIONS ─────────────────
  final categories = <MapEntry<IconData, List<String>>>[
    MapEntry(Icons.graphic_eq_rounded, [
      'music',
      'beat',
      'dj',
      'audio',
      'sound',
      'producer',
      'song',
      'playlist',
    ]),
    MapEntry(Icons.memory_rounded, [
      'tech',
      'dev',
      'code',
      'program',
      'software',
      'ai',
      'ml',
      'startup',
      'cloud',
      'crypto',
      'web',
      'app',
    ]),
    MapEntry(Icons.sports_esports_rounded, [
      'game',
      'gaming',
      'esport',
      'console',
      'pc',
      'playstation',
      'xbox',
    ]),
    MapEntry(Icons.brush_rounded, [
      'art',
      'design',
      'illustration',
      'creative',
      'ui',
      'ux',
      'draw',
      'paint',
    ]),
    MapEntry(Icons.camera_alt_rounded, [
      'photo',
      'photography',
      'camera',
      'cinema',
      'video',
      'film',
      'vlog',
    ]),
    MapEntry(Icons.fitness_center_rounded, [
      'fitness',
      'gym',
      'workout',
      'health',
      'training',
      'body',
    ]),
    MapEntry(Icons.menu_book_rounded, [
      'book',
      'read',
      'writing',
      'author',
      'literature',
      'education',
      'study',
    ]),
    MapEntry(Icons.business_center_rounded, [
      'business',
      'finance',
      'money',
      'investment',
      'marketing',
      'sales',
      'founder',
    ]),
    MapEntry(Icons.public_rounded, [
      'community',
      'network',
      'social',
      'club',
      'group',
      'people',
    ]),
  ];

  // ───────────────── SCORING ─────────────────
  IconData? bestMatch;
  int bestScore = 0;

  for (final entry in categories) {
    int score = 0;
    for (final keyword in entry.value) {
      if (text.contains(keyword)) score++;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = entry.key;
    }
  }

  // ───────────────── FALLBACK (HASH-STABLE) ─────────────────
  if (bestMatch == null) {
    final fallbackPool = [
      Icons.groups_rounded,
      Icons.auto_awesome_rounded,
      Icons.public_rounded,
      Icons.hub_rounded,
      Icons.diversity_3_rounded,
    ];

    final hash = text.hashCode.abs();
    return fallbackPool[hash % fallbackPool.length];
  }

  return bestMatch;
}

String _normalize(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
}
