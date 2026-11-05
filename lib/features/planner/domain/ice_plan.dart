import '../../../core/storage/local_store.dart';

/// A rough guide: half a kilo per guest for the first three hours, more as the event runs on and in hot weather.
int iceNeededKg({required int guests, required int hours, required bool hotDay, required bool coolingDrinks}) {
  if (guests <= 0 || hours <= 0) return 0;
  var kg = guests * 0.5;
  if (hours > 3) kg *= 1 + (hours - 3) * 0.2;
  if (hotDay) kg *= 1.25;
  if (coolingDrinks) kg += guests * 0.5;
  return kg.ceil();
}

/// The fewest bags that reach [kg], from pack sizes in kg. Biggest packs first.
Map<int, int> packsFor(int kg, List<int> packSizes) {
  final sizes = [...packSizes]..sort((a, b) => b.compareTo(a));
  final result = <int, int>{};
  var left = kg;
  for (final size in sizes) {
    final bags = left ~/ size;
    if (bags > 0) {
      result[size] = bags;
      left -= bags * size;
    }
  }
  if (left > 0) {
    final smallest = sizes.last;
    result[smallest] = (result[smallest] ?? 0) + (left / smallest).ceil();
  }
  return result;
}

enum EnquiryStatus {
  received('Received'),
  quoted('Quote sent');

  const EnquiryStatus(this.label);

  final String label;
}

class BulkEnquiry {
  const BulkEnquiry({required this.id, required this.eventType, required this.date, required this.quantityKg, required this.location, required this.notes, required this.at, this.status = EnquiryStatus.received, this.quote = ''});

  final String id;
  final String eventType;
  final DateTime date;
  final int quantityKg;
  final String location;
  final String notes;
  final DateTime at;
  final EnquiryStatus status;

  /// The price the ICECLUB team sent back.
  final String quote;

  Json toJson() => {'id': id, 'eventType': eventType, 'date': date.toIso8601String(), 'quantityKg': quantityKg, 'location': location, 'notes': notes, 'at': at.toIso8601String(), 'status': status.name, 'quote': quote};

  factory BulkEnquiry.fromJson(Json j) => BulkEnquiry(
    id: j['id'] as String,
    eventType: j['eventType'] as String,
    date: DateTime.parse(j['date'] as String),
    quantityKg: j['quantityKg'] as int,
    location: j['location'] as String,
    notes: j['notes'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
    status: EnquiryStatus.values.byName(j['status'] as String),
    quote: j['quote'] as String? ?? '',
  );
}
