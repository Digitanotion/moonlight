// lib/features/live_viewer/presentation/widgets/live_gift_chat_line.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';

/// The gift line in a live's chat — the SAME card on the host, viewer and
/// guest screens: a glowing gold/pink card reading
/// "{avatar} {sender} sent {recipient} {Gift} ×n" with the real gift
/// artwork (bundled SVG by code, else the DB image_url, else a fallback)
/// and the coin value.
class LiveGiftChatLine extends StatelessWidget {
  final String sender;
  final String? senderAvatar;

  /// Who got it — a name, or "you".
  final String recipient;
  final String giftLabel;
  final String? giftCode;
  final String? giftImageUrl;
  final int quantity;
  final int? coins;

  const LiveGiftChatLine({
    super.key,
    required this.sender,
    required this.recipient,
    required this.giftLabel,
    this.senderAvatar,
    this.giftCode,
    this.giftImageUrl,
    this.quantity = 1,
    this.coins,
  });

  @override
  Widget build(BuildContext context) {
    final qty = quantity;
    final avatar = senderAvatar;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x4DFFB020), Color(0x40FF3D81), Color(0x33A24BFF)],
        ),
        border: Border.all(color: const Color(0x66FFD27A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withOpacity(0.18),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
              border: Border.all(color: const Color(0x66FFD27A), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: (avatar != null && avatar.startsWith('http'))
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    memCacheWidth: 48,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.person, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(
                    text: sender,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD27A),
                    ),
                  ),
                  const TextSpan(text: ' sent '),
                  TextSpan(
                    text: recipient,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: giftLabel + (qty > 1 ? '  ×$qty' : ''),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFE7B0),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GiftGlyph(code: giftCode ?? '', imageUrl: giftImageUrl, size: 30),
          if (coins != null && coins! > 0) ...[
            const SizedBox(width: 6),
            _CoinBadge(coins: coins!),
          ],
        ],
      ),
    );
  }
}

/// Gold coin chip: a shiny coin disc + the amount in bold white.
class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x33FFC24B), Color(0x1AFF8A00)],
        ),
        border: Border.all(color: const Color(0x66FFD27A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE083),
                  Color(0xFFF5A623),
                  Color(0xFFCE7A16),
                ],
              ),
              boxShadow: [BoxShadow(color: Color(0x66FFC24B), blurRadius: 4)],
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A4A0C),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves the gift artwork via GiftVisuals (bundled SVG by code → DB
/// image_url → fallback icon). GiftVisuals.build is async, so this caches
/// the resolved widget per (code,url).
class _GiftGlyph extends StatefulWidget {
  final String code;
  final String? imageUrl;
  final double size;
  const _GiftGlyph({required this.code, this.imageUrl, this.size = 28});

  @override
  State<_GiftGlyph> createState() => _GiftGlyphState();
}

class _GiftGlyphState extends State<_GiftGlyph> {
  late Future<Widget> _future;

  @override
  void initState() {
    super.initState();
    _future = GiftVisuals.build(
      widget.code,
      size: widget.size,
      imageUrl: widget.imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Widget>(
        future: _future,
        builder: (_, snap) =>
            snap.data ??
            const Icon(
              Icons.card_giftcard_rounded,
              size: 20,
              color: Colors.white,
            ),
      ),
    );
  }
}
