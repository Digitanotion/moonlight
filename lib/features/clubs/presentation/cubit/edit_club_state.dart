import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';

class EditClubState extends Equatable {
  final bool loading;
  final String? errorMessage;

  final String name;
  final String? description;
  final String? motto;
  final String? location;
  final bool isPrivate;

  final String? existingCoverUrl;
  final File? newCoverImage;

  final ClubProfile? updatedClub;

  const EditClubState({
    this.loading = false,
    this.errorMessage,
    this.name = '',
    this.description,
    this.motto,
    this.location,
    this.isPrivate = false,
    this.existingCoverUrl,
    this.newCoverImage,
    this.updatedClub,
  });

  EditClubState copyWith({
    bool? loading,
    String? errorMessage,
    String? name,
    String? description,
    String? motto,
    String? location,
    bool? isPrivate,
    String? existingCoverUrl,
    File? newCoverImage,
    ClubProfile? updatedClub,
  }) {
    return EditClubState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      name: name ?? this.name,
      description: description ?? this.description,
      motto: motto ?? this.motto,
      location: location ?? this.location,
      isPrivate: isPrivate ?? this.isPrivate,
      existingCoverUrl: existingCoverUrl ?? this.existingCoverUrl,

      // 🔥 CRITICAL FIX
      newCoverImage: newCoverImage ?? this.newCoverImage,

      updatedClub: updatedClub ?? this.updatedClub,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    errorMessage,
    name,
    description,
    motto,
    location,
    isPrivate,
    existingCoverUrl,
    newCoverImage,
    updatedClub,
  ];
}
