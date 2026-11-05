import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../addresses/domain/address.dart';
import '../../auth/data/auth_controller.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/domain/cart_pricing.dart';
import '../../catalog/data/catalog_data.dart';
import '../../catalog/domain/product.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../wallet/data/wallet_controller.dart';
import '../domain/order.dart';

/// Everything the customer chose on the checkout screen.
class CheckoutRequest {
  const CheckoutRequest({
    required this.address,
    required this.date,
    required this.slot,
    required this.express,
    required this.tip,
    required this.useWallet,
    required this.method,
    required this.instructions,
    required this.dryIceAccepted,
  });

  final Address? address;
  final DateTime date;
  final String? slot;
  final bool express;
  final double tip;
  final bool useWallet;
  final PaymentMethod? method;
  final String instructions;
  final bool dryIceAccepted;
}

class OrdersController extends ListStore<Order> {
  @override
  String get key => 'orders';
  @override
  String get path => '/customer/orders';
  @override
  Order fromJson(Json json) => Order.fromJson(json);
  @override
  Json toJson(Order item) => item.toJson();

  @override
  List<Order> seed() {
    final now = DateTime.now();
    Order sample(String id, Duration ago, String productId, int qty, PaymentMethod method, {bool cancelled = false, int? rating}) {
      final p = productById(productId)!;
      final subtotal = p.price * qty;
      final fee = subtotal >= AppConstants.freeDeliveryAbove ? 0.0 : AppConstants.deliveryFee;
      final placed = now.subtract(ago);
      return Order(
        id: id,
        number: 'ICE-$id',
        lines: [OrderLine(productId: p.id, name: p.name, pack: p.pack, image: p.image, qty: qty, price: p.price)],
        subtotal: subtotal,
        discount: 0,
        deliveryFee: fee,
        expressFee: 0,
        tip: 0,
        walletUsed: 0,
        total: subtotal + fee,
        paymentMethod: method,
        addressLabel: 'Home',
        addressText: '12 Sea View Apartments, Andheri West, Mumbai - 400053',
        receiverName: 'Sample customer',
        receiverPhone: '9876500000',
        latitude: 19.1364,
        longitude: 72.8296,
        deliveryDate: placed,
        slot: AppConstants.deliverySlots[1].$1,
        placedAt: placed,
        otp: '4827',
        cancelledAt: cancelled ? placed.add(const Duration(minutes: 5)) : null,
        cancelReason: cancelled ? 'Plans changed' : null,
        deliveryRating: rating,
        productRating: rating,
      );
    }

    return [
      sample('100487', const Duration(seconds: 200), 'cube-5', 2, PaymentMethod.upi),
      sample('100452', const Duration(days: 2), 'tube-5', 3, PaymentMethod.upi, rating: 5),
      sample('100431', const Duration(days: 8), 'cube-1', 4, PaymentMethod.cod),
      sample('100398', const Duration(days: 15), 'dry-1', 1, PaymentMethod.card, cancelled: true),
      sample('100377', const Duration(days: 23), 'tube-20', 2, PaymentMethod.upi),
    ];
  }

  /// Checks the whole order and works out its bill. Throws with a message the customer can act on.
  Bill billFor(List<CartLine> lines, CheckoutRequest r) {
    if (lines.isEmpty) throw const AppException('Your cart is empty');
    final subtotal = subtotalOf(lines);
    if (subtotal < AppConstants.minOrderValue) throw const AppException('The minimum order is ₹99');
    if (r.address == null) throw const AppException('Select a delivery address');
    if (!deliversTo(r.address!.pincode)) throw AppException('We do not deliver to ${r.address!.pincode} yet');
    if (r.slot == null) throw const AppException('Select a delivery slot');
    if (lines.any((l) => !l.product.inStock)) throw const AppException('Something in your cart is out of stock');
    if (lines.any((l) => l.product.isDryIce) && !r.dryIceAccepted) {
      throw const AppException('Please accept the dry ice safety note');
    }
    final bill = computeBill(
      mrpTotal: mrpTotalOf(lines),
      subtotal: subtotal,
      coupon: ref.read(appliedCouponProvider),
      express: r.express,
      tip: r.tip,
      walletBalance: ref.read(walletBalanceProvider),
      useWallet: r.useWallet,
    );
    if (bill.total > 0 && r.method == null) throw const AppException('Select a payment method');
    return bill;
  }

