// lib/features/live_viewer/presentation/widgets/overlays/chat_panel.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _scrollController = ScrollController();
  bool _isAtTop = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final isAtTop = _scrollController.position.pixels == 0;
    if (isAtTop != _isAtTop) {
      setState(() {
        _isAtTop = isAtTop;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.chat != n.chat || p.host != n.host,
      builder: (_, s) {
        final chat = s.chat.reversed.toList();
        final hostName = s.host?.name ?? 'the host';
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
          child: Container(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _scrollController,
                    reverse: true,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: chat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = chat[i];
                      if (m.kind == ChatMessageKind.gift) {
                        return _GiftChatLine(
                          message: m,
                          hostName: hostName,
                          isNew: i == 0,
                        );
                      }
                      return _ModernChatBubble(
                        username: m.username,
                        text: m.text,
                        isNew: i == 0,
                        isHost: m.isHost,
                      );
                    },
                  ),
                  if (!_isAtTop)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Distinct "gift" line in the live chat — visually separate from normal
/// messages: a glowing gold/pink card reading
/// "{avatar} {sender} sent {host} a {Gift}" with the real gift artwork
/// (bundled SVG by code, else the DB image_url, else a fallback).
class _GiftChatLine extends StatelessWidget {
  final ChatMessage message;
  final String hostName;
  final bool isNew;

  const _GiftChatLine({
    required this.message,
    required this.hostName,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final qty = message.giftQuantity;
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
            child: (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: message.avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.person, size: 16, color: Colors.white70),
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
                    text: message.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD27A),
                    ),
                  ),
                  const TextSpan(text: ' sent '),
                  TextSpan(
                    text: hostName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: message.text + (qty > 1 ? '  ×$qty' : ''),
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
          _GiftGlyph(
            code: message.giftCode ?? '',
            imageUrl: message.giftImageUrl,
            size: 30,
          ),
          if (message.giftCoins != null && message.giftCoins! > 0) ...[
            const SizedBox(width: 6),
            _CoinBadge(coins: message.giftCoins!),
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
                colors: [Color(0xFFFFE083), Color(0xFFF5A623), Color(0xFFCE7A16)],
              ),
              boxShadow: [
                BoxShadow(color: Color(0x66FFC24B), blurRadius: 4),
              ],
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
            const Icon(Icons.card_giftcard_rounded,
                size: 20, color: Colors.white),
      ),
    );
  }
}

class _ModernChatBubble extends StatelessWidget {
  final String username;
  final String text;
  final bool isHost;
  final bool isNew;

  const _ModernChatBubble({
    required this.username,
    required this.text,
    this.isHost = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(left: isNew ? 0 : 0, right: 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isHost
              ? const Color(0xFFFF7A00).withOpacity(0.25)
              : Colors.black.withOpacity(0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10, top: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHost
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF29C3FF),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: isHost
                                ? const Color(0xFFFF7A00)
                                : const Color(0xFF29C3FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFF7A00).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNew)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 0, top: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF7A00),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
