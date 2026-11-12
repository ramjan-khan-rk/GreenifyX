import 'dart:io';

import '../../domain/models/message_model.dart';
import '../api/message_api.dart';

class MessageRepository {
  final MessageApi api = MessageApi();

  Future<List<ChatMessageModel>> getMessages(String userId) async {
    final data = await api.getMessages(userId);
    return data.map<ChatMessageModel>((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> sendMessage({required String receiverId, required String text}) =>
      api.sendMessage(receiverId: receiverId, text: text);

  /// Uploads the recording, then sends it as a voice-note message.
  Future<void> sendVoiceNote({required String receiverId, required File file, required int durationSec}) async {
    final url = await api.uploadAudio(file);
    await api.sendMessage(receiverId: receiverId, audio: url, durationSec: durationSec);
  }

  Future<void> markRead(String userId) async {
    try {
      await api.markRead(userId);
    } catch (_) {}
  }
}
