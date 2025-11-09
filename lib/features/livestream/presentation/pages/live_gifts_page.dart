import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/data/repositories/live_session_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';

class LiveGiftsPage extends StatefulWidget {
  final int livestreamId;
  const LiveGiftsPage({super.key, required this.livestreamId});

  @override
  State<LiveGiftsPage> createState() => _LiveGiftsPageState();
}

class _LiveGiftsPageState extends State<LiveGiftsPage> {
  final LiveSessionRepositoryImpl _repo =
      GetIt.I<LiveSessionRepository>() as LiveSessionRepositoryImpl;
  List<HostGiftBroadcast> _gifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final list = await _repo.fetchCollectedGifts();
      setState(() {
        _gifts = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load collected gifts: $e');
      setState(() => _loading = false);
    }
  }

  int get _totalCoins => _gifts.fold(0, (s, g) => s + (g.coinsSpent));

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifts Earned'),
        backgroundColor: const Color(0xFF020024),
      ),
      backgroundColor: const Color(0xFF020024),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    color: const Color(0xFF0A0E2A),
                    child: ListTile(
                      title: const Text(
                        'Total Coins',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text(
                        'Sum of coins earned during this livestream',
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        '+${_fmt(_totalCoins)}',
                        style: const TextStyle(
                          color: Color(0xFFFF6A00),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _gifts.isEmpty
                        ? const Center(
                            child: Text(
                              'No gifts received',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _gifts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final g = _gifts[i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A0E2A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    FutureBuilder<Widget>(
                                      future: GiftVisuals.build(
                                        g.giftCode,
                                        size: 48,
                                        title: g.giftName,
                                      ),
                                      builder: (ctx, snap) {
                                        if (snap.hasData)
                                          return SizedBox(
                                            width: 56,
                                            height: 56,
                                            child: Center(child: snap.data),
                                          );
                                        return const SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '@${g.senderDisplayName}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${g.giftName ?? g.giftCode} • x${g.quantity}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '+${_fmt(g.coinsSpent)}',
                                          style: const TextStyle(
                                            color: Color(0xFFFF6A00),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          DateFormat(
                                            'HH:mm:ss',
                                          ).format(g.timestamp.toLocal()),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
