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
    // One automatic retry: uploads on mobile data often fail once.
    String url;
    try {
      url = await api.uploadAudio(file);
    } catch (_) {
      await Future.delayed(const Duration(seconds: 2));
      url = await api.uploadAudio(file);
    }
    await api.sendMessage(receiverId: receiverId, audio: url, durationSec: durationSec);
  }

  /// Uploads a photo, then sends it as an image message with an optional caption.
  Future<void> sendPhoto({required String receiverId, required File file, String caption = ""}) async {
    final url = await api.uploadImage(file);
    await api.sendMessage(receiverId: receiverId, image: url, text: caption);
  }

  /// Friend's online state: (online, lastSeenAt).
  Future<(bool, DateTime?)> presence(String userId) async {
    try {
      final r = await api.presence(userId);
      return (r["online"] == true, DateTime.tryParse(r["lastSeenAt"]?.toString() ?? "")?.toLocal());
    } catch (_) {
      return (false, null);
    }
  }

  Future<void> markRead(String userId) async {
    try {
      await api.markRead(userId);
    } catch (_) {}
  }
}
