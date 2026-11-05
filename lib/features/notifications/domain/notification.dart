import '../../../core/storage/local_store.dart';

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, required this.at, this.read = false, this.orderId, this.offerCode});

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final bool read;
  final String? orderId;
  final String? offerCode;

  AppNotification markRead() => AppNotification(id: id, title: title, body: body, at: at, read: true, orderId: orderId, offerCode: offerCode);

  Json toJson() => {'id': id, 'title': title, 'body': body, 'at': at.toIso8601String(), 'read': read, 'orderId': orderId, 'offerCode': offerCode};

  factory AppNotification.fromJson(Json j) => AppNotification(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    at: DateTime.parse(j['at'] as String),
    read: j['read'] as bool? ?? false,
    orderId: j['orderId'] as String?,
    offerCode: j['offerCode'] as String?,
  );
}
