// lib/features/livestream/presentation/widgets/live_chat_dock.dart
import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';

class LiveChatDock extends StatelessWidget {
  final List<Message> messages;
  final ValueChanged<String> onSend;
  const LiveChatDock({super.key, required this.messages, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubbleList(messages),
            const SizedBox(height: 10),
            _input(onSend),
          ],
        ),
      ),
    );
  }

  static Widget _bubbleList(List<Message> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x88212B4F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items
            .take(4)
            .map(
              (m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: m.userDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: m.text,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static Widget _input(ValueChanged<String> onSend) {
    final c = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141A33),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: c,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Add a comment…',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (t) {
                if (t.trim().isNotEmpty) {
                  onSend(t.trim());
                  c.clear();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (c.text.trim().isNotEmpty) {
              onSend(c.text.trim());
              c.clear();
            }
          },
          icon: const Icon(Icons.send_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}
