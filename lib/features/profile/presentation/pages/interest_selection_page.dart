import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/primary_button.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/secondary_button.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_bloc.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_event.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_state.dart';
import 'package:moonlight/features/profile/presentation/widgets/interest_tile.dart';

class InterestSelectionPage extends StatelessWidget {
  const InterestSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.topRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: BlocConsumer<InterestBloc, InterestState>(
              listener: (context, state) {
                if (state.saved) {
                  Navigator.pushReplacementNamed(context, RouteNames.home);
                }
              },
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'What are you interested in?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We’ll tailor your experience based on what you choose.",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (state.loading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    else if (state.error != null)
                      Expanded(
                        child: Center(
                          child: Text(
                            state.error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textWhite),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: state.interests.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: .95,
                              ),
                          itemBuilder: (context, index) {
                            final item = state.interests[index];
                            final selected = state.selectedIds.contains(
                              item.id,
                            );
                            return InterestTile(
                              interest: item,
                              selected: selected,
                              onTap: () => context.read<InterestBloc>().add(
                                ToggleInterest(item.id),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${state.selectedIds.length} of ${state.interests.length} selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SecondaryButton(
                      text: 'Continue',
                      onPressed: state.selectedIds.isEmpty || state.loading
                          ? () {}
                          : () => context.read<InterestBloc>().add(
                              const SubmitInterests(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: state.loading
                            ? null
                            : () => Navigator.pushReplacementNamed(
                                context,
                                RouteNames.home,
                              ),
                        child: Text(
                          'Skip for now',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textWhite),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
