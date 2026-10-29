import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/notification_api.dart';
import '../../domain/models/notification_model.dart';

final notificationApiProvider = Provider((ref) => NotificationApi());

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.read(notificationApiProvider).list();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((item) => !item.isRead).length,
        orElse: () => 0,
      );
});
