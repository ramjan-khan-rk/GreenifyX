import '../../../../core/services/api_service.dart';

class SearchUserApi {
  Future<List<dynamic>> searchUsers(String keyword) async {
  final response = await ApiService.dio.get(
    "/users/search",
    queryParameters: {
      "q": keyword,
    },
  );

  return response.data["users"];
}
}