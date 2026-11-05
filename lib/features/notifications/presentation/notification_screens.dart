import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(tooltip: 'Notification settings', icon: const Icon(Icons.tune), onPressed: () => context.push(Routes.notificationSettings)),
          if (items.any((n) => !n.read)) TextButton(onPressed: controller.markAllRead, child: const Text('Mark all read')),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.notifications_none, title: 'No notifications', message: 'Order updates and offers will show up here.')
          : ListView(
              padding: AppSpacing.page,
              children: [
                for (final n in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(n.id),
                      onDismissed: (_) => controller.remove(n.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppColors.red50,
                        child: const Icon(Icons.delete_outline, color: AppColors.red600),
                      ),
                      direction: DismissDirection.endToStart,
                      child: AppCard(
                        onTap: () {
                          controller.markRead(n.id);
                          if (n.orderId != null) context.push(Routes.order(n.orderId!));
                          if (n.offerCode != null) context.push(Routes.offer(n.offerCode!));
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(n.offerCode != null ? Icons.local_offer_outlined : Icons.receipt_long_outlined, color: AppColors.sky700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: Theme.of(context).textTheme.labelLarge),
                                  Text(n.body),
                                  Text(formatDateTime(n.at), style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            if (!n.read) const Icon(Icons.circle, size: 9, color: AppColors.sky600),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final entry in prefs.entries)
                  SwitchListTile(
                    title: Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                    value: entry.value,
                    onChanged: (v) => ref.read(notificationPrefsProvider.notifier).set(entry.key, v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const NoticeBanner('Your choices are saved. Phone alerts start when push notifications are connected.'),
        ],
      ),
    );
  }
}
