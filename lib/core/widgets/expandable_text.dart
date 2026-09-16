// lib/core/widgets/expandable_text.dart
//
// Shared "read more" text for anywhere a post caption/comment is shown.
// Collapses to [collapsedMaxLines], with an inline "… more" affix colored
// with the app's accent — tapping the text (or the affix) expands it in
// place with a smooth size animation; tapping again collapses it back.
//
// The truncation point is computed per-layout (not just character-capped),
// so it's accurate at any width/font scale: a binary search finds the
// longest prefix of the text whose "… more"-suffixed rendering still fits
// within collapsedMaxLines at the actual available width.

import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int collapsedMaxLines;
  final TextAlign textAlign;
  final Color moreColor;

  const ExpandableText(
    this.text, {
    super.key,
    required this.style,
    this.collapsedMaxLines = 3,
    this.textAlign = TextAlign.start,
    this.moreColor = AppColors.secondary,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  int _findCutoff(String text, TextStyle style, double maxWidth) {
    int low = 0;
    int high = text.length;
    int best = text.length;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = '${text.substring(0, mid).trimRight()}… more';
      final tp = TextPainter(
        text: TextSpan(text: candidate, style: style),
        maxLines: widget.collapsedMaxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (!tp.didExceedMaxLines) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fullTp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.collapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);
        final overflows = fullTp.didExceedMaxLines;

        Widget content;
        if (!overflows || _expanded) {
          content = Text(
            widget.text,
            key: const ValueKey('expanded'),
            style: widget.style,
            textAlign: widget.textAlign,
          );
        } else {
          final cutoff = _findCutoff(widget.text, widget.style, maxWidth);
          content = Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${widget.text.substring(0, cutoff).trimRight()}… ',
                ),
                TextSpan(
                  text: 'more',
                  style: widget.style.copyWith(
                    color: widget.moreColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            key: const ValueKey('collapsed'),
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: overflows
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
