// -----------------------------
// FILE: lib/features/live/ui/widgets/chat_list.dart
// -----------------------------
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class ChatList extends StatelessWidget {
  const ChatList({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in state.messages.take(4)) ...[
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12),
                    children: [
                      TextSpan(
                        text: m.user,
                        style: const TextStyle(color: Color(0xFF7DD3FC)),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: m.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }
}
