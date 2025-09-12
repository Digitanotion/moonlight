// -----------------------------
// FILE: lib/features/live/ui/widgets/gift_banner.dart
// -----------------------------
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class GiftBanner extends StatelessWidget {
  const GiftBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BannerCubit, BannerState>(
      builder: (context, state) {
        if (state.gift == null) return const SizedBox.shrink();
        final g = state.gift!;
        return _BannerShell(
          icon: Icons.card_giftcard,
          child: Text(
            '${g.from} just sent you a ‘${g.giftName}’ gift\n(worth ${g.coins} coins!)',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}

class _BannerShell extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _BannerShell({required this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA64D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
