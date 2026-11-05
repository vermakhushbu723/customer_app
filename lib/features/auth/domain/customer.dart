import '../../../core/storage/local_store.dart';

class Customer {
  const Customer({required this.phone, this.name = '', this.email = '', this.referralCode = ''});

  final String phone;
  final String name;
  final String email;
  final String referralCode;

  /// A new customer gives their name once, after the first OTP.
  bool get profileComplete => name.trim().isNotEmpty;

  String get firstName => name.trim().split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Customer copyWith({String? name, String? email}) =>
      Customer(phone: phone, name: name ?? this.name, email: email ?? this.email, referralCode: referralCode);

  Json toJson() => {'phone': phone, 'name': name, 'email': email, 'referralCode': referralCode};

  factory Customer.fromJson(Json j) => Customer(
    phone: j['phone'] as String,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
    referralCode: j['referralCode'] as String? ?? '',
  );
}
