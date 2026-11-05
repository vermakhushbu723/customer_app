import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../domain/notification.dart';

class NotificationsController extends ListStore<AppNotification> {
  @override
  String get key => 'notifications';
  @override
  String get path => '/customer/notifications';
  @override
  AppNotification fromJson(Json json) => AppNotification.fromJson(json);
  @override
  Json toJson(AppNotification item) => item.toJson();

  @override
  List<AppNotification> seed() {
    final now = DateTime.now();
    return [
      AppNotification(id: 'n1', title: 'Your ice is on the way', body: 'Order ICE-100487 is being prepared.', at: now.subtract(const Duration(minutes: 3)), orderId: '100487'),
      AppNotification(id: 'n2', title: '10% off this weekend', body: 'Use COOL10 on orders of ₹199 or more.', at: now.subtract(const Duration(hours: 6)), offerCode: 'COOL10'),
      AppNotification(id: 'n3', title: 'Order delivered', body: 'ICE-100452 was delivered. How was it?', at: now.subtract(const Duration(days: 2)), orderId: '100452', read: true),
    ];
  }

  void push(String title, String body, {String? orderId}) => save([
    AppNotification(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title, body: body, at: DateTime.now(), orderId: orderId),
    ...state,
  ]);

  /// Shown straight away, and sent to the server behind the scenes.
  Future<void> markRead(String id) async {
    save([for (final n in state) n.id == id ? n.markRead() : n]);
    if (!useFakeBackend) await api.post('/customer/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    save([for (final n in state) n.markRead()]);
    if (!useFakeBackend) await api.post('/customer/notifications/read-all');
  }

  Future<void> remove(String id) async {
    save(state.where((n) => n.id != id).toList());
    if (!useFakeBackend) await api.delete('/customer/notifications/$id');
  }
}

final notificationsProvider = NotifierProvider<NotificationsController, List<AppNotification>>(NotificationsController.new);

final unreadCountProvider = Provider<int>((ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);

/// The customer's choices for what to hear about. The server will read these when push is connected.
class NotificationPrefs extends Notifier<Map<String, bool>> {
  static const _key = 'notification_prefs';
  static const defaults = {'Order updates': true, 'Offers and coupons': true, 'Subscription reminders': true, 'WhatsApp messages': false};

  @override
  Map<String, bool> build() {
    final saved = ref.watch(customerStoreProvider).readMap(_key);
    return {...defaults, ...?saved?.map((k, v) => MapEntry(k, v as bool))};
  }

  Future<void> refresh() async {
    if (useFakeBackend) return;
    final saved = await ref.read(apiProvider).get('/customer/notification-prefs') as Map<String, dynamic>;
    _save({...defaults, ...saved.map((k, v) => MapEntry(k, v as bool))});
  }

  Future<void> set(String name, bool on) async {
    _save({...state, name: on});
    if (!useFakeBackend) await ref.read(apiProvider).put('/customer/notification-prefs', state);
  }

  void _save(Map<String, bool> next) {
    state = next;
    ref.read(customerStoreProvider).writeMap(_key, state);
  }
}

final notificationPrefsProvider = NotifierProvider<NotificationPrefs, Map<String, bool>>(NotificationPrefs.new);
