import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Chrome-less in-app web page. No address bar, no browser toolbar — just
/// the page, a slim progress line, and a single floating close button.
/// Used for the marketing-site legal / about pages so they feel native.
class WebViewScreen extends StatefulWidget {
  final String title; // kept for call-site compatibility; not shown as chrome
  final String url;

  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.dark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageStarted: (_) => setState(() {
            _loading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            // Sub-resource errors (ads, fonts) shouldn't blank the page —
            // only fail on a main-frame load error.
            if (err.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Stack(
        children: [
          if (!_hasError)
            Positioned.fill(child: WebViewWidget(controller: _controller)),

          if (_hasError) _ErrorView(onRetry: () {
            setState(() => _hasError = false);
            _controller.reload();
          }),

          // Slim top progress line (under the status bar).
          if (_loading && !_hasError)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),

          // Single floating close button — the only chrome.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load page',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
