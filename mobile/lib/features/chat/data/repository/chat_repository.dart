import '../../domain/models/chat_model.dart';
import '../api/message_api.dart';

class ChatRepository {
  final MessageApi api = MessageApi();

  Future<List<ChatModel>> getChats() async {
    final data = await api.getChats();

    return data
        .map<ChatModel>(
          (e) => ChatModel.fromJson(e),
        )
        .toList();
  }
}