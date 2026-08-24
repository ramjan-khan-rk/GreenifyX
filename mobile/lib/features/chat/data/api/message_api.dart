import '../../../../core/services/api_service.dart';

class MessageApi {
  Future<List<dynamic>> getMessages(String userId) async {
    final response = await ApiService.dio.get(
      "/messages/$userId",
    );

    return response.data["messages"];
  }

  Future<List<dynamic>> getChats() async {
    final response = await ApiService.dio.get(
      "/messages",
    );

    return response.data["chats"];
  }

  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    await ApiService.dio.post(
      "/messages",
      data: {
        "receiverId": receiverId,
        "text": text,
      },
    );
  }
}