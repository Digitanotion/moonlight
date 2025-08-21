import '../../domain/entities/interest.dart';

class InterestModel extends Interest {
  const InterestModel({
    required super.id,
    required super.title,
    required super.emoji,
  });

  factory InterestModel.fromJson(Map<String, dynamic> json) {
    return InterestModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      emoji: json['emoji'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'emoji': emoji};
}
