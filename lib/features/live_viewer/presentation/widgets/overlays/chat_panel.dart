// lib/features/live_viewer/presentation/widgets/overlays/chat_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _scrollController = ScrollController();
  bool _isAtTop = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final isAtTop = _scrollController.position.pixels == 0;
    if (isAtTop != _isAtTop) {
      setState(() {
        _isAtTop = isAtTop;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.chat != n.chat,
      builder: (_, s) {
        final chat = s.chat.reversed.toList();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
          child: Container(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _scrollController,
                    reverse: true,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: chat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = chat[i];
                      return _ModernChatBubble(
                        username: m.username,
                        text: m.text,
                        isNew: i == 0,
                      );
                    },
                  ),
                  if (!_isAtTop)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModernChatBubble extends StatelessWidget {
  final String username;
  final String text;
  final bool isHost;
  final bool isNew;

  const _ModernChatBubble({
    required this.username,
    required this.text,
    this.isHost = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(left: isNew ? 0 : 0, right: 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isHost
              ? const Color(0xFFFF7A00).withOpacity(0.25)
              : Colors.black.withOpacity(0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10, top: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHost
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF29C3FF),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: isHost
                                ? const Color(0xFFFF7A00)
                                : const Color(0xFF29C3FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A00).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFF7A00).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNew)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 0, top: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF7A00),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
