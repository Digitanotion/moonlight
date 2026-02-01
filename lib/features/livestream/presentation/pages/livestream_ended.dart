import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax/iconsax.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';

class LivestreamEndedScreen extends StatefulWidget {
  final LiveEndAnalytics? analytics;
  const LivestreamEndedScreen({super.key, this.analytics});

  @override
  State<LivestreamEndedScreen> createState() => _LivestreamEndedScreenState();
}

class _LivestreamEndedScreenState extends State<LivestreamEndedScreen> {
  int? _coinsFromCollected;

  @override
  void initState() {
    super.initState();
    _hydrateCoins();
  }

  Future<void> _hydrateCoins() async {
    try {
      final repo = GetIt.I<LiveSessionRepository>(); // statically typed
      final List<HostGiftBroadcast> gifts = await repo.fetchCollectedGifts();
      final sum = gifts.fold<int>(0, (s, g) => s + g.coinsSpent);
      setState(() {
        _coinsFromCollected = sum;
      });
    } catch (e, st) {
      debugPrint('⚠️ Failed to hydrate collected coins: $e\n$st');
    }
  }

  String _fmtInt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analytics;

    final durationText = a?.durationFormatted ?? '00:00:00';
    final viewersText = a != null ? _fmtInt(a.totalViewers) : '0';
    final chatsText = a != null ? _fmtInt(a.totalChats) : '0';
    final coinsSource = a?.coinsAmount ?? 0;
    final coinsText = a != null ? _fmtInt(coinsSource) : '0';

    return Scaffold(
      backgroundColor: const Color(0xFF020024),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              const Text(
                "Livestream Ended 🎉",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Your stream has ended successfully",
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // ClipRRect(
              //   borderRadius: BorderRadius.circular(12),
              //   child: Stack(
              //     children: [
              //       Image.asset(
              //         "assets/cover_placeholder.jpg",
              //         width: double.infinity,
              //         height: 150,
              //         fit: BoxFit.cover,
              //       ),
              //       Positioned(
              //         left: 10,
              //         bottom: 10,
              //         child: Container(
              //           padding: const EdgeInsets.symmetric(
              //             horizontal: 8,
              //             vertical: 4,
              //           ),
              //           decoration: BoxDecoration(
              //             color: Colors.black54,
              //             borderRadius: BorderRadius.circular(6),
              //           ),
              //           child: const Text(
              //             "Cover image saved to your profile",
              //             style: TextStyle(color: Colors.white, fontSize: 12),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 24),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Livestream Ended",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    icon: Iconsax.clock,
                    label: "Duration",
                    value: durationText,
                  ),
                  _StatCard(
                    icon: Iconsax.eye,
                    label: "Total Viewers",
                    value: viewersText,
                  ),
                  _StatCard(
                    icon: Iconsax.message,
                    label: "Comments",
                    value: chatsText,
                  ),
                  _StatCard(
                    icon: Iconsax.coin,
                    label: "Coins Earned",
                    value: coinsText,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ElevatedButton.icon(
              //   onPressed: () {},
              //   icon: const Icon(Iconsax.repeat, color: Colors.white),
              //   label: const Text("Share Replay"),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.orange,
              //     minimumSize: const Size.fromHeight(50),
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),
              // ElevatedButton.icon(
              //   onPressed: () {},
              //   icon: const Icon(Iconsax.chart, color: Colors.white),
              //   label: const Text("View Insights"),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.grey[850],
              //     minimumSize: const Size.fromHeight(50),
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(RouteNames.home),
                icon: const Icon(Iconsax.home),
                label: const Text("Return Home"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Great job! Your audience loved the stream.\nReady to go live again?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
