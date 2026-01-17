import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class NetworkErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onChangeCountry;
  final String? message;
  const NetworkErrorState({
    super.key,
    required this.onRetry,
    this.onChangeCountry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.wifi_off_rounded,
      iconBg: const [Color(0xFF3A1F1F), Color(0xFF251111)],
      title: 'Connection issue',
      subtitle:
          message ??
          'We couldn’t load live streams.\nCheck your network and try again.',
      primaryAction: _StateAction(
        label: 'Try again',
        onTap: onRetry,
        kind: _ActionKind.filled,
      ),
      secondaryAction: onChangeCountry == null
          ? null
          : _StateAction(
              label: 'Change country',
              onTap: onChangeCountry!,
              kind: _ActionKind.ghost,
            ),
      footerHint: '',
    );
  }
}

class EmptyLiveState extends StatelessWidget {
  final VoidCallback? onChangeCountry;
  final VoidCallback? onGoLive;
  final VoidCallback? onRefresh;
  const EmptyLiveState({
    super.key,
    this.onChangeCountry,
    this.onGoLive,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.podcasts_rounded,
      iconBg: const [Color(0xFF1A2837), Color(0xFF0F1822)],
      title: 'No live streams right now',
      subtitle: 'Try a different country or come back in a bit.',
      primaryAction: onChangeCountry == null
          ? null
          : _StateAction(
              label: 'Try again',
              onTap: onRefresh ?? () {},
              kind: _ActionKind.filled,
            ),
      secondaryAction: onGoLive == null
          ? null
          : _StateAction(
              label: 'Go live',
              onTap: onGoLive!,
              kind: _ActionKind.ghost,
            ),
      footerHint: '',
    );
  }
}

/* ---------- Foundation ---------- */

enum _ActionKind { filled, ghost }

class _StateAction {
  final String label;
  final VoidCallback onTap;
  final _ActionKind kind;
  _StateAction({required this.label, required this.onTap, required this.kind});
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final List<Color> iconBg;
  final String title;
  final String subtitle;
  final _StateAction? primaryAction;
  final _StateAction? secondaryAction;
  final String? footerHint;

  const _StateCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.primaryAction,
    this.secondaryAction,
    this.footerHint,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: iconBg,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconBg.last.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (primaryAction != null)
                      _ModernButton(action: primaryAction!, isPrimary: true),
                    // if (primaryAction != null && secondaryAction != null)
                    //   const SizedBox(width: 10),
                    // if (secondaryAction != null)
                    //   _ModernButton(action: secondaryAction!, isPrimary: false),
                  ],
                ),
                if (footerHint != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    footerHint!,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernButton extends StatefulWidget {
  final _StateAction action;
  final bool isPrimary;
  const _ModernButton({required this.action, required this.isPrimary});

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.isPrimary;
    final bg = isPrimary
        ? [AppColors.textRed, const Color(0xFFE64A4A)]
        : [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.04)];

    final borderColor = isPrimary
        ? Colors.transparent
        : Colors.white.withOpacity(0.15);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _hover ? 1.03 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.action.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: bg,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isPrimary)
                  const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white,
                  )
                else
                  const Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                const SizedBox(width: 8),
                Text(
                  widget.action.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? Colors.white : Colors.white70,
                    fontSize: 13,
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
