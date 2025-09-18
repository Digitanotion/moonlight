import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_state.dart';
import 'package:moonlight/features/home/presentation/widgets/country_picker_sheet.dart';
import 'package:moonlight/features/home/presentation/widgets/live_tile_grid.dart';
import 'package:moonlight/features/home/presentation/widgets/shimmer.dart';
import 'package:moonlight/widgets/states.dart';
import 'package:moonlight/features/home/presentation/widgets/section_header.dart';

class LiveNowSection extends StatefulWidget {
  const LiveNowSection({super.key});
  @override
  State<LiveNowSection> createState() => _LiveNowSectionState();
}

class _LiveNowSectionState extends State<LiveNowSection> {
  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // AUTOLOAD: All countries (countryIso = null)
    context.read<LiveFeedBloc>().add(LiveFeedStarted(order: 'trending'));
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    final bloc = context.read<LiveFeedBloc>();
    if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 300) {
      bloc.add(LiveFeedLoadMore());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<LiveFeedBloc>().add(LiveFeedRefresh());
  }

  int _calcColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BlocBuilder<LiveFeedBloc, LiveFeedState>(
        builder: (context, state) {
          if (state.status == LiveFeedStatus.loading && state.items.isEmpty) {
            return const _ShimmerGrid();
          }
          // Replace your failure block with:
          if (state.status == LiveFeedStatus.failure && state.items.isEmpty) {
            return NetworkErrorState(
              onRetry: () =>
                  context.read<LiveFeedBloc>().add(LiveFeedRefresh()),
              onChangeCountry: () async {
                // Reuse the same country sheet UX your SectionHeader uses:
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: const Color(0xFF161616),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (_) =>
                      const CountryPickerSheet(), // this is defined in section_header.dart
                );
                if (selected == null) return; // dismissed
                final isoOrNull = selected == '__ALL__' ? null : selected;
                context.read<LiveFeedBloc>().add(
                  LiveFeedCountryChanged(isoOrNull),
                );
              },
              message: 'No connection. Check your network and try again.',
            );
          }

          // Replace your empty block with:
          if (state.status == LiveFeedStatus.empty) {
            return EmptyLiveState(
              onChangeCountry: () async {
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
                if (selected == null) return;
                final isoOrNull = selected == '__ALL__' ? null : selected;
                context.read<LiveFeedBloc>().add(
                  LiveFeedCountryChanged(isoOrNull),
                );
              },
              onGoLive: () => Navigator.pushNamed(context, '/go-live'),
              onRefresh: () =>
                  context.read<LiveFeedBloc>().add(LiveFeedRefresh()),
            );
          }

          final items = state.items;

          return LayoutBuilder(
            builder: (_, box) {
              final cols = _calcColumns(box.maxWidth);
              final ratio = 9 / 14;
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: GridView.builder(
                  controller: _ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: ratio,
                  ),
                  itemCount: items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= items.length) {
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final it = items[i];
                    return LiveTileGrid(item: it);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        int cols = 2;
        if (box.maxWidth >= 1100)
          cols = 4;
        else if (box.maxWidth >= 800)
          cols = 3;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 9 / 14,
          ),
          itemCount: cols * 3,
          itemBuilder: (_, __) => Shimmer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}
