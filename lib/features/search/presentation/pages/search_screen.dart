import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/home/presentation/widgets/bottom_nav.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:moonlight/features/search/presentation/widgets/empty_search_state.dart';
import 'package:moonlight/features/search/presentation/widgets/popular_clubs_section.dart';
import 'package:moonlight/features/search/presentation/widgets/search_app_bar.dart';
import 'package:moonlight/features/search/presentation/widgets/suggested_users_section.dart';
import 'package:moonlight/features/search/presentation/widgets/trending_tags_section.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final SearchBloc _searchBloc;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchBloc = BlocProvider.of<SearchBloc>(context);
    _searchBloc.add(LoadTrendingContent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          // Handle state changes if needed
        },
        builder: (context, state) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.dark],
                begin: Alignment.topLeft,
                end: Alignment.topRight,
              ),
            ),

            child: Column(
              children: [
                SearchAppBar(
                  controller: _searchController,
                  onChanged: (query) {
                    _searchBloc.add(SearchQueryChanged(query));
                  },
                  onClear: () {
                    _searchController.clear();
                    _searchBloc.add(ClearSearch());
                  },
                ),
                Expanded(child: _buildContent(state)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: HomeBottomNav(
        currentIndex: 4, // Assuming search is at index 4
        onTap: (index) {
          // Handle navigation
        },
      ),
    );
  }

  Widget _buildContent(SearchState state) {
    if (state.query.isNotEmpty) {
      switch (state.status) {
        case SearchStatus.loading:
          return const Center(child: CircularProgressIndicator());
        case SearchStatus.empty:
          return EmptySearchState(query: state.query);
        case SearchStatus.success:
          return _buildSearchResults(state);
        case SearchStatus.failure:
          return Center(child: Text(state.errorMessage ?? 'Search failed'));
        case SearchStatus.initial:
        default:
          return _buildInitialContent(state);
      }
    } else {
      return _buildInitialContent(state);
    }
  }

  Widget _buildInitialContent(SearchState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.dark],
          begin: Alignment.topLeft,
          end: Alignment.topRight,
        ),
      ),

      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No title for trending tags in the screenshot
            TrendingTagsSection(tags: state.trendingTags),
            const SizedBox(height: 24),

            // Suggested Users with proper styling from screenshot
            Text(
              'Suggested Users',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            ...state.suggestedUsers
                .map((user) => _buildUserTile(user))
                .toList(),
            const SizedBox(height: 24),

            // Clubs to Explore with proper styling
            Text(
              'Clubs to Explore',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            ...state.popularClubs.map((club) => _buildClubTile(club)).toList(),
            const SizedBox(height: 32),

            // Discover text at the bottom
            const Center(
              child: Text(
                'Discover Amazing Content\nStart searching to find creators, clubs and trending contents',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(UserResult user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.dark.withOpacity(0.3),
            child: const Icon(Icons.person, color: AppColors.textWhite),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Follow',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubTile(ClubResult club) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.groups, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${club.membersCount.formatCount()} members',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        return ListTile(
          title: Text(
            result.name,
            style: const TextStyle(color: AppColors.textWhite),
          ),
        );
      },
    );
  }
}
