import 'package:equatable/equatable.dart';

class SuggestedClub extends Equatable {
  final String uuid;
  final String slug;
  final String name;
  final String? description;
  final int membersCount;
  final String? coverImageUrl;
  final double score;
  final String reason;

  const SuggestedClub({
    required this.uuid,
    required this.slug,
    required this.name,
    this.description,
    required this.membersCount,
    this.coverImageUrl,
    required this.score,
    required this.reason,
  });

  factory SuggestedClub.fromJson(Map<String, dynamic> json) {
    return SuggestedClub(
      uuid: json['uuid'],
      slug: json['slug'],
      name: json['name'],
      description: json['description'],
      membersCount: json['membersCount'] ?? 0,
      coverImageUrl: json['coverImageUrl'],
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    slug,
    name,
    membersCount,
    coverImageUrl,
    score,
    reason,
  ];
}
