import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/fetch_my_profile.dart';

part 'profile_page_state.dart';

enum ProfileTab { posts, clubs, livestreams }

class ProfilePageCubit extends Cubit<ProfilePageState> {
  final FetchMyProfile fetchMyProfile;

  ProfilePageCubit({required this.fetchMyProfile})
    : super(ProfilePageState.initial());

  Future<void> load({bool haptic = false}) async {
    if (haptic) HapticFeedback.selectionClick();
    emit(state.copyWith(loading: true, error: null));
    try {
      final user = await fetchMyProfile(); // GET /v1/me (and caches)
      // Mock data (replace later with real endpoints)
      emit(
        state.copyWith(
          loading: false,
          user: user,
          posts: state.posts.isEmpty
              ? List.generate(8, (i) => 'https://picsum.photos/seed/p_$i/400')
              : state.posts,
          clubs: state.clubs.isEmpty
              ? [
                  ClubItem('Photography Masters', 'President'),
                  ClubItem('Travel Snappers', 'Member'),
                  ClubItem('Portrait Pro Network', 'Member'),
                ]
              : state.clubs,
          replays: state.replays.isEmpty
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
              : state.replays,
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
