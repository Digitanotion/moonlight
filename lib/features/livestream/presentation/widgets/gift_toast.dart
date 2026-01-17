// FILE: lib/features/livestream/presentation/widgets/gift_toast.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';

/// Ultra-modern TikTok-style Gift Queue System
class GiftToast extends StatefulWidget {
  const GiftToast({super.key});

  @override
  State<GiftToast> createState() => _GiftToastState();
}

class _GiftToastState extends State<GiftToast>
    with SingleTickerProviderStateMixin {
  final List<GiftEvent> _giftQueue = [];
  GiftEvent? _currentGift;
  int _comboCount = 1;
  Timer? _advanceTimer;
  Timer? _comboTimer;
  bool _isShowing = false;

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;

  // Gift combo window (2 seconds for combo stacking)
  static const Duration _comboWindow = Duration(seconds: 2);
  // Time each gift stays on screen
  static const Duration _giftDuration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize all animations in the correct order
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // FIXED: Initialize _glowAnimation properly
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _addToQueue(GiftEvent gift) {
    // Check if same sender + same gift within combo window
    if (_currentGift != null &&
        _isShowing &&
        _currentGift!.from == gift.from &&
        _currentGift!.giftName == gift.giftName) {
      // Same gift combo - stack quantity and coins
      setState(() {
        _comboCount++;
        _currentGift = GiftEvent(
          id: _currentGift!.id,
          from: _currentGift!.from,
          giftName: _currentGift!.giftName,
          coins: _currentGift!.coins + gift.coins,
        );
      });

      // Reset combo timer
      _comboTimer?.cancel();
      _comboTimer = Timer(_comboWindow, () {
        _comboCount = 1;
      });

      return;
    }

    // Add to queue
    _giftQueue.add(gift);

    // If not currently showing a gift, show next one
    if (!_isShowing) {
      _showNextGift();
    }
  }

  void _showNextGift() {
    if (_giftQueue.isEmpty) {
      _isShowing = false;
      return;
    }

    setState(() {
      _currentGift = _giftQueue.removeAt(0);
      _isShowing = true;
      _comboCount = 1;
    });

    // Start animation
    _controller.reset();
    _controller.forward();

    // Setup combo timer
    _comboTimer?.cancel();
    _comboTimer = Timer(_comboWindow, () {
      _comboCount = 1;
    });

    // Setup auto-advance timer
    _advanceTimer?.cancel();
    _advanceTimer = Timer(_giftDuration, () {
      _hideCurrentGift();
    });
  }

  void _hideCurrentGift() {
    _controller.reverse().then((_) {
      // Wait for exit animation
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          _currentGift = null;
          _isShowing = false;
        });

        // Show next gift in queue
        _showNextGift();
      });
    });
  }

  void _skipToNext() {
    _advanceTimer?.cancel();
    _comboTimer?.cancel();
    _hideCurrentGift();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _comboTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LiveHostBloc, LiveHostState>(
      listenWhen: (previous, current) =>
          previous.showGiftToast != current.showGiftToast ||
          previous.gift != current.gift,
      listener: (context, state) {
        if (state.showGiftToast && state.gift != null) {
          _addToQueue(state.gift!);

          Future.delayed(const Duration(milliseconds: 100), () {
            context.read<LiveHostBloc>().add(HideGiftToast());
          });
        }
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _currentGift == null || !_isShowing
                ? const SizedBox.shrink()
                : _AnimatedGiftToast(
                    key: ValueKey(_currentGift!.id),
                    gift: _currentGift!,
                    comboCount: _comboCount,
                    queueLength: _giftQueue.length,
                    controller: _controller,
                    onSkip: _skipToNext,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Animated wrapper for the gift toast
class _AnimatedGiftToast extends StatelessWidget {
  final GiftEvent gift;
  final int comboCount;
  final int queueLength;
  final AnimationController controller;
  final VoidCallback onSkip;

  const _AnimatedGiftToast({
    required Key key,
    required this.gift,
    required this.comboCount,
    required this.queueLength,
    required this.controller,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final opacityAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    final scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 30),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));

    final glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: opacityAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: _MagicalGiftToast(
            gift: gift,
            comboCount: comboCount,
            queueLength: queueLength,
            glowAnimation: glowAnimation,
            onSkip: onSkip,
          ),
        ),
      ),
    );
  }
}

/// Magical Gift Toast - Simple, elegant, and beautiful
class _MagicalGiftToast extends StatelessWidget {
  final GiftEvent gift;
  final int comboCount;
  final int queueLength;
  final Animation<double> glowAnimation;
  final VoidCallback onSkip;

  const _MagicalGiftToast({
    required this.gift,
    required this.comboCount,
    required this.queueLength,
    required this.glowAnimation,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),

        // Stack children
        child: Stack(
          children: [
            // Glow effect
            Positioned.fill(
              child: AnimatedBuilder(
                animation: glowAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.2,
                        colors: [
                          const Color(
                            0xFFFF6A00,
                          ).withOpacity(glowAnimation.value * 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: Sender info and queue indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender avatar/emoji
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6A00),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🎁', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sender name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gift.from,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'sent you a gift',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Queue indicator
                      if (queueLength > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF6A00).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '+$queueLength',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Middle: Big gift visual
                  Row(
                    children: [
                      // Big gift visual
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Center(
                          child: FutureBuilder<Widget>(
                            future: GiftVisuals.build(
                              gift.giftName,
                              size: 48,
                              emojiStyle: const TextStyle(fontSize: 36),
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Color(0xFFFF6A00),
                                  size: 36,
                                );
                              }
                              return snapshot.data ??
                                  const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Color(0xFFFF6A00),
                                    size: 36,
                                  );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Gift details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gift name
                            Text(
                              gift.giftName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Coins value
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFFD700),
                                        const Color(0xFFFF6A00),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6A00,
                                        ).withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+${gift.coins}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Combo badge
                                if (comboCount > 1) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'x$comboCount',
                                      style: const TextStyle(
                                        color: Color(0xFFFF6A00),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.7, // Shows progress
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF6A00),
                              const Color(0xFFFFD700),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Skip button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onSkip,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
