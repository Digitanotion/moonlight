import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/home/presentation/widgets/bottom_nav.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:moonlight/features/search/presentation/widgets/empty_search_state.dart';
import 'package:moonlight/features/search/presentation/widgets/popular_clubs_section.dart';
import 'package:moonlight/features/search/presentation/widgets/search_app_bar.dart';
import 'package:moonlight/features/search/presentation/widgets/search_skeletons.dart';
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

  Widget suggestedUserSkeleton() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        shimmerBox(w: 48, h: 48, r: BorderRadius.circular(24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shimmerBox(w: 120, h: 14),
              const SizedBox(height: 6),
              shimmerBox(w: 80, h: 12),
            ],
          ),
        ),
        shimmerBox(w: 60, h: 28, r: BorderRadius.circular(16)),
      ],
    ),
  );

  Widget clubSkeleton() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        shimmerBox(w: 40, h: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shimmerBox(w: 140, h: 14),
              const SizedBox(height: 6),
              shimmerBox(w: 90, h: 12),
            ],
          ),
        ),
        shimmerBox(w: 50, h: 28, r: BorderRadius.circular(16)),
      ],
    ),
  );

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
            TrendingTagsSection(
              tags: state.trendingTags,
              isLoading: state.isLoadingTrending,
            ),

            const SizedBox(height: 24),

            // Suggested Users with proper styling from screenshot
            Text(
              'Suggested Users',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoadingUsers)
              ...List.generate(3, (_) => suggestedUserSkeleton())
            else
              ...state.suggestedUsers.map(_buildUserTile),
            const SizedBox(height: 24),

            // Clubs to Explore with proper styling
            Text(
              'Clubs to Explore',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoadingClubs)
              ...List.generate(2, (_) => clubSkeleton())
            else
              ...state.popularClubs.map(_buildClubTile),

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
    return InkWell(
      onTap: () => _openUserProfile(user),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(user),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.dark.withOpacity(0.3),
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.textWhite)
                    : null,
              ),
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
      ),
    );
  }

  void _openUserProfile(UserResult user) {
    if (user.id.isEmpty) return;

    Navigator.pushNamed(
      context,
      RouteNames.profileView,
      arguments: {
        'userUuid': user.id,
        'user_slug': user.username, // optional, router ignores it safely
      },
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final result = state.results[index];

        if (result is UserResult) {
          return _buildSearchUserResult(result);
        }

        if (result is ClubResult) {
          return _buildSearchClubResult(result);
        }

        if (result is TagResult) {
          return _buildSearchTagResult(result);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchUserResult(UserResult user) {
    return InkWell(
      onTap: () => _openUserProfile(user),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _UserAvatar(url: user.avatarUrl),
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
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchClubResult(ClubResult club) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              club.name,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTagResult(TagResult tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#${tag.name}',
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? url;
  const _UserAvatar({this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.dark.withOpacity(0.3),
      backgroundImage: url != null && url!.isNotEmpty
          ? NetworkImage(url!)
          : null,
      onBackgroundImageError: (_, __) {},
      child: url == null || url!.isEmpty
          ? const Icon(Icons.person, color: AppColors.textWhite)
          : null,
    );
  }
}
