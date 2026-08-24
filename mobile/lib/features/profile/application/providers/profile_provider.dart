import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/api/upload_api.dart';
import '../../data/repository/profile_repository.dart';
import '../../../../core/services/storage_service.dart';


final profileRepositoryProvider = Provider((ref) {
  return ProfileRepository();
});

final uploadApiProvider = Provider((ref) {
  return UploadApi();
});

class ProfileState {
  final bool isLoading;

  final File? imageFile;

  final String profileImage;

  final String name;

  final String bio;

  final int ecoScore;

  final int karamCount;

  final int streak;

  final int level;

  final int friendsCount;

  final String? error;

  const ProfileState({
    this.isLoading = false,
    this.imageFile,
    this.profileImage = "",
    this.name = "",
    this.bio = "",
    this.ecoScore = 0,
    this.karamCount = 0,
    this.streak = 0,
    this.level = 1,
    this.friendsCount = 0,
    this.error,
  });

  ProfileState copyWith({
    bool? isLoading,
    File? imageFile,
    String? profileImage,
    String? name,
    String? bio,
    int? ecoScore,
    int? karamCount,
    int? streak,
    int? level,
    int? friendsCount,
    String? error,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      imageFile: imageFile ?? this.imageFile,
      profileImage: profileImage ?? this.profileImage,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      ecoScore: ecoScore ?? this.ecoScore,
      karamCount: karamCount ?? this.karamCount,
      streak: streak ?? this.streak,
      level: level ?? this.level,
      friendsCount: friendsCount ?? this.friendsCount,
      error: error,
    );
  }
}


class ProfileNotifier extends Notifier<ProfileState> {
  late ProfileRepository repository;
  late UploadApi uploadApi;

  @override
  ProfileState build() {
    repository = ref.read(profileRepositoryProvider);
    uploadApi = ref.read(uploadApiProvider);

    return const ProfileState();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    state = state.copyWith(
      imageFile: File(image.path),
    );
  }

  Future<void> uploadImage() async {
    if (state.imageFile == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final url = await uploadApi.uploadImage(
        state.imageFile!,
      );

      state = state.copyWith(
        profileImage: url,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> saveProfile({
    required String name,
    required String bio,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await repository.updateProfile(
        name: name,
        bio: bio,
        profileImage: state.profileImage,
      );

      state = state.copyWith(isLoading: false);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      await loadProfile();

      return false;
    }
  }



Future<void> loadProfile() async {

  state = state.copyWith(
    isLoading: true,
  );

  try {

    final profile =
        await repository.getProfile();

    state = state.copyWith(

      isLoading: false,

      name: profile.name,

      bio: profile.bio,

      profileImage: profile.profileImage,

      ecoScore: profile.ecoScore,

      karamCount: profile.karamCount,

      streak: profile.streak,

      level: profile.level,

      friendsCount: profile.friendsCount,

    );

  } catch (e) {

    state = state.copyWith(

      isLoading: false,

      error: e.toString(),

    );

  }

}
Future<void> logout() async {

  await StorageService.clear();

}
}
final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(
  () => ProfileNotifier(),
);