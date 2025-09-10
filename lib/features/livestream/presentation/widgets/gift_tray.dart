// lib/features/livestream/presentation/widgets/gift_tray.dart
import 'package:flutter/material.dart';

class GiftTray extends StatelessWidget {
  final int balance;
  final void Function(String type, int coins) onGiftTap;
  const GiftTray({super.key, required this.balance, required this.onGiftTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 86),
        child: Row(
          children: [
            _balancePill(balance),
            const SizedBox(width: 10),
            _giftButton('Golden Crown', 500, onGiftTap),
            const SizedBox(width: 8),
            _giftButton('Rose', 50, onGiftTap),
          ],
        ),
      ),
    );
  }

  static Widget _balancePill(int coins) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2D1F3A),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.monetization_on_rounded,
          color: Color(0xFFFFD34E),
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          '$coins',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  static Widget _giftButton(
    String name,
    int coins,
    void Function(String, int) onTap,
  ) => GestureDetector(
    onTap: () => onTap(name.toLowerCase().replaceAll(' ', '_'), coins),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF19213F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );
}
