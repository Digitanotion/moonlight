import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
// import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_state.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart'
    hide ConnectionState;
import 'package:moonlight/widgets/top_snack.dart';

import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';

class GiftBottomSheet extends StatefulWidget {
  final String toUserUuid;
  final String livestreamId; // numeric as string (e.g., "63")

  /// When given, the sheet offers "Send to": the host, each guest in the
  /// box, or everyone in the box.
  final ViewerRepositoryImpl? repository;
  final String? hostName;
  final String? hostAvatar;

  const GiftBottomSheet({
    super.key,
    required this.toUserUuid,
    required this.livestreamId,
    this.repository,
    this.hostName,
    this.hostAvatar,
  });

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _Recipient {
  final String uuid;
  final String name;
  final String? avatar;
  const _Recipient(this.uuid, this.name, this.avatar);
}

const _allInBox = '__all_in_box__';

class _GiftBottomSheetState extends State<GiftBottomSheet> {
  int _qty = 1;

  /// Guests in the box (not me).
  List<_Recipient> _guests = const [];
  late String _target = widget.toUserUuid;
  bool _sendingAll = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _loadGuests();
  }

  Future<void> _loadGuests() async {
    try {
      final me = sl<CurrentUserService>().getCurrentUserId();
      final res = await sl<DioClient>().dio.get(
        '/api/v1/live/${widget.repository!.livestreamParam}/participants',
        queryParameters: {'role': 'guest', 'per_page': 20},
      );
      final list = ((res.data as Map)['data'] as List?) ?? const [];
      final guests = <_Recipient>[];
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final uuid = m['user_uuid']?.toString() ?? '';
        if (uuid.isEmpty || uuid == me) continue;
        guests.add(
          _Recipient(
            uuid,
            (m['display_name'] ?? m['user_slug'] ?? 'Guest').toString(),
            m['avatar']?.toString(),
          ),
        );
      }
      if (mounted) setState(() => _guests = guests);
    } catch (_) {}
  }

  int get _recipientCount => _target == _allInBox ? _guests.length : 1;

  /// Gift every guest in the box, one after another.
  Future<void> _sendToAll(GiftItem g) async {
    final repo = widget.repository;
    if (repo == null || _guests.isEmpty) return;
    final bloc = context.read<ViewerBloc>();
    setState(() => _sendingAll = true);
    var sent = 0;
    GiftSendResult? last;
    String? error;
    for (final r in _guests) {
      try {
        last = await repo.sendGift(
          giftCode: g.code,
          toUserUuid: r.uuid,
          livestreamId: widget.livestreamId,
          quantity: _qty,
        );
        sent++;
      } catch (e) {
        error = e.toString();
        break; // e.g. out of coins — stop, don't keep failing
      }
    }
    if (last != null) bloc.add(GiftSendSucceeded(last));
    if (!mounted) return;
    setState(() => _sendingAll = false);
    if (sent == _guests.length) {
      TopSnack.success(context, 'Sent ${g.title} to everyone in the box 🎉');
      Navigator.of(context).pop();
    } else if (sent > 0) {
      TopSnack.error(
        context,
        'Sent to $sent of ${_guests.length} — ${error ?? 'stopped early'}',
      );
    } else {
      TopSnack.error(context, 'Couldn\'t send the gift. Try again.');
    }
  }

  Widget _recipientRow() {
    if (widget.repository == null || _guests.isEmpty) {
      return const SizedBox.shrink();
    }
    final items = <(String, String, String?, IconData?)>[
      (widget.toUserUuid, widget.hostName ?? 'Host', widget.hostAvatar, null),
      for (final g in _guests) (g.uuid, g.name, g.avatar, null),
      if (_guests.length > 1)
        (_allInBox, 'All in box', null, Icons.groups_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send to',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 66,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (uuid, name, avatar, icon) in items)
                  GestureDetector(
                    onTap: () => setState(() => _target = uuid),
                    child: Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _target == uuid
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF2D55),
                                        Color(0xFFFF7A00),
                                      ],
                                    )
                                  : null,
                              color: _target == uuid ? null : Colors.white12,
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF221D44),
                              backgroundImage:
                                  (avatar ?? '').startsWith('http')
                                  ? NetworkImage(avatar!)
                                  : null,
                              child: icon != null
                                  ? Icon(icon, color: Colors.white, size: 20)
                                  : ((avatar ?? '').startsWith('http')
                                        ? null
                                        : Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          )),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _target == uuid
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 10.5,
                              fontWeight: _target == uuid
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use SafeArea + MediaQuery to avoid bottom inset and small overflows
    final mq = MediaQuery.of(context);
    final maxSheetHeight = mq.size.height * 0.75;

    return FractionallySizedBox(
      heightFactor: 0.6,
      child: SafeArea(
        child: BlocConsumer<ViewerBloc, ViewerState>(
          listenWhen: (p, n) =>
              p.sendErrorMessage != n.sendErrorMessage ||
              p.isSendingGift != n.isSendingGift,
          listener: (ctx, s) {
            if (s.sendErrorMessage != null && s.sendErrorMessage!.isNotEmpty) {
              TopSnack.error(ctx, s.sendErrorMessage!);
            }

            // On success we close via bloc (showGiftSheet=false), but if this sheet is still open, pop it.
            if (!s.isSendingGift &&
                !s.showGiftSheet &&
                Navigator.of(ctx).canPop()) {
              TopSnack.success(ctx, "Thank! Your Gift is sent successfully");
              Navigator.of(ctx).pop();
            }
          },
          buildWhen: (p, n) =>
              p.giftCatalog != n.giftCatalog ||
              p.walletBalanceCoins != n.walletBalanceCoins ||
              p.isSendingGift != n.isSendingGift,
          builder: (context, s) {
            final items = s.giftCatalog;
            // estimate grid height: 4 columns, ~110px per row (icon + text + spacing)
            final rows = (items.isEmpty ? 1 : (items.length / 4).ceil());
            final estimatedGridHeight = (rows * 110).toDouble();
            // total sheet estimate (header + qty selector + spacing) ~ 220
            final estimatedTotalHeight = min(
              maxSheetHeight,
              estimatedGridHeight + 220,
            );

            return Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Send a gift',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      if (s.walletBalanceCoins != null)
                        _pill(
                          text: '${s.walletBalanceCoins} coins',
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                    ],
                  ),
                  _recipientRow(),
                  const SizedBox(height: 8),
                  _qtySelector(),
                  const SizedBox(height: 8),

                  // Let the grid expand to fill the remaining half-screen and scroll inside it
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 6),
                      shrinkWrap: false,
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.86,
                          ),
                      itemBuilder: (ctx, i) {
                        final g = items[i];
                        final need = g.coins * _qty * _recipientCount;
                        final bal = s.walletBalanceCoins ?? 0;
                        final canAfford = bal >= need;
                        return _GiftTile(
                          item: g,
                          quantity: _qty,
                          disabled:
                              !canAfford || s.isSendingGift || _sendingAll,
                          onTap: () {
                            if (!canAfford) {
                              TopSnack.error(
                                ctx,
                                'Not enough coins for ${g.title}. Need $need',
                                onAction: () {
                                  // optional quick nav
                                  Navigator.of(
                                    ctx,
                                  ).pushNamed(RouteNames.wallet);
                                },
                              );
                              return;
                            }

                            if (_target == _allInBox) {
                              _sendToAll(g);
                              return;
                            }
                            context.read<ViewerBloc>().add(
                              GiftSendRequested(
                                g.code,
                                _qty,
                                _target,
                                widget.livestreamId,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 6),
                  if (s.isSendingGift || _sendingAll)
                    const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _qtySelector() {
    Widget chip(String label, int? val) {
      final active = (_qty == val);
      return GestureDetector(
        onTap: val == null
            ? () async {
                final n = await showDialog<int>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController(text: '10');
                    return AlertDialog(
                      backgroundColor: const Color(0xFF121212),
                      title: const Text(
                        'Custom quantity',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter quantity',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            int.tryParse(ctrl.text.trim()) ?? 1,
                          ),
                          child: const Text('Set'),
                        ),
                      ],
                    );
                  },
                );
                if (n != null && n > 0) setState(() => _qty = n);
              }
            : () => setState(() => _qty = val),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF7A00) : Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // wrap in horizontal scroll to avoid tiny overflow on very small screens
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text('Quantity', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 10),
          chip('x1', 1),
          const SizedBox(width: 8),
          chip('x5', 5),
          const SizedBox(width: 8),
          chip('x10', 10),
          const SizedBox(width: 8),
          chip('Custom', null),
        ],
      ),
    );
  }

  Widget _pill({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  final GiftItem item;
  final int quantity;
  final bool disabled;
  final VoidCallback onTap;
  const _GiftTile({
    required this.item,
    required this.quantity,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final need = item.coins * quantity;

    // ensure hit target & ink ripple + contrast
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 1 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45), // stronger contrast
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // keep fixed-size placeholder so grid doesn't jump when Future completes
                SizedBox(
                  width: 46,
                  height: 46,
                  child: FutureBuilder<Widget>(
                    future: GiftVisuals.build(
                      item.code,
                      size: 46,
                      title: item.title,
                      imageUrl: item.imageUrl,
                    ),
                    builder: (ctx, snap) {
                      if (snap.hasError) {
                        return const Icon(
                          Icons.card_giftcard,
                          color: Colors.white70,
                        );
                      }
                      if (snap.connectionState == ConnectionState.done &&
                          snap.hasData) {
                        return snap.data!;
                      }
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: AppLogoLoader(),
                        ),
                      );
                    },
                  ),
                ),
                // const SizedBox(height: 8),
                // Text(
                //   item.title,
                //   maxLines: 1,
                //   overflow: TextOverflow.ellipsis,
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                const SizedBox(height: 2),
                Text(
                  '$need',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
