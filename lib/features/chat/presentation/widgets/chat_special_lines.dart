// lib/features/chat/presentation/widgets/chat_special_lines.dart
//
// Non-text chat lines: a gift sent in the chat, the call log ("Audio call ·
// 2:31", "Missed video call") and the voice-note player.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:video_player/video_player.dart';

/// "🎁 You sent Rose ×2 · 10 coins" — centred card, gold/pink like the live
/// gift card.
class ChatGiftLine extends StatelessWidget {
  final Message message;
  final bool isMe;
  const ChatGiftLine({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final m = message.meta ?? const {};
    final title = (m['gift_title'] ?? 'a gift').toString();
    final qty = (m['quantity'] as num?)?.toInt() ?? 1;
    final coins = (m['coins'] as num?)?.toInt() ?? 0;
    final who = isMe ? 'You' : message.sender.fullName.split(' ').first;
    final to = isMe ? 'them' : 'you';
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0x4DFFB020), Color(0x40FF3D81), Color(0x33A24BFF)],
          ),
          border: Border.all(color: const Color(0x66FFD27A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GiftArt(
              code: (m['gift_code'] ?? '').toString(),
              imageUrl: m['gift_image']?.toString(),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  children: [
                    TextSpan(
                      text: who,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD27A),
                      ),
                    ),
                    TextSpan(text: ' sent $to '),
                    TextSpan(
                      text: title + (qty > 1 ? ' ×$qty' : ''),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (coins > 0) TextSpan(text: '  ·  $coins coins'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftArt extends StatefulWidget {
  final String code;
  final String? imageUrl;
  const _GiftArt({required this.code, this.imageUrl});

  @override
  State<_GiftArt> createState() => _GiftArtState();
}

class _GiftArtState extends State<_GiftArt> {
  late final Future<Widget> _art = GiftVisuals.build(
    widget.code,
    size: 28,
    imageUrl: widget.imageUrl,
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: FutureBuilder<Widget>(
      future: _art,
      builder: (_, s) =>
          s.data ??
          const Icon(
            Icons.card_giftcard_rounded,
            color: Colors.white,
            size: 20,
          ),
    ),
  );
}

/// Call log line: phone/camera icon, "Audio call · 2:31" or "Missed …".
class ChatCallLine extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onCallBack;
  const ChatCallLine({
    super.key,
    required this.message,
    required this.isMe,
    this.onCallBack,
  });

  @override
  Widget build(BuildContext context) {
    final m = message.meta ?? const {};
    final video = m['call_kind'] == 'video';
    final answered = m['answered'] == true;
    final missed = !answered;
    final color = missed && !isMe ? const Color(0xFFFF6B81) : Colors.white70;
    var text = message.body;
    if (missed && isMe) text = text.replaceFirst('Missed', 'Unanswered');
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onCallBack,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                video
                    ? (missed
                          ? Icons.missed_video_call_rounded
                          : Icons.videocam_rounded)
                    : (missed
                          ? Icons.phone_missed_rounded
                          : Icons.call_rounded),
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: color, fontSize: 13)),
              if (onCallBack != null) ...[
                const SizedBox(width: 10),
                const Text(
                  'Call back',
                  style: TextStyle(
                    color: Color(0xFF58B5FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice note: play/pause, progress bar and time.
class VoiceNotePlayer extends StatefulWidget {
  final String url;
  final File? localFile;
  final int? durationSeconds;
  final bool isMe;
  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.localFile,
    this.durationSeconds,
    this.isMe = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  VideoPlayerController? _c;
  bool _loading = false;

  Future<void> _toggle() async {
    if (_c == null) {
      setState(() => _loading = true);
      final c = widget.localFile != null && widget.localFile!.existsSync()
          ? VideoPlayerController.file(widget.localFile!)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      try {
        await c.initialize();
      } catch (_) {
        await c.dispose();
        if (mounted) setState(() => _loading = false);
        return;
      }
      c.addListener(() {
        if (!mounted) return;
        // Back to the start when it finishes.
        if (c.value.isCompleted) {
          c.pause();
          c.seekTo(Duration.zero);
        }
        setState(() {});
      });
      _c = c;
      _loading = false;
    }
    final c = _c!;
    c.value.isPlaying ? await c.pause() : await c.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final total =
        c?.value.duration ?? Duration(seconds: widget.durationSeconds ?? 0);
    final pos = c?.value.position ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final playing = c?.value.isPlaying ?? false;
    final accent = widget.isMe ? Colors.white : const Color(0xFF58B5FF);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _loading ? null : _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: accent,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.mic_rounded, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(playing || pos > Duration.zero ? pos : total),
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
