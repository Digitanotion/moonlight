// lib/core/utils/time_ago.dart
import 'package:intl/intl.dart';

/// Returns a Twitter-style relative time string.
///
/// < 60s      → "just now"
/// < 60m      → "42m"
/// < 24h      → "5h"
/// < 7 days   → "3d"
/// same year  → "Jan 5"
/// older      → "Jan 5, 2022"
String timeAgo(Duration diff, {DateTime? from}) {
  final seconds = diff.inSeconds.abs();
  final minutes = diff.inMinutes.abs();
  final hours = diff.inHours.abs();
  final days = diff.inDays.abs();

  if (seconds < 60) return 'just now';
  if (minutes < 60) return '${minutes}m';
  if (hours < 24) return '${hours}h';
  if (days < 7) return '${days}d';

  // Use the actual date for older posts
  final date = from ?? DateTime.now().subtract(diff);
  final now = DateTime.now();

  if (date.year == now.year) {
    return DateFormat('MMM d').format(date); // "Jan 5"
  }
  return DateFormat('MMM d, y').format(date); // "Jan 5, 2022"
}

/// Convenience wrapper that takes the post's createdAt directly.
String timeAgoFrom(DateTime createdAt) {
  return timeAgo(DateTime.now().difference(createdAt), from: createdAt);
}
