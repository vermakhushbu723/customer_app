import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/list_store.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/data/catalog_data.dart';
import '../../catalog/domain/product.dart';
import '../domain/cart_pricing.dart';

const maxQtyPerItem = 50;

class CartController extends Notifier<Map<String, int>> {
  static const _key = 'cart';

  @override
  Map<String, int> build() {
    final saved = ref.watch(customerStoreProvider).readMap(_key);
    return saved == null ? {} : saved.map((id, qty) => MapEntry(id, qty as int));
  }

  void setQty(String id, int qty) {
    final next = {...state};
    if (qty <= 0) {
      next.remove(id);
    } else {
      next[id] = qty > maxQtyPerItem ? maxQtyPerItem : qty;
    }
    _save(next);
  }

  void add(String id, [int qty = 1]) => setQty(id, (state[id] ?? 0) + qty);

  void clear() => _save({});

  void _save(Map<String, int> next) {
    state = next;
    ref.read(customerStoreProvider).writeMap(_key, next);
  }
}

final cartProvider = NotifierProvider<CartController, Map<String, int>>(CartController.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).values.fold(0, (a, b) => a + b));

typedef CartLine = ({Product product, int qty});

final cartLinesProvider = Provider<List<CartLine>>((ref) {
  return [
    for (final entry in ref.watch(cartProvider).entries)
      if (productById(entry.key) case final product?) (product: product, qty: entry.value),
  ];
});

double subtotalOf(List<CartLine> lines) => roundMoney(lines.fold(0.0, (sum, l) => sum + l.product.price * l.qty));
double mrpTotalOf(List<CartLine> lines) => roundMoney(lines.fold(0.0, (sum, l) => sum + l.product.mrp * l.qty));

/// Replaced with the server's list as soon as it arrives.
List<Coupon> coupons = const [
  Coupon(code: 'FIRST50', title: '₹50 off your order', description: 'On orders of ₹299 or more.', minOrder: 299, flatOff: 50),
  Coupon(code: 'COOL10', title: '10% off', description: 'Up to ₹100 off on orders of ₹199 or more.', minOrder: 199, percentOff: 10, maxOff: 100),
  Coupon(code: 'FREEDEL', title: 'Free delivery', description: 'On orders of ₹149 or more.', minOrder: 149, freeDelivery: true),
  Coupon(code: 'PARTY15', title: '15% off party orders', description: 'Up to ₹300 off on orders of ₹999 or more.', minOrder: 999, percentOff: 15, maxOff: 300),
];

void applyCoupons(List<dynamic> rows) {
  coupons = [
    for (final j in rows.cast<Map<String, dynamic>>())
      Coupon(
        code: j['code'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        minOrder: (j['minOrder'] as num).toDouble(),
        flatOff: (j['flatOff'] as num).toDouble(),
        percentOff: (j['percentOff'] as num).toDouble(),
        maxOff: (j['maxOff'] as num).toDouble(),
        freeDelivery: j['freeDelivery'] as bool,
      ),
  ];
}

Coupon? couponByCode(String code) {
  for (final c in coupons) {
    if (c.code == code.trim().toUpperCase()) return c;
  }
  return null;
}

class AppliedCoupon extends Notifier<Coupon?> {
  @override
  Coupon? build() => null;

  void set(Coupon? coupon) => state = coupon;
}

final appliedCouponProvider = NotifierProvider<AppliedCoupon, Coupon?>(AppliedCoupon.new);
