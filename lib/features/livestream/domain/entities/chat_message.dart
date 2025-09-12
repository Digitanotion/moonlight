import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class ChatMessage extends Equatable {
  final String user;
  final String text;
  final String? trailing;
  final IconData? trailingIcon;

  const ChatMessage({
    required this.user,
    required this.text,
    this.trailing,
    this.trailingIcon,
  });

  @override
  List<Object?> get props => [user, text, trailing, trailingIcon];
}
