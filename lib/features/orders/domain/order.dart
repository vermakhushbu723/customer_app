import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';

enum OrderStatus {
  placed('Order placed', AppColors.sky600),
  confirmed('Confirmed', AppColors.sky600),
  packed('Packed', AppColors.sky700),
  outForDelivery('Out for delivery', AppColors.amber600),
  delivered('Delivered', AppColors.green700),
  cancelled('Cancelled', AppColors.red600),
  failed('Delivery failed', AppColors.red600);

  const OrderStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// The steps a delivery goes through, for the timeline.
const orderSteps = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.packed,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
];

/// The demo moves each order along by itself, this many minutes after it starts.
const _demoStepMinutes = {OrderStatus.packed: 2, OrderStatus.outForDelivery: 3, OrderStatus.delivered: 6};

enum PaymentMethod {
  upi('UPI', Icons.qr_code_2),
  card('Debit or credit card', Icons.credit_card),
  netbanking('Net banking', Icons.account_balance_outlined),
  wallet('ICECLUB wallet', Icons.account_balance_wallet_outlined),
  cod('Cash on delivery', Icons.payments_outlined);

  const PaymentMethod(this.label, this.icon);

  final String label;
  final IconData icon;
}

class OrderLine {
  const OrderLine({required this.productId, required this.name, required this.pack, required this.image, required this.qty, required this.price});

  final String productId;
  final String name;
  final String pack;
  final String image;
  final int qty;
  final double price;

  double get amount => qty * price;

  Json toJson() => {'productId': productId, 'name': name, 'pack': pack, 'image': image, 'qty': qty, 'price': price};

