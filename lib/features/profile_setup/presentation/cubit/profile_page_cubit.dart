import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/fetch_my_profile.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

part 'profile_page_state.dart';

// Simple typedef for injecting a function that returns posts for a user.
// Keep it optional so existing DI doesn't break.
typedef FetchMyPosts =
    Future<List<Post>> Function({
      required String userUuid,
      int page,
      int perPage,
    });

enum ProfileTab { posts, clubs, livestreams }

class ProfilePageCubit extends Cubit<ProfilePageState> {
  final FetchMyProfile fetchMyProfile;
  final FetchMyPosts? fetchMyPosts; // optional - keep backward compat

  ProfilePageCubit({required this.fetchMyProfile, this.fetchMyPosts})
    : super(ProfilePageState.initial());

  Future<void> load({bool haptic = false}) async {
    if (haptic) HapticFeedback.selectionClick();
    emit(state.copyWith(loading: true, error: null));
    try {
      final user = await fetchMyProfile(); // GET /v1/me (and caches)
      List<Post> posts = [];

      // If a posts provider is injected, use it to fetch posts for the current user.
      if (fetchMyPosts != null) {
        try {
          // Use 'uuid' field — change to 'id' if your UserModel exposes a different property.
          final userUuid = (user.uuid ?? user.userId ?? '').toString();
          if (userUuid.isNotEmpty) {
            posts = await fetchMyPosts!(
              userUuid: userUuid,
              page: 1,
              perPage: 50,
            );
          }
        } catch (e) {
          // on failure keep posts empty to fall back to placeholders
        }
      }

      // If we still don't have posts, fall back to legacy placeholders (as Post objects)
      if (posts.isEmpty) {
        posts = List.generate(8, (i) {
          return Post(
            id: 'placeholder_$i',
            author: AppUser(
              id: '0',
              name: 'You',
              avatarUrl: '',
              countryFlagEmoji: '',
              roleLabel: '',
              roleColor: '',
            ),
            mediaUrl: 'https://picsum.photos/seed/p_$i/400',
            caption: '',
            tags: const [],
            createdAt: DateTime.now(),
          );
        });
      }

      // existing fallback clubs/replays (unchanged)
      final clubs = state.clubs.isEmpty
          ? [
              ClubItem('Photography Masters', 'President'),
              ClubItem('Travel Snappers', 'Member'),
              ClubItem('Portrait Pro Network', 'Member'),
            ]
          : state.clubs;

      final replays = state.replays.isEmpty
          ? [
              ReplayItem(
                title: 'Photography Basics Workshop',
                viewsLabel: '5.6k views',
                whenLabel: '2d ago',
                durationLabel: '45:32',
                thumbnailUrl:
                    'https://images.pexels.com/photos/274973/pexels-photo-274973.jpeg',
              ),
              ReplayItem(
                title: 'Photo Editing Tips & Tricks',
                viewsLabel: '5.6k views',
                whenLabel: '1wk ago',
                durationLabel: '45:32',
                thumbnailUrl:
                    'https://images.pexels.com/photos/66134/pexels-photo-66134.jpeg',
              ),
            ]
          : state.replays;

      // IMPORTANT: emit the typed List<Post> directly (no casting to List<String>)
      emit(
        state.copyWith(
          loading: false,
          user: user,
          posts: posts, // << keep as List<Post>
          clubs: clubs,
          replays: replays,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void switchTab(ProfileTab tab) => emit(state.copyWith(tab: tab));
}

class ClubItem {
  final String name;
  final String role; // President / Member
  ClubItem(this.name, this.role);
}

class ReplayItem {
  final String title;
  final String viewsLabel;
  final String whenLabel;
  final String durationLabel;
  final String thumbnailUrl;
  ReplayItem({
    required this.title,
    required this.viewsLabel,
    required this.whenLabel,
    required this.durationLabel,
    required this.thumbnailUrl,
  });
}
