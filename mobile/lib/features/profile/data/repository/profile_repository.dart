import '../../domain/models/profile_model.dart';
import '../api/profile_api.dart';

class ProfileRepository {

  final ProfileApi _api = ProfileApi();

  Future<ProfileModel> getProfile() async {

    final json =
        await _api.getProfile();

    return ProfileModel.fromJson(json);

  }

  Future<void> updateProfile({

    required String name,
    required String bio,
    required String profileImage,

  }){

    return _api.updateProfile(

      name:name,
      bio:bio,
      profileImage:profileImage,

    );

  }

}