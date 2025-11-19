// lib/features/home/presentation/widgets/live_tile_grid.dart
// ... (file header and imports remain unchanged)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/widgets/image_placeholder.dart';
import 'package:moonlight/features/wallet/services/idempotency_helper.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';
import '../../../../core/injection_container.dart';

class LiveTileGrid extends StatelessWidget {
  final LiveItem item;
  const LiveTileGrid({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final flag = isoToFlagEmoji(item.countryIso2 ?? '');
    final countryName = item.countryName ?? 'Unknown';

    Widget _image() {
      final placeholder = Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
      );
      final url = item.coverUrl;
      if (url == null || url.trim().isEmpty) return placeholder;

      // Fade-in + error fallback
      return FadeInImage.assetNetwork(
        placeholder: 'assets/images/logo.png',
        image: url,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => placeholder,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // NEW: always navigate to viewer. Viewer will handle premium overlay / payment.
        Navigator.of(context).pushNamed(
          RouteNames.liveViewer,
          arguments: {
            'id': item.id, // REQUIRED numeric for Pusher
            'uuid': item.uuid, // REST path (uuid or numeric ok)
            'channel': item.channel, // e.g. "live_zNt4yMaaQwhf"
            'hostUuid': item.hostUuid,
            'hostName': item.handle.replaceFirst('@', ''),
            'hostAvatar': item.coverUrl,
            'title': item.title,
            'startedAt': item.startedAt,
            'role': item.role,
            // premium metadata so viewer can show overlay and payment CTA
            'isPremium': item.isPremium, // note: int (1 or 0)
            'premiumFee': item.premiumFee,
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: NetworkImageWithPlaceholder(
                  url: item.coverUrl, // cover_url from API (may be null)
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(16),
                  shimmer: true, // nice social-style loading
                  icon: Icons.videocam_rounded, // or any icon you prefer
                  iconSize: 44,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.60),
                        Colors.black.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatCompact(item.viewers),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.role,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          countryName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumConfirmBottomSheet(BuildContext context, LiveItem item) {
    final repo = sl<LiveFeedRepository>();
    final idempo = sl<IdempotencyHelper>();
    final uuid = const Uuid();

    // State variables declared outside StatefulBuilder so they persist across rebuilds.
    bool isLoading = false;
    String? statusMessage;
    int? newBalance; // if server returns new balance we display it

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void setLoading(bool v) => setState(() => isLoading = v);
            void setStatus(String? m) => setState(() => statusMessage = m);

            // Core payment + retry logic: generates a NEW idempotency key when the server
            // responds with "already processing" (or similar). Retries up to maxAttempts.
            Future<void> payWithAutoNewIdempotency() async {
              const int maxAttempts =
                  5; // initial attempt + 4 retries (adjustable)
              final List<int> backoffMs = [
                0,
                600,
                1200,
                2400,
                4800,
              ]; // exponential-ish

              setLoading(true);
              setStatus(null);

              List<String> persistedKeys = [];
              for (int attempt = 0; attempt < maxAttempts; attempt++) {
                // If there's a backoff for this attempt (skip for attempt 0)
                if (backoffMs.length > attempt && backoffMs[attempt] > 0) {
                  await Future.delayed(
                    Duration(milliseconds: backoffMs[attempt]),
                  );
                }

                final idempotencyKey = uuid.v4();

                // Persist before the call for crash recovery
                try {
                  await idempo.persist(idempotencyKey, {
                    'liveId': item.id,
                    'attempt': attempt,
                  });
                  persistedKeys.add(idempotencyKey);
                } catch (e) {
                  // Non-fatal: continue but inform dev/user
                  TopSnack.info(
                    context,
                    'Warning: local persist failed for attempt ${attempt + 1}.',
                  );
                }

                try {
                  final resp = await repo.payPremium(
                    liveId: item.id,
                    idempotencyKey: idempotencyKey,
                  );

                  final status = (resp['status'] ?? '') as String;
                  final message = (resp['message'] as String?) ?? '';
                  final data = resp['data'] as Map<String, dynamic>?;

                  if (status.toLowerCase() == 'success') {
                    // success: mark this idempotency key as complete and cleanup older persisted keys
                    try {
                      await idempo.complete(idempotencyKey);
                    } catch (_) {}

                    for (final k in persistedKeys) {
                      if (k != idempotencyKey) {
                        try {
                          await idempo.complete(k);
                        } catch (_) {}
                      }
                    }

                    if (data != null && data['new_balance_coins'] != null) {
                      newBalance = (data['new_balance_coins'] as num).toInt();
                      // TODO: update global wallet state / bloc with newBalance
                    }

                    TopSnack.success(
                      context,
                      data != null && data['message'] != null
                          ? data['message'] as String
                          : 'Premium paid successfully',
                    );

                    // close sheet then navigate to viewer
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      RouteNames.liveViewer,
                      arguments: {
                        'id': item.id,
                        'uuid': item.uuid,
                        'channel': item.channel,
                        'hostUuid': item.hostUuid,
                        'hostName': item.handle.replaceFirst('@', ''),
                        'hostAvatar': item.coverUrl,
                        'title': item.title,
                        'startedAt': item.startedAt,
                        'role': item.role,
                      },
                    );

                    setLoading(false);
                    return; // done
                  } else {
                    final lower = message.toLowerCase();

                    // If server says it's already processing, generate a NEW idempotency key and retry
                    if (lower.contains('already processing') ||
                        lower.contains('processing')) {
                      // If this was the last allowed attempt, show friendly message and stop
                      if (attempt == maxAttempts - 1) {
                        setStatus(
                          'Request still processing. Please try again later.',
                        );
                        TopSnack.error(
                          context,
                          'Request still processing — try again later.',
                        );
                        break;
                      } else {
                        final nextAttempt = attempt + 1;
                        setStatus(
                          'Request already processing — retrying (attempt ${nextAttempt}/${maxAttempts})...',
                        );
                        TopSnack.info(
                          context,
                          'Request already processing — retrying (${nextAttempt}/${maxAttempts})',
                        );
                        // continue loop; next iteration will create a new idempotency key
                        continue;
                      }
                    } else if (lower.contains('insufficient')) {
                      setStatus(
                        'Insufficient coins. Open wallet to buy coins.',
                      );
                      TopSnack.error(context, 'Insufficient coins.');
                      // keep persisted keys for potential recovery
                      break;
                    } else if (lower.contains('unauthorized') ||
                        lower.contains('unauth')) {
                      setStatus('You are not allowed to view this stream.');
                      TopSnack.error(context, 'This action is unauthorized.');
                      // remove this persisted key as it won't succeed
                      try {
                        await idempo.complete(idempotencyKey);
                      } catch (_) {}
                      break;
                    } else {
                      // Other server error: show message and stop retrying
                      setStatus(
                        message.isNotEmpty ? message : 'Payment failed.',
                      );
                      TopSnack.error(
                        context,
                        message.isNotEmpty ? message : 'Payment failed.',
                      );
                      break;
                    }
                  }
                } catch (e) {
                  // Network / unexpected error: either retry (if attempts left) or show final error
                  final nextAttempt = attempt + 1;
                  if (attempt == maxAttempts - 1) {
                    setStatus('Network error. Please try again later.');
                    TopSnack.error(
                      context,
                      'Network error. Please try again later.',
                    );
                    break;
                  } else {
                    setStatus(
                      'Network error — retrying (${nextAttempt}/${maxAttempts})...',
                    );
                    TopSnack.info(
                      context,
                      'Network error — retry ${nextAttempt}/${maxAttempts}',
                    );
                    // continue to next loop iteration (new idempotency key will be created)
                    continue;
                  }
                }
              } // for attempts

              // If we exit loop without success, leave persistedKeys for recovery and re-enable UI
              setLoading(false);
            } // payWithAutoNewIdempotency

            // UI (unchanged)
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                top: 12,
              ),
              child: Material(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF0B0B0D),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 42,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                        ),
                        // leadingWidth: 64,
                        minLeadingWidth: 64,
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: NetworkImageWithPlaceholder(
                              url: item.coverUrl,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              shimmer: false,
                              icon: Icons.videocam_rounded,
                            ),
                          ),
                        ),
                        title: Text(
                          item.title ?? 'Premium Stream',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          item.handle.replaceFirst('@', ''),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Premium Access Required',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Unlock this exclusive live stream and support your favorite creator.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (item.premiumFee != null) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.stars_rounded,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${item.premiumFee} coins',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            Divider(
                              color: Colors.white.withOpacity(0.1),
                              thickness: 1,
                              height: 16,
                            ),
                            const Text(
                              'The fee will be deducted automatically from your wallet balance once you proceed.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            if (statusMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                statusMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // CTA row
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async =>
                                              await payWithAutoNewIdempotency(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Proceed',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                          Navigator.of(
                                            context,
                                          ).pushNamed('/wallet');
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.06),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Open Wallet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
