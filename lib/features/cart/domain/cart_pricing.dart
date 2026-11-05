import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';

class Coupon {
  const Coupon({
    required this.code,
    required this.title,
    required this.description,
    required this.minOrder,
    this.flatOff = 0,
    this.percentOff = 0,
    this.maxOff = 0,
    this.freeDelivery = false,
  });

  final String code;
  final String title;
  final String description;
  final double minOrder;
  final double flatOff;
  final double percentOff;
  final double maxOff;
  final bool freeDelivery;
}

/// Why this coupon can't be used on the subtotal, or null if it can.
String? couponProblem(Coupon coupon, double subtotal) =>
    subtotal < coupon.minOrder ? 'Add ${money(coupon.minOrder - subtotal)} more to use ${coupon.code}' : null;

double couponDiscount(Coupon? coupon, double subtotal) {
  if (coupon == null || couponProblem(coupon, subtotal) != null) return 0;
  var off = coupon.flatOff;
  if (coupon.percentOff > 0) {
    off = subtotal * coupon.percentOff / 100;
    if (coupon.maxOff > 0 && off > coupon.maxOff) off = coupon.maxOff;
  }
  return roundMoney(off > subtotal ? subtotal : off);
}

class Bill {
  const Bill({
    required this.mrpTotal,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.expressFee,
    required this.tip,
    required this.walletUsed,
    required this.total,
  });

  final double mrpTotal;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double expressFee;
  final double tip;
  final double walletUsed;

  /// What is still to pay after the wallet.
  final double total;

  double get savings => roundMoney(mrpTotal - subtotal + discount);
}

/// Prices already include GST. The wallet can pay all or part of the bill.
Bill computeBill({
  required double mrpTotal,
  required double subtotal,
  Coupon? coupon,
  bool express = false,
  double tip = 0,
  double walletBalance = 0,
  bool useWallet = false,
}) {
  final discount = couponDiscount(coupon, subtotal);
  final freeByCoupon = coupon != null && coupon.freeDelivery && couponProblem(coupon, subtotal) == null;
  final delivery = freeByCoupon || subtotal - discount >= AppConstants.freeDeliveryAbove || subtotal == 0
      ? 0.0
      : AppConstants.deliveryFee;
  final expressFee = express ? AppConstants.expressFee : 0.0;
  final payable = roundMoney(subtotal - discount + delivery + expressFee + tip);
  final fromWallet = useWallet ? (walletBalance < payable ? walletBalance : payable) : 0.0;
  return Bill(
    mrpTotal: mrpTotal,
    subtotal: subtotal,
    discount: discount,
    deliveryFee: delivery,
    expressFee: expressFee,
    tip: tip,
    walletUsed: roundMoney(fromWallet),
    total: roundMoney(payable - fromWallet),
  );
}

/// The delivery slots still open on [day]. A same-day slot closes before it starts.
List<(String, int)> openSlots(DateTime day, DateTime now) {
  if (!isSameDay(day, now)) return AppConstants.deliverySlots;
  return AppConstants.deliverySlots.where((s) => s.$2 - now.hour >= AppConstants.slotLeadHours).toList();
}
