import '../../../../core/services/api_service.dart';

class FriendApi {

  Future<void> sendRequest(String userId) async {
    await ApiService.dio.post(
      "/friends/send",
      data: {
        "userId": userId,
      },
    );
  }

  Future<void> acceptRequest(String userId) async {
    await ApiService.dio.post(
      "/friends/accept",
      data: {
        "userId": userId,
      },
    );
  }

  Future<List<dynamic>> getFriends() async {
    final response = await ApiService.dio.get(
      "/friends",
    );

    return response.data["friends"];
  }

  Future<List<dynamic>> getRequests() async {
    final response = await ApiService.dio.get(
      "/friends/requests",
    );

    return response.data["requests"];
  }
}