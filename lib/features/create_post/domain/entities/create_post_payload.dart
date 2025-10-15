class CreatePostPayload {
  final String caption;
  final List<String> tags;
  final PostVisibility visibility; // everyone / followers / onlyMe
  final String mediaPath; // local file path (image/video)

  CreatePostPayload({
    required this.caption,
    required this.tags,
    required this.visibility,
    required this.mediaPath,
  });
}

enum PostVisibility { everyone, followers, onlyMe }

extension PostVisibilityApi on PostVisibility {
  String get apiValue {
    switch (this) {
      case PostVisibility.everyone:
        return 'everyone';
      case PostVisibility.followers:
        return 'followers';
      case PostVisibility.onlyMe:
        return 'only_me';
    }
  }
}
