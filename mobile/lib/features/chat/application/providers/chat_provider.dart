import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/message_repository.dart';
import '../../domain/models/message_model.dart';

final messageRepositoryProvider =
    Provider(
  (ref) => MessageRepository(),
);

final chatProvider =
FutureProvider.family<
List<ChatMessageModel>,
String>((ref, userId) {

  return ref
      .read(messageRepositoryProvider)
      .getMessages(userId);

});