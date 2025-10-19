// User Helper Class
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/post_view/domain/entities/comment.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:provider/provider.dart';

class UserHelper {
  static User? getCurrentUser(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user;
    }
    return null;
  }

  static String? getCurrentUserId(BuildContext context) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    return currentUserService.getCurrentUserId();
  }

  static String getCurrentUserAvatar(BuildContext context) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    return currentUserService.getCurrentAvatar();
  }

  static bool isPostOwner(BuildContext context, Post post) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    return currentUserService.isPostOwner(post);
  }

  static bool isCommentOwner(BuildContext context, Comment comment) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    return currentUserService.isCommentOwner(comment);
  }

  static bool isLoggedIn(BuildContext context) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    return currentUserService.isLoggedIn;
  }
}
