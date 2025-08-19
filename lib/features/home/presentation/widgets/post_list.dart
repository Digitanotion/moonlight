// lib/features/home/presentation/widgets/post_list.dart
import 'package:flutter/material.dart';
import 'post_card.dart';

class PostList extends StatelessWidget {
  const PostList({super.key});

  @override
  Widget build(BuildContext context) {
    final items = _demoPosts;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final p = items[i];
        return PostCard(
          avatarUrl: p.avatar,
          handle: p.handle,
          badge: p.badge,
          timeAgo: p.timeAgo,
          imageUrl: p.image,
          caption: p.caption,
          likes: p.likes,
          comments: p.comments,
          views: p.views,
        );
      },
    );
  }
}

class _Post {
  final String avatar,
      handle,
      badge,
      timeAgo,
      image,
      caption,
      likes,
      comments,
      views;
  _Post({
    required this.avatar,
    required this.handle,
    required this.badge,
    required this.timeAgo,
    required this.image,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.views,
  });
}

final _demoPosts = <_Post>[
  _Post(
    avatar:
        'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?auto=compress&w=200',
    handle: '@emily_travels',
    badge: 'Ambassador 🥇',
    timeAgo: '3h ago',
    image:
        'https://images.pexels.com/photos/240040/pexels-photo-240040.jpeg?auto=compress&w=1200',
    caption:
        'Amazing sunset view from Tokyo Tower tonight!\nThe city never fails to amaze me ✨',
    likes: '2.4K',
    comments: '186',
    views: '8.2K',
  ),
  _Post(
    avatar:
        'https://images.pexels.com/photos/614810/pexels-photo-614810.jpeg?auto=compress&w=200',
    handle: '@emily_travels',
    badge: 'Superstar 🥇',
    timeAgo: '4h ago',
    image:
        'https://images.pexels.com/photos/841130/pexels-photo-841130.jpeg?auto=compress&w=1200',
    caption:
        'Morning workout complete! Remember, consistency is key to achieving your goals 💪',
    likes: '1.8K',
    comments: '94',
    views: '5.6K',
  ),
  _Post(
    avatar:
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress&w=200',
    handle: '@maya_designs',
    badge: 'Active member 🥇',
    timeAgo: '9h ago',
    image:
        'https://images.pexels.com/photos/196645/pexels-photo-196645.jpeg?auto=compress&w=1200',
    caption:
        'Working on a new brand identity project. Love how colors can tell a story 🧠',
    likes: '3.1K',
    comments: '267',
    views: '6.2K',
  ),
  _Post(
    avatar:
        'https://images.pexels.com/photos/3861964/pexels-photo-3861964.jpeg?auto=compress&w=200',
    handle: '@david_tech',
    badge: 'Nominal member ⌚',
    timeAgo: '1h ago',
    image:
        'https://images.pexels.com/photos/3861964/pexels-photo-3861964.jpeg?auto=compress&w=1200',
    caption:
        'Late night coding session. Building something amazing! The future is in our hands 🚀',
    likes: '1.5K',
    comments: '128',
    views: '4.7K',
  ),
];
