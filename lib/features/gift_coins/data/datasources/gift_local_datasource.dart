// lib/features/gift_coins/data/datasources/gift_local_datasource.dart
import 'dart:async';
import '../../domain/entities/gift_user.dart';

class GiftLocalDataSource {
  // Dummy dataset - expand as needed
  final List<GiftUser> _users = [
    GiftUser(
      username: '@alex_moon',
      fullName: 'Alex Thompson',
      avatar: 'https://i.pravatar.cc/120?img=1',
      uuid: 'u1',
    ),
    GiftUser(
      username: '@morrison_ken',
      fullName: 'Dinobi Morrison',
      avatar: 'https://i.pravatar.cc/120?img=2',
      uuid: 'u2',
    ),
    GiftUser(
      username: '@desire_john',
      fullName: 'Desire Johnson',
      avatar: 'https://i.pravatar.cc/120?img=3',
      uuid: 'u3',
    ),
    GiftUser(
      username: '@ada_love',
      fullName: 'Ada Lovelace',
      avatar: 'https://i.pravatar.cc/120?img=4',
      uuid: 'u4',
    ),
    GiftUser(
      username: '@sam',
      fullName: 'Sam Brown',
      avatar: 'https://i.pravatar.cc/120?img=5',
      uuid: 'u5',
    ),
    GiftUser(
      username: '@jane_doe',
      fullName: 'Jane Doe',
      avatar: 'https://i.pravatar.cc/120?img=6',
      uuid: 'u6',
    ),
  ];

  int _balance = 7000;

  Future<int> getBalance() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _balance;
  }

  Future<List<GiftUser>> searchUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _users.where((u) {
      final uname = u.username.toLowerCase();
      final name = u.fullName.toLowerCase();
      final unameBare = uname.replaceAll('@', '');
      return uname.contains(q) || name.contains(q) || unameBare.contains(q);
    }).toList();
  }

  Future<void> sendGift({
    required String toUsername,
    required int amount,
    String? message,
  }) async {
    // simulate processing latency
    await Future.delayed(const Duration(milliseconds: 700));

    if (amount <= 0) {
      throw Exception('Invalid amount');
    }
    if (amount > _balance) {
      throw Exception('Insufficient coins');
    }

    // simulate random failure sometimes (for demo) - comment if not desired
    // final randomFailure = (DateTime.now().millisecondsSinceEpoch % 7 == 0);
    // if (randomFailure) throw Exception('Network error occurred');

    // subtract local balance
    _balance -= amount;
  }
}
