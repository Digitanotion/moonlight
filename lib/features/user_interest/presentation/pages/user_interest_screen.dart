import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/widgets/moon_snack.dart';
import '../cubit/user_interest_cubit.dart';

class UserInterestScreen extends StatelessWidget {
  const UserInterestScreen({super.key});

  static final _all = <_Interest>[
    _Interest('making_friends', 'Making Friends', '💬'),
    _Interest('watching_live_videos', 'Watching Live\nVideos', '📹'),
    _Interest('going_live', 'Going Live', '🎥'),
    _Interest('learning_new_skills', 'Learning New\nSkills', '🧠'),
    _Interest('gaming', 'Gaming', '🎮'),
    _Interest('creativity_art', 'Creativity & Art', '🎨'),
    _Interest('entertainment', 'Entertainment', '🕺'),
    _Interest('competitions_challenges', 'Competitions &\nChallenges', '🏆'),
    _Interest('lifestyle_wellness', 'Lifestyle &\nWellness', '🧘'),
  ];

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final gradient = const LinearGradient(
      colors: [Color(0xFF0C0F52), Color(0xFF0A0A0F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return BlocConsumer<UserInterestCubit, UserInterestState>(
      listener: (context, state) async {
        if (state.success) {
          // mark completed once
          // ignore: use_build_context_synchronously
          MoonSnack.success(context, "Great Job! We have noted your interests");
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        } else if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final selected = state.selected.toSet();
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      'What are you interested in?',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We’ll tailor your experience based on what you choose.",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),

                    Expanded(
                      child: GridView.builder(
                        itemCount: _all.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.35,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                            ),
                        itemBuilder: (context, i) {
                          final it = _all[i];
                          final isSel = selected.contains(it.key);
                          return _InterestCard(
                            title: it.label,
                            emoji: it.emoji,
                            selected: isSel,
                            onTap: () => context
                                .read<UserInterestCubit>()
                                .toggle(it.key),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${selected.length} of ${_all.length} selected',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.submitting
                            ? null
                            : () => context.read<UserInterestCubit>().submit(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          disabledBackgroundColor: orange.withOpacity(0.5),
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: state.submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (_) => false,
                        ),
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(color: Color(0xFF19D85E)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Interest {
  final String key;
  final String label;
  final String emoji;
  const _Interest(this.key, this.label, this.emoji);
}

class _InterestCard extends StatelessWidget {
  final String emoji;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _InterestCard({
    required this.emoji,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? const Color(0xFFFF7A00) : const Color(0x29FFFFFF);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
