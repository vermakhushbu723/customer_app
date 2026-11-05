import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_store.dart';

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line,
    required this.landmark,
    required this.city,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String name;
  final String phone;
  final String line;
  final String landmark;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;

  String get singleLine => [line, if (landmark.isNotEmpty) landmark, '$city - $pincode'].join(', ');

  Address copyWith({bool? isDefault}) => Address(
    id: id,
    label: label,
    name: name,
    phone: phone,
    line: line,
    landmark: landmark,
    city: city,
    pincode: pincode,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault ?? this.isDefault,
  );

  Json toJson() => {
    'id': id,
    'label': label,
    'name': name,
    'phone': phone,
    'line': line,
    'landmark': landmark,
    'city': city,
    'pincode': pincode,
    'latitude': latitude,
    'longitude': longitude,
    'isDefault': isDefault,
  };

  factory Address.fromJson(Json j) => Address(
    id: j['id'] as String,
    label: j['label'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    line: j['line'] as String,
    landmark: j['landmark'] as String? ?? '',
    city: j['city'] as String,
    pincode: j['pincode'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    isDefault: j['isDefault'] as bool? ?? false,
  );
}

bool deliversTo(String pincode) => AppConstants.servicePinPrefixes.any((prefix) => pincode.trim().startsWith(prefix));
