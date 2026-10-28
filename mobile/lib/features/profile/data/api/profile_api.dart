import '../../../../core/services/api_service.dart';

class ProfileApi {

  Future<Map<String,dynamic>> getProfile() async {

    final response =
        await ApiService.dio.get("/users/me");

    return response.data["user"];

  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final response = await ApiService.dio.get("/users/leaderboard");
    final users = response.data["users"];
    if (users is! List) return [];
    return users
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> updateProfile({

    required String name,
    required String bio,
    required String profileImage,

  }) async {

    await ApiService.dio.put(

      "/users/profile",

      data:{

        "name":name,
        "bio":bio,
        "profileImage":profileImage,

      },

    );

  }

}