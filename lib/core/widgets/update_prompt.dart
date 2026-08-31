import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart' as play;
import 'package:url_launcher/url_launcher.dart';

import 'package:moonlight/core/services/app_update_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

Future<void> _openStore(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Update strategy:
///
///  1. Ask our own `/app-version` endpoint. If it says the running build is
///     below `min_build` (or a global `force` flag is set) → a hard,
///     non-dismissible gate. This works for every install (incl. sideloads)
///     and lets us cut off old clients on demand.
///
///  2. Otherwise, let **Google Play's In-App Update API** decide — it knows
///     the instant a new version is live on the Play Store, no server config
///     needed. High-priority updates run immediately (Play's full-screen
///     flow); normal ones download in the background (flexible) and we show
///     a "restart to finish" prompt.
///
///  3. If the Play API isn't available (debug build, sideload, no Play
///     Services) we fall back to our endpoint's soft "update available"
///     sheet + a Play Store link.
///
/// Fails open everywhere — a check that errors just means "no prompt".
Future<void> maybePromptForUpdate(
  BuildContext context, {
  bool force = false,
  bool onlyForced = false,
}) async {
  // ── 1. Server-driven hard gate ──────────────────────────────────────────
  final info = await AppUpdateService.instance.check(force: force);
  if (info != null && info.forced) {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => ForceUpdateScreen(info: info),
      ),
    );
    return;
  }
  if (onlyForced) return;

  // ── 2. Google Play In-App Update (automatic on Play releases) ────────────
  if (Platform.isAndroid) {
    final handled = await _tryPlayInAppUpdate(context);
    if (handled) return;
  }

  // ── 3. Fallback: our endpoint's soft prompt ─────────────────────────────
  if (info == null || info.forced || !context.mounted) return;
  if (await AppUpdateService.instance.isSnoozed(info.latestBuild)) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpdateSheet(info: info),
  );
}

/// Returns true if Play handled it (an update flow started / completed),
/// false if there's nothing to do OR the API is unavailable (→ fall back).
Future<bool> _tryPlayInAppUpdate(BuildContext context) async {
  try {
    final result = await play.InAppUpdate.checkForUpdate()
        .timeout(const Duration(seconds: 6));

    if (result.updateAvailability !=
        play.UpdateAvailability.updateAvailable) {
      return false;
    }

    // Play's own 0–5 priority (set in the Play Console). Treat 4–5 as
    // "make them do it now".
    final highPriority = (result.updatePriority) >= 4;

    if (highPriority && result.immediateUpdateAllowed) {
      await play.InAppUpdate.performImmediateUpdate();
      return true;
    }

    if (result.flexibleUpdateAllowed) {
      await play.InAppUpdate.startFlexibleUpdate();
      // Download finished in the background — prompt to apply it.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            backgroundColor: AppColors.surface,
            content: const Text(
              'Update downloaded — restart to finish.',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Restart',
              textColor: const Color(0xFFFF7A00),
              onPressed: () => play.InAppUpdate.completeFlexibleUpdate(),
            ),
          ),
        );
      }
      return true;
    }

    if (result.immediateUpdateAllowed) {
      await play.InAppUpdate.performImmediateUpdate();
      return true;
    }

    return false;
  } catch (_) {
    // Not a Play install / no Play Services / debug build → let the caller
    // fall back to the endpoint-driven sheet.
    return false;
  }
}

class _UpdateSheet extends StatelessWidget {
  final AppUpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _UpdateGlyph(),
            const SizedBox(height: 16),
            const Text(
              'Update available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              info.latestVersion.isNotEmpty
                  ? 'Version ${info.latestVersion} is ready. Update for the latest features and fixes.'
                  : 'A new version is ready with the latest features and fixes.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (info.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  info.notes.trim(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _openStore(info.storeUrl);
                },
                child: const Text(
                  'Update now',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  AppUpdateService.instance.snooze(info.latestBuild);
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Later',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  final AppUpdateInfo info;
  const ForceUpdateScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _UpdateGlyph(large: true),
                  const SizedBox(height: 24),
                  const Text(
                    'Update required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    info.latestVersion.isNotEmpty
                        ? 'This version of Moonlight is no longer supported. Please update to version ${info.latestVersion} to continue.'
                        : 'This version of Moonlight is no longer supported. Please update to the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (info.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      info.notes.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        // Prefer Play's immediate flow when we can.
                        if (Platform.isAndroid) {
                          try {
                            final r = await play.InAppUpdate.checkForUpdate();
                            if (r.updateAvailability ==
                                    play.UpdateAvailability.updateAvailable &&
                                r.immediateUpdateAllowed) {
                              await play.InAppUpdate.performImmediateUpdate();
                              return;
                            }
                          } catch (_) {}
                        }
                        _openStore(info.storeUrl);
                      },
                      child: const Text(
                        'Update Moonlight',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateGlyph extends StatelessWidget {
  final bool large;
  const _UpdateGlyph({this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 84.0 : 56.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00).withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.system_update_alt_rounded,
        color: const Color(0xFFFF7A00),
        size: large ? 40 : 28,
      ),
    );
  }
}
