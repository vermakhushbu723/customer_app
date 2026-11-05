import '../../../core/storage/local_store.dart';

class WalletEntry {
  const WalletEntry({required this.id, required this.amount, required this.title, required this.at});

  final String id;

  /// Money in is positive, money out is negative.
  final double amount;
  final String title;
  final DateTime at;

  Json toJson() => {'id': id, 'amount': amount, 'title': title, 'at': at.toIso8601String()};

  factory WalletEntry.fromJson(Json j) => WalletEntry(
    id: j['id'] as String,
    amount: (j['amount'] as num).toDouble(),
    title: j['title'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

class RewardEntry {
  const RewardEntry({required this.points, required this.at});

  final int points;
  final DateTime at;

  Json toJson() => {'points': points, 'at': at.toIso8601String()};

  factory RewardEntry.fromJson(Json j) => RewardEntry(points: j['points'] as int, at: DateTime.parse(j['at'] as String));
}
