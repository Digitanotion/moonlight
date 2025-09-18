import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/countries.dart';
import 'package:moonlight/features/home/presentation/widgets/country_picker_sheet.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_feed/live_feed_event.dart';
import '../bloc/live_feed/live_feed_state.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool trailingFilter;
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailingFilter)
            BlocBuilder<LiveFeedBloc, LiveFeedState>(
              buildWhen: (p, n) => p.selectedCountryIso != n.selectedCountryIso,
              builder: (context, state) {
                final iso = state.selectedCountryIso; // null => All Countries
                final label = countryDisplayName(iso);
                final flag = isoToFlagEmoji(iso ?? '');

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final selected = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: const Color(0xFF161616),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => const CountryPickerSheet(),
                    );
                    if (selected == null) return; // dismissed
                    final isoOrNull = selected == '__ALL__' ? null : selected;
                    context.read<LiveFeedBloc>().add(
                      LiveFeedCountryChanged(isoOrNull),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
