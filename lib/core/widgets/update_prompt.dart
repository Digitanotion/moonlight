import 'package:flutter/material.dart';
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

/// Runs an update check and, if warranted, shows the right prompt:
///   - forced  -> a non-dismissible full-screen gate
///   - soft    -> a dismissible bottom sheet (once per new build)
///
/// Safe to call on every home entry / resume — the service throttles the
/// network check and the soft prompt is snoozed per build.
Future<void> maybePromptForUpdate(
  BuildContext context, {
  bool force = false,
  bool onlyForced = false,
}) async {
  final info = await AppUpdateService.instance.check(force: force);
  if (info == null || !context.mounted) return;

  if (info.forced) {
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
  if (await AppUpdateService.instance.isSnoozed(info.latestBuild)) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpdateSheet(info: info),
  );
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45),
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                child: Text('Later', style: TextStyle(color: AppColors.textSecondary)),
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
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  if (info.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      info.notes.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openStore(info.storeUrl),
                      child: const Text(
                        'Update Moonlight',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
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
