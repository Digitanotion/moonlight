// lib/features/chat/presentation/widgets/chat_gift_sheet.dart
//
// Send a gift to the person you're chatting with. Uses the same gift
// catalogue and /wallet/gift endpoint as livestreams; passing the
// conversation makes the server post a gift line into this chat.

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/widgets/top_snack.dart';

Future<void> showChatGiftSheet(
  BuildContext context, {
  required String conversationUuid,
  required String recipientUuid,
  required String recipientName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatGiftSheet(
      conversationUuid: conversationUuid,
      recipientUuid: recipientUuid,
      recipientName: recipientName,
    ),
  );
}

class _ChatGiftSheet extends StatefulWidget {
  final String conversationUuid;
  final String recipientUuid;
  final String recipientName;
  const _ChatGiftSheet({
    required this.conversationUuid,
    required this.recipientUuid,
    required this.recipientName,
  });

  @override
  State<_ChatGiftSheet> createState() => _ChatGiftSheetState();
}

class _ChatGiftSheetState extends State<_ChatGiftSheet> {
  final _dio = sl<DioClient>().dio;
  List<GiftItem> _gifts = const [];
  int? _balance;
  GiftItem? _picked;
  int _qty = 1;
  bool _loading = true;
  bool _sending = false;

  /// Gift art loads once per gift (not on every tap/rebuild).
  final _art = <String, Future<Widget>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        _dio.get('/api/v1/wallet/gifts'),
        _dio.get('/api/v1/wallet'),
      ]);
      final list =
          ((res[0].data as Map)['data'] as List? ?? const [])
              .map(
                (e) => GiftItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .where((g) => g.active)
              .toList()
            ..sort((a, b) => a.coins.compareTo(b.coins));
      final w = (res[1].data as Map)['data'];
      if (!mounted) return;
      setState(() {
        _gifts = list;
        _balance = int.tryParse('${w is Map ? w['balance'] : ''}');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final g = _picked;
    if (g == null || _sending) return;
    if (_balance != null && _balance! < g.coins * _qty) {
      TopSnack.error(context, 'Not enough coins. Top up your wallet.');
      return;
    }
    setState(() => _sending = true);
    try {
      await _dio.post(
        '/api/v1/wallet/gift',
        data: {
          'gift_code': g.code,
          'to_user_uuid': widget.recipientUuid,
          'quantity': _qty,
          'conversation_uuid': widget.conversationUuid,
          'idempotency_key':
              'chat-${DateTime.now().microsecondsSinceEpoch}-${g.code}',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      TopSnack.success(context, 'Gift sent to ${widget.recipientName}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      TopSnack.error(context, 'Couldn\'t send the gift. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = (_picked?.coins ?? 0) * _qty;
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFF14101F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Send a gift to ${widget.recipientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFFC24B),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _balance?.toString() ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _gifts.isEmpty
                  ? const Center(
                      child: Text(
                        'No gifts available right now.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: _gifts.length,
                      itemBuilder: (_, i) {
                        final g = _gifts[i];
                        final on = _picked?.code == g.code;
                        return GestureDetector(
                          onTap: () => setState(() => _picked = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: on
                                  ? const Color(0x33FF7A00)
                                  : Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: on
                                    ? const Color(0xFFFF7A00)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FutureBuilder<Widget>(
                                  future: _art.putIfAbsent(
                                    g.code,
                                    () => GiftVisuals.build(
                                      g.code,
                                      size: 40,
                                      imageUrl: g.imageUrl,
                                    ),
                                  ),
                                  builder: (_, s) =>
                                      s.data ?? const SizedBox(height: 40),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  g.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                  ),
                                ),
                                Text(
                                  '${g.coins}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFC24B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  for (final q in const [1, 5, 10])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('×$q'),
                        selected: _qty == q,
                        onSelected: (_) => setState(() => _qty = q),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white60,
                    ),
                    onPressed: _picked == null || _sending ? null : _send,
                    child: Text(
                      _sending
                          ? 'Sending…'
                          : _picked == null
                          ? 'Pick a gift'
                          : 'Send · $cost',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
