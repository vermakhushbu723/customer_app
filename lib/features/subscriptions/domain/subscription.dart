import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';

enum Frequency {
  daily('Every day'),
  alternate('Every other day'),
  weekly('Once a week');

  const Frequency(this.label);

  final String label;

  int get gapDays => switch (this) {
    Frequency.daily => 1,
    Frequency.alternate => 2,
    Frequency.weekly => 7,
  };
}

class Subscription {
  const Subscription({
    required this.id,
    required this.productId,
    required this.qty,
    required this.frequency,
    required this.slot,
    required this.addressId,
    required this.startDate,
    this.paused = false,
    this.skipped = const [],
  });

  final String id;
  final String productId;
  final int qty;
  final Frequency frequency;
  final String slot;
  final String addressId;
  final DateTime startDate;
  final bool paused;
  final List<DateTime> skipped;

  bool isSkipped(DateTime day) => skipped.any((d) => isSameDay(d, day));

  /// The next [count] delivery days from [from], including skipped ones.
  List<DateTime> upcoming(DateTime from, {int count = 5}) {
    final today = dateOnly(from);
    var day = dateOnly(startDate);
    while (day.isBefore(today)) {
      day = day.add(Duration(days: frequency.gapDays));
    }
    return [for (var i = 0; i < count; i++) DateTime(day.year, day.month, day.day + i * frequency.gapDays)];
  }

  /// The next day a delivery will actually come, or null while paused.
  DateTime? nextDelivery(DateTime from) {
    if (paused) return null;
    for (final day in upcoming(from, count: 30)) {
      if (!isSkipped(day)) return day;
    }
    return null;
  }

  Subscription copyWith({int? qty, Frequency? frequency, String? slot, String? addressId, DateTime? startDate, bool? paused, List<DateTime>? skipped}) => Subscription(
    id: id,
    productId: productId,
    qty: qty ?? this.qty,
    frequency: frequency ?? this.frequency,
    slot: slot ?? this.slot,
    addressId: addressId ?? this.addressId,
    startDate: startDate ?? this.startDate,
    paused: paused ?? this.paused,
    skipped: skipped ?? this.skipped,
  );

  Json toJson() => {
    'id': id,
    'productId': productId,
    'qty': qty,
    'frequency': frequency.name,
    'slot': slot,
    'addressId': addressId,
    'startDate': startDate.toIso8601String(),
    'paused': paused,
    'skipped': skipped.map((d) => d.toIso8601String()).toList(),
  };

  factory Subscription.fromJson(Json j) => Subscription(
    id: j['id'] as String,
    productId: j['productId'] as String,
    qty: j['qty'] as int,
    frequency: Frequency.values.byName(j['frequency'] as String),
    slot: j['slot'] as String,
    addressId: j['addressId'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    paused: j['paused'] as bool? ?? false,
    skipped: (j['skipped'] as List? ?? const []).cast<String>().map(DateTime.parse).toList(),
  );
}
