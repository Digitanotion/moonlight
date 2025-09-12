// -----------------------------
// FILE: lib/features/live/ui/widgets/comment_input.dart
// -----------------------------
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';

class CommentInput extends StatefulWidget {
  const CommentInput({super.key});
  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(.35),
            shape: const CircleBorder(),
          ),
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isNotEmpty) context.read<ChatCubit>().send(text);
            _ctrl.clear();
          },
          icon: const Icon(Icons.send, color: Colors.white),
        ),
      ],
    );
  }
}
