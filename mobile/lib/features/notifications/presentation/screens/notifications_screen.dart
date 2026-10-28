import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../application/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Updates", style: AppTextStyles.title),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationApiProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text("Mark all read"),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_none_outlined,
                title: "You're all caught up",
                message:
                    "Friend requests, likes, challenges, and messages will show up here.",
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = list[index];
                return ListTile(
                  tileColor: item.isRead
                      ? AppColors.card
                      : AppColors.primary.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  title: Text(item.title, style: AppTextStyles.body),
                  subtitle: Text(item.message, style: AppTextStyles.subtitle),
                  onTap: item.isRead
                      ? null
                      : () async {
                          await ref
                              .read(notificationApiProvider)
                              .markRead(item.id);
                          ref.invalidate(notificationsProvider);
                        },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
