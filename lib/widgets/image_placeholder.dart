import 'package:flutter/material.dart';
import 'package:moonlight/features/home/presentation/widgets/shimmer.dart';

/// Network image with a professional, asset-free placeholder:
/// - Shimmers ONLY while a valid URL is loading
/// - No shimmer when there is no URL (static gradient + icon)
/// - No shimmer after a load error
/// - Smooth fade-in when the image renders its first frame
///
/// Usage:
///   NetworkImageWithPlaceholder(
///     url: item.coverUrl,
///     fit: BoxFit.cover,
///     borderRadius: BorderRadius.circular(16),
///   )
class NetworkImageWithPlaceholder extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool shimmer; // master switch to allow shimmer at all
  final IconData icon; // placeholder center icon
  final double iconSize;
  final List<Color>? gradient; // optional custom gradient

  const NetworkImageWithPlaceholder({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shimmer = true,
    this.icon = Icons.videocam_rounded,
    this.iconSize = 40,
    this.gradient,
  });

  @override
  State<NetworkImageWithPlaceholder> createState() =>
      _NetworkImageWithPlaceholderState();
}

class _NetworkImageWithPlaceholderState
    extends State<NetworkImageWithPlaceholder> {
  bool _isLoading = false;
  bool _hasError = false;

  String? get _url {
    final u = widget.url?.trim();
    return (u == null || u.isEmpty) ? null : u;
  }

  @override
  void initState() {
    super.initState();
    // If there is a URL, start in "loading" mode. If no URL, we won't shimmer.
    _isLoading = _url != null;
  }

  @override
  void didUpdateWidget(covariant NetworkImageWithPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If URL changed, reset state appropriately.
    if (oldWidget.url != widget.url) {
      final hasUrl = _url != null;
      _isLoading = hasUrl;
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showShimmer = widget.shimmer && _isLoading && !_hasError;

    final placeholder = _PlaceholderBox(
      borderRadius: widget.borderRadius,
      shimmer: showShimmer, // <- shimmer only while loading a valid URL
      icon: widget.icon,
      iconSize: widget.iconSize,
      gradient: widget.gradient,
    );

    final url = _url;

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base placeholder (may shimmer depending on state)
          placeholder,

          // If there is a URL, try to render it over the placeholder.
          if (url != null)
            Image.network(
              url,
              fit: widget.fit,
              // Fade in on first frame
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                final ready = frame != null;
                return AnimatedOpacity(
                  opacity: ready ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              // Stop shimmer when load completes (loadingProgress becomes null)
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  if (_isLoading) {
                    // finished
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isLoading = false);
                    });
                  }
                  return child;
                }
                // still loading -> keep shimmer via placeholder below
                return const SizedBox.shrink();
              },
              // On error: stop shimmer & keep placeholder visible
              errorBuilder: (context, error, stack) {
                if (!_hasError || _isLoading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _hasError = true;
                      _isLoading = false;
                      setState(() {});
                    }
                  });
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }
}

/// Internal: gradient + (optional) shimmer + icon
class _PlaceholderBox extends StatelessWidget {
  final BorderRadius? borderRadius;
  final bool shimmer;
  final IconData icon;
  final double iconSize;
  final List<Color>? gradient;

  const _PlaceholderBox({
    required this.borderRadius,
    required this.shimmer,
    required this.icon,
    required this.iconSize,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final base = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: gradient ?? const [Color(0xFF2B2B2B), Color(0xFF1E1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: Colors.white54),
      ),
    );

    // Only apply shimmer when asked
    return shimmer ? Shimmer(child: base) : base;
  }
}