  /// Places the order after payment. It takes the wallet money and empties the cart.
  /// The server checks everything again and works out the amount itself.
  Future<Order> place(CheckoutRequest r) async {
    final lines = ref.read(cartLinesProvider);
    final bill = billFor(lines, r);
    if (!useFakeBackend) {
      final body = await api.post('/customer/orders', {
        'addressId': r.address!.id,
        'items': [for (final l in lines) {'productId': l.product.id, 'qty': l.qty}],
        'deliveryDate': r.date.toIso8601String(),
        'slot': r.slot,
        'express': r.express,
        'tip': r.tip,
        'useWallet': r.useWallet,
        'paymentMethod': bill.total == 0 ? 'wallet' : r.method?.name,
        'couponCode': ref.read(appliedCouponProvider)?.code,
        'instructions': r.instructions.trim(),
        'dryIceAccepted': r.dryIceAccepted,
        'expectedTotal': bill.total,
      });
      final order = Order.fromJson(body as Map<String, dynamic>);
      save([order, ...state]);
      ref.read(cartProvider.notifier).clear();
      ref.read(appliedCouponProvider.notifier).set(null);
      await Future.wait([ref.read(walletProvider.notifier).refresh(), ref.read(notificationsProvider.notifier).refresh()].map((f) => f.catchError((_) {})));
      return order;
    }
    final id = '${DateTime.now().millisecondsSinceEpoch % 1000000}'.padLeft(6, '0');
    final customer = ref.read(authProvider);
    final order = Order(
      id: id,
      number: 'ICE-$id',
      lines: [
        for (final l in lines)
          OrderLine(productId: l.product.id, name: l.product.name, pack: l.product.pack, image: l.product.image, qty: l.qty, price: l.product.price),
      ],
      subtotal: bill.subtotal,
      discount: bill.discount,
      deliveryFee: bill.deliveryFee,
      expressFee: bill.expressFee,
      tip: bill.tip,
      walletUsed: bill.walletUsed,
      total: bill.total,
      paymentMethod: bill.total == 0 ? PaymentMethod.wallet : r.method!,
      addressLabel: r.address!.label,
      addressText: r.address!.singleLine,
      receiverName: r.address!.name.isEmpty ? (customer?.name ?? '') : r.address!.name,
      receiverPhone: r.address!.phone,
      latitude: r.address!.latitude,
      longitude: r.address!.longitude,
      deliveryDate: r.date,
      slot: r.express ? 'Express, within 60 minutes' : r.slot!,
      placedAt: DateTime.now(),
      otp: '${1000 + Random().nextInt(9000)}',
      couponCode: ref.read(appliedCouponProvider)?.code,
      instructions: r.instructions.trim(),
    );
    ref.read(walletProvider.notifier).spend(bill.walletUsed, 'Paid for order ${order.number}');
    save([order, ...state]);
    ref.read(cartProvider.notifier).clear();
    ref.read(appliedCouponProvider.notifier).set(null);
    ref.read(notificationsProvider.notifier).push('Order placed', 'We have your order ${order.number}.', orderId: order.id);
    return order;
  }

