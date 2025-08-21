import 'package:equatable/equatable.dart';

class Interest extends Equatable {
  final String id;
  final String title;
  final String emoji;

  const Interest({required this.id, required this.title, required this.emoji});

  Interest copyWith({String? id, String? title, String? emoji}) {
    return Interest(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
    );
  }

  @override
  List<Object?> get props => [id, title, emoji];
}
