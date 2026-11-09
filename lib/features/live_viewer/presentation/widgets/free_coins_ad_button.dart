// lib/features/live_viewer/presentation/widgets/free_coins_ad_button.dart
//
// "Free coins · watch ads" pill above the Join button in a livestream.
// Opens a (preloaded) Google rewarded ad; the server credits the coins when
// AdMob confirms the ad was watched.

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/rewarded_ad_service.dart';
import 'package:moonlight/widgets/top_snack.dart';

class FreeCoinsAdButton extends StatefulWidget {
  /// Sent with the reward (shows up on the server as e.g. "live:3374").
  final String? customData;
  const FreeCoinsAdButton({super.key, this.customData});

  @override
  State<FreeCoinsAdButton> createState() => _FreeCoinsAdButtonState();
}

class _FreeCoinsAdButtonState extends State<FreeCoinsAdButton> {
  final _ads = RewardedAdService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ads.preload();
  }

  Future<void> _watch() async {
    final uuid = sl<CurrentUserService>().getCurrentUserId();
    if (uuid == null || _busy) return;
    setState(() => _busy = true);
    var earned = false;
    final shown = await _ads.show(
      userUuid: uuid,
      customData: widget.customData,
      onEarned: () => earned = true,
      onClosed: () {
        if (!mounted) return;
        setState(() => _busy = false);
        if (earned) {
          TopSnack.success(
            context,
            'Thanks for watching! Your free coins are being added.',
          );
        }
      },
    );
    if (!shown && mounted) {
      setState(() => _busy = false);
      TopSnack.info(context, 'An ad is loading — try again in a moment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ads.configured) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _ads.ready,
      builder: (_, ready, _) => GestureDetector(
        onTap: _watch,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: ready ? 1 : 0.7,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC24B), Color(0xFFFF8A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.45),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Free coins',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'watch ads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