  /// Refunds anything already paid into the wallet.
  Future<void> cancel(String id, String reason, DateTime now) async {
    if (!useFakeBackend) {
      final body = await api.post('/customer/orders/$id/cancel', {'reason': reason});
      _replace(Order.fromJson(body as Map<String, dynamic>));
      await Future.wait([ref.read(walletProvider.notifier).refresh(), ref.read(notificationsProvider.notifier).refresh()].map((f) => f.catchError((_) {})));
      return;
    }
    final order = byId(id);
    if (order == null || !order.canCancelAt(now)) {
      throw const AppException('This order can no longer be cancelled');
    }
    if (reason.trim().isEmpty) throw const AppException('Select a reason');
    _replace(order.copyWith(cancelledAt: now, cancelReason: reason));
    final refund = order.walletUsed + (order.paymentMethod == PaymentMethod.cod ? 0 : order.total);
    if (refund > 0) await ref.read(walletProvider.notifier).add(refund, 'Refund for order ${order.number}');
    ref.read(notificationsProvider.notifier).push(
      'Order cancelled',
      refund > 0 ? 'Your refund for ${order.number} is in your wallet.' : '${order.number} has been cancelled.',
      orderId: order.id,
    );
  }

  Future<void> rate(String id, {required int delivery, required int product, required String text}) async {
    if (!useFakeBackend) {
      final body = await api.post('/customer/orders/$id/rate', {'delivery': delivery, 'product': product, 'text': text});
      _replace(Order.fromJson(body as Map<String, dynamic>));
      return;
    }
    final order = byId(id);
    if (order == null) return;
    _replace(order.copyWith(deliveryRating: delivery, productRating: product, reviewText: text.trim()));
    final author = ref.read(authProvider)?.firstName ?? 'Customer';
    for (final l in order.lines) {
      ref.read(reviewsProvider.notifier).add(
        Review(productId: l.productId, author: author, rating: product, text: text.trim().isEmpty ? 'Rated $product out of 5.' : text.trim(), at: DateTime.now()),
      );
    }
  }

  /// Puts an old order's items back in the cart. Returns what could not be added.
  List<String> reorder(String id) {
    final missing = <String>[];
    for (final l in byId(id)?.lines ?? const <OrderLine>[]) {
      final product = productById(l.productId);
      if (product == null || !product.inStock) {
        missing.add(l.name);
      } else {
        ref.read(cartProvider.notifier).add(l.productId, l.qty);
      }
    }
    return missing;
  }

  Order? byId(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }

  void _replace(Order order) => save([for (final o in state) o.id == order.id ? order : o]);
}

final ordersProvider = NotifierProvider<OrdersController, List<Order>>(OrdersController.new);

/// Reward points earned on everything delivered, minus what was redeemed.
int availablePoints(List<Order> orders, int redeemed, DateTime now) {
  final earned = orders
      .where((o) => o.statusAt(now) == OrderStatus.delivered)
      .fold<int>(0, (sum, o) => sum + o.grandTotal ~/ AppConstants.pointsPerRupees);
  return earned - redeemed;
}

class IssuesController extends ListStore<OrderIssue> {
  @override
  String get key => 'order_issues';
  @override
  String get path => '/customer/issues';
  @override
  OrderIssue fromJson(Json json) => OrderIssue.fromJson(json);
  @override
  Json toJson(OrderIssue item) => item.toJson();

  Future<OrderIssue> report(Order order, IssueType type, String details, List<String> photos) async {
    if (!useFakeBackend) {
      final uploaded = [for (final p in photos) await api.upload(p)];
      final body = await api.post('/customer/issues', {'orderId': order.id, 'type': type.name, 'details': details, 'photos': uploaded});
      final issue = OrderIssue.fromJson(body as Map<String, dynamic>);
      save([issue, ...state]);
      return issue;
    }
    if (details.trim().isEmpty) throw const AppException('Tell us what went wrong');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final issue = OrderIssue(
      id: id,
      number: 'ISS-${id.substring(id.length - 5)}',
      orderId: order.id,
      orderNumber: order.number,
      type: type,
      details: details.trim(),
      photos: photos,
      at: DateTime.now(),
    );
    save([issue, ...state]);
    return issue;
  }
}

final issuesProvider = NotifierProvider<IssuesController, List<OrderIssue>>(IssuesController.new);
