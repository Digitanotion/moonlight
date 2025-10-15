import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:moonlight/core/services/local_cache.dart';
import 'package:moonlight/features/post_view/domain/entities/comment.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';

class PostLocalDataSource {
  final LocalCache cache;
  PostLocalDataSource(this.cache);

  // seed dummy content; persist to SharedPreferences to mimic TikTok-like quick loads
  Future<void> seedIfEmpty() async {
    final map = await cache.read();
    if (map['seeded'] == true) return;

    final user = AppUser(
      id: 1,
      name: 'Alex Kim',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      countryFlagEmoji: '🇺🇸',
      roleLabel: 'Nominal member',
      roleColor: '#4C8DFF',
    );
    final post = {
      'id': 'post_1',
      'author': {
        'id': user.id,
        'name': user.name,
        'avatar': user.avatarUrl,
        'flag': user.countryFlagEmoji,
        'role': user.roleLabel,
        'roleColor': user.roleColor,
      },
      'mediaUrl':
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=1600&auto=format&fit=crop',
      'caption':
          'Caught this amazing sunset during my weekend hiking trip! The colors were absolutely breathtaking...',
      'tags': ['Nature', 'Sunset', 'Hiking', 'Photography'],
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch,
      'likes': 1200,
      'comments': 5800,
      'shares': 24,
      'isLiked': false,
    };
    final comments = List.generate(
      4,
      (i) => {
        'id': 'c$i',
        'user': {
          'id': i + 2,
          'name': [
            'Marcus Chen',
            'Sarah Jensen',
            'Emma Lens',
            'Marcus Chen',
          ][i],
          'avatar': 'https://i.pravatar.cc/150?img=${i + 20}',
          'flag': '🇺🇸',
          'role': ['Nominal member', 'Active member', 'VIP', 'Superstar'][i],
          'roleColor': ['#4C8DFF', '#ADB5BD', '#9B5CFF', '#31D873'][i],
        },
        'text': i == 2
            ? 'This makes me want to go hiking right now! Amazing composition'
            : 'Absolutely stunning! The reflection on the water is perfect 🔥',
        'createdAt': DateTime.now()
            .subtract(Duration(hours: i + 1))
            .millisecondsSinceEpoch,
        'likes': Random().nextInt(40) + 1,
        'replies': [],
      },
    );

    await cache.write({'seeded': true, 'post': post, 'comments': comments});
  }

  Future<Post> getPost() async {
    await seedIfEmpty();
    final map = await cache.read();
    final p = map['post'] as Map<String, dynamic>;
    final authorMap = p['author'] as Map<String, dynamic>;
    final author = AppUser(
      id: authorMap['id'] as int,
      name: authorMap['name'] as String,
      avatarUrl: authorMap['avatar'] as String,
      countryFlagEmoji: authorMap['flag'] as String,
      roleLabel: authorMap['role'] as String,
      roleColor: authorMap['roleColor'] as String,
    );
    return Post(
      id: p['id'],
      author: author,
      mediaUrl: p['mediaUrl'],
      caption: p['caption'],
      tags: (p['tags'] as List).cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(p['createdAt'] as int),
      likes: p['likes'] as int,
      commentsCount: p['comments'] as int,
      shares: p['shares'] as int,
      isLiked: p['isLiked'] as bool,
    );
  }

  Future<void> savePost(Post post) async {
    final map = await cache.read();
    final author = post.author;
    map['post'] = {
      'id': post.id,
      'author': {
        'id': author.id,
        'name': author.name,
        'avatar': author.avatarUrl,
        'flag': author.countryFlagEmoji,
        'role': author.roleLabel,
        'roleColor': author.roleColor,
      },
      'mediaUrl': post.mediaUrl,
      'caption': post.caption,
      'tags': post.tags,
      'createdAt': post.createdAt.millisecondsSinceEpoch,
      'likes': post.likes,
      'comments': post.commentsCount,
      'shares': post.shares,
      'isLiked': post.isLiked,
    };
    await cache.write(map);
  }

  Future<List<Comment>> getComments() async {
    await seedIfEmpty();
    final map = await cache.read();
    final list = (map['comments'] as List).cast<Map<String, dynamic>>();
    return list.map(_commentFromJson).toList();
  }

  Future<void> saveComments(List<Comment> comments) async {
    final map = await cache.read();
    map['comments'] = comments.map(_commentToJson).toList();
    await cache.write(map);
  }

  Comment _fromChild(Map<String, dynamic> m) => _commentFromJson(m);

  Comment _commentFromJson(Map<String, dynamic> m) {
    final u = m['user'] as Map<String, dynamic>;
    final user = AppUser(
      id: u['id'],
      name: u['name'],
      avatarUrl: u['avatar'],
      countryFlagEmoji: u['flag'],
      roleLabel: u['role'],
      roleColor: u['roleColor'],
    );
    return Comment(
      id: m['id'],
      user: user,
      text: m['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt']),
      likes: m['likes'] as int,
      replies: (m['replies'] as List)
          .cast<Map<String, dynamic>>()
          .map(_fromChild)
          .toList(),
    );
  }

  Map<String, dynamic> _commentToJson(Comment c) => {
    'id': c.id,
    'user': {
      'id': c.user.id,
      'name': c.user.name,
      'avatar': c.user.avatarUrl,
      'flag': c.user.countryFlagEmoji,
      'role': c.user.roleLabel,
      'roleColor': c.user.roleColor,
    },
    'text': c.text,
    'createdAt': c.createdAt.millisecondsSinceEpoch,
    'likes': c.likes,
    'replies': c.replies.map(_commentToJson).toList(),
  };

  Future<Comment> addReply(String commentId, String text) async {
    final list = await getComments();
    final you = const AppUser(
      id: 999,
      name: 'You',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      countryFlagEmoji: '🇳🇬',
      roleLabel: 'Active member',
      roleColor: '#ADB5BD',
    );
    final reply = Comment(
      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
      user: you,
      text: text,
      createdAt: DateTime.now(),
      likes: 0,
    );

    for (var i = 0; i < list.length; i++) {
      if (list[i].id == commentId) {
        final updated = list[i].copyWith(replies: [reply, ...list[i].replies]);
        list[i] = updated;
        await saveComments(list);
        return reply;
      }
    }
    throw Exception('Comment not found');
  }
}
