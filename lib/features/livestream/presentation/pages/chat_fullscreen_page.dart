// lib/features/livestream/presentation/pages/chat_fullscreen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubits/chat_cubit.dart';
import '../widgets/live_message_tile.dart';

class ChatFullscreenPage extends StatefulWidget {
  const ChatFullscreenPage({super.key, required this.livestreamUuid});
  final String livestreamUuid;

  @override
  State<ChatFullscreenPage> createState() => _ChatFullscreenPageState();
}

class _ChatFullscreenPageState extends State<ChatFullscreenPage> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ChatCubit is created with lsUuid at the route/provider level.
    // So just trigger load with no params.
    context.read<ChatCubit>().loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: BlocBuilder<ChatCubit, ChatState>(
          buildWhen: (p, c) => p.count != c.count,
          builder: (context, s) => Row(
            children: [
              const Text(
                'Live Chat',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              const Icon(Icons.forum_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                '${s.count}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                final items = state.messages;
                if (state.loading && items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemBuilder: (_, i) => LiveMessageTile(msg: items[i]),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: items.length,
                );
              },
            ),
          ),
          _InputBar(
            controller: _ctrl,
            onSend: (text) {
              final t = text.trim();
              if (t.isEmpty) return;
              context.read<ChatCubit>().send(t);
              _ctrl.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0B102A),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF101637),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => onSend(controller.text),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF5C7CF8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