  factory OrderLine.fromJson(Json j) => OrderLine(
    productId: j['productId'] as String,
    name: j['name'] as String,
    pack: j['pack'] as String,
    image: j['image'] as String,
    qty: j['qty'] as int,
    price: (j['price'] as num).toDouble(),
  );
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.expressFee,
    required this.tip,
    required this.walletUsed,
    required this.total,
    required this.paymentMethod,
    required this.addressLabel,
    required this.addressText,
    required this.receiverName,
    required this.receiverPhone,
    required this.latitude,
    required this.longitude,
    required this.deliveryDate,
    required this.slot,
    required this.placedAt,
    required this.otp,
    this.couponCode,
    this.instructions = '',
    this.cancelledAt,
    this.cancelReason,
    this.deliveryRating,
    this.productRating,
    this.reviewText,
    this.serverStatus,
    this.steps = const {},
    this.serverCanCancel = false,
    this.riderName,
    this.riderPhone,
    this.riderVehicle,
  });

  final String id;
  final String number;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double expressFee;
  final double tip;
  final double walletUsed;

  /// What was left to pay after the wallet.
  final double total;
  final PaymentMethod paymentMethod;
  final String addressLabel;
  final String addressText;
  final String receiverName;
  final String receiverPhone;
  final double latitude;
  final double longitude;
  final DateTime deliveryDate;
  final String slot;
  final DateTime placedAt;
  final String otp;
  final String? couponCode;
  final String instructions;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final int? deliveryRating;
  final int? productRating;
  final String? reviewText;

  /// Set when the server says where the order is. Without one, the demo timing below applies.
  final OrderStatus? serverStatus;
  final Map<OrderStatus, DateTime> steps;
  final bool serverCanCancel;
  final String? riderName;
  final String? riderPhone;
  final String? riderVehicle;

  double get grandTotal => total + walletUsed;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);
  bool get paidOnline => paymentMethod != PaymentMethod.cod;
  bool get isExpress => expressFee > 0;

  /// When the delivery work starts: straight away, or on a later delivery day.
  DateTime get _workStart {
    final day = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
    return day.isAfter(placedAt) ? day : placedAt;
  }

  /// When each step happened or will happen.
  DateTime timeOf(OrderStatus step) => serverStatus != null ? (steps[step] ?? placedAt) : switch (step) {
    OrderStatus.placed => placedAt,
    OrderStatus.confirmed => placedAt.add(const Duration(minutes: 1)),
    OrderStatus.cancelled => cancelledAt ?? placedAt,
    OrderStatus.failed => placedAt,
    _ => _workStart.add(Duration(minutes: _demoStepMinutes[step]!)),
  };

  OrderStatus statusAt(DateTime now) {
    if (serverStatus != null) return serverStatus!;
    if (cancelledAt != null) return OrderStatus.cancelled;
    return orderSteps.lastWhere((step) => !timeOf(step).isAfter(now));
  }

  bool isActiveAt(DateTime now) {
    final status = statusAt(now);
    return status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  /// An order can be cancelled until it leaves with the rider.
  bool canCancelAt(DateTime now) => serverStatus != null ? serverCanCancel : const [OrderStatus.placed, OrderStatus.confirmed, OrderStatus.packed].contains(statusAt(now));

  /// How far along the road the rider is, from 0 to 1.
  double tripProgressAt(DateTime now) {
    final start = timeOf(OrderStatus.outForDelivery);
    final end = timeOf(OrderStatus.delivered);
    final done = now.difference(start).inSeconds / end.difference(start).inSeconds;
    return done.clamp(0.0, 1.0);
  }

  int etaMinutesAt(DateTime now) {
    final left = timeOf(OrderStatus.delivered).difference(now).inSeconds;
    return left <= 0 ? 0 : (left / 60).ceil();
  }

  Order copyWith({DateTime? cancelledAt, String? cancelReason, int? deliveryRating, int? productRating, String? reviewText}) => Order(
    id: id,
    number: number,
    lines: lines,
    subtotal: subtotal,
    discount: discount,
    deliveryFee: deliveryFee,
    expressFee: expressFee,
    tip: tip,
    walletUsed: walletUsed,
    total: total,
    paymentMethod: paymentMethod,
    addressLabel: addressLabel,
    addressText: addressText,
    receiverName: receiverName,
    receiverPhone: receiverPhone,
    latitude: latitude,
    longitude: longitude,
    deliveryDate: deliveryDate,
    slot: slot,
    placedAt: placedAt,
    otp: otp,
    couponCode: couponCode,
    instructions: instructions,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancelReason: cancelReason ?? this.cancelReason,
    deliveryRating: deliveryRating ?? this.deliveryRating,
    productRating: productRating ?? this.productRating,
    reviewText: reviewText ?? this.reviewText,
    serverStatus: serverStatus,
    steps: steps,
    serverCanCancel: serverCanCancel,
    riderName: riderName,
    riderPhone: riderPhone,
    riderVehicle: riderVehicle,
  );

  Json toJson() => {
    'id': id,
    'number': number,
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal,
    'discount': discount,
    'deliveryFee': deliveryFee,
    'expressFee': expressFee,
    'tip': tip,
    'walletUsed': walletUsed,
    'total': total,
    'paymentMethod': paymentMethod.name,
    'addressLabel': addressLabel,
    'addressText': addressText,
    'receiverName': receiverName,
    'receiverPhone': receiverPhone,
    'latitude': latitude,
    'longitude': longitude,
    'deliveryDate': deliveryDate.toIso8601String(),
    'slot': slot,
    'placedAt': placedAt.toIso8601String(),
    'otp': otp,
    'couponCode': couponCode,
    'instructions': instructions,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancelReason': cancelReason,
    'deliveryRating': deliveryRating,
    'productRating': productRating,
    'reviewText': reviewText,
    'status': serverStatus?.name,
    'steps': {for (final e in steps.entries) e.key.name: e.value.toIso8601String()},
    'canCancel': serverCanCancel,
    'rider': riderName == null ? null : {'name': riderName, 'phone': riderPhone, 'vehicle': riderVehicle},
  };

  factory Order.fromJson(Json j) => Order(
    id: j['id'] as String,
    number: j['number'] as String,
    lines: (j['lines'] as List).cast<Json>().map(OrderLine.fromJson).toList(),
    subtotal: (j['subtotal'] as num).toDouble(),
    discount: (j['discount'] as num).toDouble(),
    deliveryFee: (j['deliveryFee'] as num).toDouble(),
    expressFee: (j['expressFee'] as num).toDouble(),
    tip: (j['tip'] as num).toDouble(),
    walletUsed: (j['walletUsed'] as num).toDouble(),
    total: (j['total'] as num).toDouble(),
    paymentMethod: PaymentMethod.values.byName(j['paymentMethod'] as String),
    addressLabel: j['addressLabel'] as String,
    addressText: j['addressText'] as String,
    receiverName: j['receiverName'] as String,
    receiverPhone: j['receiverPhone'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    deliveryDate: DateTime.parse(j['deliveryDate'] as String),
    slot: j['slot'] as String,
    placedAt: DateTime.parse(j['placedAt'] as String),
    otp: j['otp'] as String,
    couponCode: j['couponCode'] as String?,
    instructions: j['instructions'] as String? ?? '',
    cancelledAt: j['cancelledAt'] == null ? null : DateTime.parse(j['cancelledAt'] as String),
    cancelReason: j['cancelReason'] as String?,
    deliveryRating: j['deliveryRating'] as int?,
    productRating: j['productRating'] as int?,
    reviewText: j['reviewText'] as String?,
    serverStatus: j['status'] == null ? null : OrderStatus.values.byName(j['status'] as String),
    steps: {
      for (final e in ((j['steps'] as Map?) ?? const {}).entries) OrderStatus.values.byName(e.key as String): DateTime.parse(e.value as String),
    },
    serverCanCancel: j['canCancel'] as bool? ?? false,
    riderName: (j['rider'] as Map?)?['name'] as String?,
    riderPhone: (j['rider'] as Map?)?['phone'] as String?,
    riderVehicle: (j['rider'] as Map?)?['vehicle'] as String?,
  );
}

enum IssueType {
  damaged('Damaged packaging'),
  melted('Melted ice'),
  short('Less quantity than ordered'),
  wrong('Wrong item delivered'),
  other('Something else');

  const IssueType(this.label);

  final String label;
}

class OrderIssue {
  const OrderIssue({required this.id, required this.number, required this.orderId, required this.orderNumber, required this.type, required this.details, required this.photos, required this.at, this.status = 'underReview', this.remark = '', this.creditAmount = 0});

  final String id;
  final String number;
  final String orderId;
  final String orderNumber;
  final IssueType type;
  final String details;
  final List<String> photos;
  final DateTime at;

  /// underReview, approved or rejected. Only the ICECLUB team can change it.
  final String status;
  final String remark;
  final double creditAmount;

  Json toJson() => {'id': id, 'number': number, 'orderId': orderId, 'orderNumber': orderNumber, 'type': type.name, 'details': details, 'photos': photos, 'at': at.toIso8601String(), 'status': status, 'remark': remark, 'creditAmount': creditAmount};

  factory OrderIssue.fromJson(Json j) => OrderIssue(
    id: j['id'] as String,
    number: j['number'] as String,
    orderId: j['orderId'] as String,
    orderNumber: j['orderNumber'] as String,
    type: IssueType.values.byName(j['type'] as String),
    details: j['details'] as String,
    photos: (j['photos'] as List).cast<String>(),
    at: DateTime.parse(j['at'] as String),
    status: j['status'] as String? ?? 'underReview',
    remark: j['remark'] as String? ?? '',
    creditAmount: (j['creditAmount'] as num?)?.toDouble() ?? 0,
  );
}
