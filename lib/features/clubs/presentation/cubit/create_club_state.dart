import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';

class CreateClubState extends Equatable {
  final bool loading;
  final String? errorMessage;
  final ClubProfile? createdClub;

  final String name;
  final String? description;
  final String? motto;
  final String? location;
  final bool isPrivate;
  final File? coverImageFile;

  const CreateClubState({
    this.loading = false,
    this.errorMessage,
    this.createdClub,
    this.name = '',
    this.description,
    this.motto,
    this.location,
    this.isPrivate = false,
    this.coverImageFile,
  });

  CreateClubState copyWith({
    bool? loading,
    String? errorMessage,
    ClubProfile? createdClub,
    String? name,
    String? description,
    String? motto,
    String? location,
    bool? isPrivate,
    File? coverImageFile,
  }) {
    return CreateClubState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      createdClub: createdClub,
      name: name ?? this.name,
      description: description ?? this.description,
      motto: motto ?? this.motto,
      location: location ?? this.location,
      isPrivate: isPrivate ?? this.isPrivate,
      coverImageFile: coverImageFile ?? this.coverImageFile,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    errorMessage,
    createdClub,
    name,
    description,
    motto,
    location,
    isPrivate,
    coverImageFile,
  ];
}
