import '../../domain/models/message_model.dart';
import '../api/message_api.dart';

class MessageRepository {
  final MessageApi api = MessageApi();

  Future<List<ChatMessageModel>> getMessages(
      String userId) async {
    final data = await api.getMessages(userId);

    return data
        .map<ChatMessageModel>(
          (e) => ChatMessageModel.fromJson(e),
        )
        .toList();
  }

  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    await api.sendMessage(
      receiverId: receiverId,
      text: text,
    );
  }
}