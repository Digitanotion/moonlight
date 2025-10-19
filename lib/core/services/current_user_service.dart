// lib/core/services/current_user_service.dart
import 'package:flutter/material.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/post_view/domain/entities/comment.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class CurrentUserService with ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  String getCurrentAvatar() {
    return _currentUser?.avatarUrl ?? 'https://i.pravatar.cc/150?img=5';
  }

  String? getCurrentUserId() {
    return _currentUser?.id;
  }

  bool isPostOwner(Post post) {
    return _currentUser != null && _currentUser!.id == post.author.id;
  }

  bool isCommentOwner(Comment comment) {
    return _currentUser != null && _currentUser!.id == comment.user.id;
  }
}
