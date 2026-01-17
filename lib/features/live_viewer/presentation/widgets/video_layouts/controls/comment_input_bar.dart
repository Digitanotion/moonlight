// lib/features/live_viewer/presentation/widgets/controls/comment_input_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class CommentInputBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onGiftTap;
  final VoidCallback? onToggleControls;

  const CommentInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onGiftTap,
    this.onToggleControls,
  });

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();
  bool _isControlsPanelVisible = false;
  final LayerLink _layerLink = LayerLink();

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      widget.controller.clear();
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _addEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void _toggleControlsPanel() {
    setState(() {
      _isControlsPanelVisible = !_isControlsPanelVisible;
    });
    widget.onToggleControls?.call();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.showChatUI != n.showChatUI,
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji picker overlay
            if (_showEmojiPicker) _buildEmojiPicker(),

            // Main input bar
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, isSmallScreen ? 24 : 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Main input field
                      Expanded(
                        child: CompositedTransformTarget(
                          link: _layerLink,
                          child: Container(
                            height: isSmallScreen ? 44 : 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.black.withOpacity(0.5),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: TextField(
                                      controller: widget.controller,
                                      focusNode: _focusNode,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 14 : 15,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Say something...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: isSmallScreen ? 14 : 15,
                                          fontWeight: FontWeight.w400,
                                          height: 1.2,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                      ),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                // Emoji button
                                Container(
                                  width: 44,
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      _showEmojiPicker
                                          ? Icons.keyboard_rounded
                                          : Icons.emoji_emotions_outlined,
                                      color: _showEmojiPicker
                                          ? const Color(0xFFFF7A00)
                                          : Colors.white.withOpacity(0.7),
                                      size: isSmallScreen ? 18 : 20,
                                    ),
                                    onPressed: _toggleEmojiPicker,
                                    padding: EdgeInsets.zero,
                                    splashRadius: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Send and action buttons
                      Row(
                        children: [
                          // Send button
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: isSmallScreen ? 38 : 44,
                              height: isSmallScreen ? 38 : 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF7A00),
                                    const Color(0xFFFF9E40),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF7A00,
                                    ).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 18 : 20,
                              ),
                            ),
                          ),

                          SizedBox(width: isSmallScreen ? 6 : 8),

                          // Action buttons container
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                // Chat toggle
                                _TikTokActionButton(
                                  icon: state.showChatUI
                                      ? Icons.chat_bubble_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  onTap: () {
                                    context.read<ViewerBloc>().add(
                                      state.showChatUI
                                          ? const ChatHideRequested()
                                          : const ChatShowRequested(),
                                    );
                                  },
                                  size: isSmallScreen ? 18 : 20,
                                ),

                                const SizedBox(width: 6),

                                // Gift button
                                _TikTokActionButton(
                                  icon: Icons.card_giftcard_rounded,
                                  onTap:
                                      widget.onGiftTap ??
                                      () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Gift feature coming soon!',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                  isGift: true,
                                  size: isSmallScreen ? 18 : 20,
                                ),

                                const SizedBox(width: 6),

                                // Menu button
                                _TikTokActionButton(
                                  icon: _isControlsPanelVisible
                                      ? Icons.more_vert_rounded
                                      : Icons.more_vert_rounded,
                                  onTap: _toggleControlsPanel,
                                  isActive: _isControlsPanelVisible,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Typing indicator
                  if (widget.controller.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            'Press Enter to send',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmojiPicker() {
    // Common emojis for live streaming
    final popularEmojis = [
      '😂',
      '😍',
      '😭',
      '🔥',
      '🥰',
      '👏',
      '🎉',
      '🙏',
      '❤️',
      '👍',
      '👌',
      '💯',
      '😎',
      '🤔',
      '😢',
      '🤣',
      '😘',
      '😁',
      '😉',
      '🤩',
      '🤗',
      '😴',
      '😇',
      '🥳',
      '😱',
      '🤯',
      '😡',
      '🥺',
      '🤮',
      '🤢',
    ];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Emoji category tabs (optional - simplified)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emojis',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showEmojiPicker = false),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: popularEmojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _addEmoji(popularEmojis[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        popularEmojis[index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the _TikTokActionButton class as is...
class _TikTokActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isGift;
  final bool isActive;

  const _TikTokActionButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.isGift = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Gift button styling
    if (isGift) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF7A00).withOpacity(0.9),
                const Color(0xFFFFD700).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      );
    }

    // Active menu button
    if (isActive) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      );
    }

    // Default button
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.9), size: size),
      ),
    );
  }
}

// Optional: For a better emoji picker, use a package
// Add to pubspec.yaml: emoji_picker_flutter: ^3.0.0
// Then use this:

// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

// Widget _buildEmojiPickerPackage() {
//   return EmojiPicker(
//     onEmojiSelected: (Category? category, Emoji emoji) {
//       _addEmoji(emoji.emoji);
//     },
//     config: Config(
//       columns: 7,
//       emojiSizeMax: 32,
//       bgColor: Colors.black.withOpacity(0.95),
//       indicatorColor: const Color(0xFFFF7A00),
//       iconColor: Colors.white.withOpacity(0.7),
//       iconColorSelected: const Color(0xFFFF7A00),
//       progressIndicatorColor: const Color(0xFFFF7A00),
//       backspaceColor: Colors.white.withOpacity(0.7),
//       skinToneDialogBgColor: Colors.black,
//       skinToneIndicatorColor: Colors.white.withOpacity(0.7),
//       enableSkinTones: true,
//       showRecentsTab: true,
//       recentsLimit: 28,
//       noRecentsText: 'No Recents',
//       noRecentsStyle: TextStyle(
//         color: Colors.white.withOpacity(0.5),
//         fontSize: 14,
//       ),
//       tabIndicatorAnimDuration: const Duration(milliseconds: 300),
//       categoryIcons: const CategoryIcons(),
//       buttonMode: ButtonMode.MATERIAL,
//     ),
//   );
// }
