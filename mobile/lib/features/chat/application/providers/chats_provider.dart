import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/chat_repository.dart';
import '../../domain/models/chat_model.dart';

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(),
);

final chatsProvider =
    FutureProvider<List<ChatModel>>((ref) {
  return ref
      .read(chatRepositoryProvider)
      .getChats();
});