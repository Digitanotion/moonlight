// User Helper Class
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/post_view/domain/entities/comment.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class UserHelper {
  static User? getCurrentUser(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user;
    }
    return null;
  }

  static String? getCurrentUserId(BuildContext context) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.getCurrentUserId();
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  static String getCurrentUserAvatar(BuildContext context) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.getCurrentAvatar();
    } catch (e) {
      debugPrint('Error getting current user avatar: $e');
      return '';
    }
  }

  static bool isPostOwner(BuildContext context, Post post) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.isPostOwner(post);
    } catch (e) {
      debugPrint('Error checking post ownership: $e');
      return false;
    }
  }

  static bool isCommentOwner(BuildContext context, Comment comment) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.isCommentOwner(comment);
    } catch (e) {
      debugPrint('Error checking comment ownership: $e');
      return false;
    }
  }

  static bool isLoggedIn(BuildContext context) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.isLoggedIn;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }
}
