import 'package:customer_app/app/router.dart';
import 'package:customer_app/app/routes.dart';
import 'package:customer_app/features/addresses/domain/address.dart';
import 'package:customer_app/features/cart/data/cart_controller.dart';
import 'package:customer_app/features/cart/domain/cart_pricing.dart';
import 'package:customer_app/features/catalog/data/catalog_data.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/planner/domain/ice_plan.dart';
import 'package:customer_app/features/subscriptions/domain/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

Order sampleOrder(DateTime placedAt, {DateTime? deliveryDate, DateTime? cancelledAt}) => Order(
  id: '1',
  number: 'ICE-1',
  lines: const [OrderLine(productId: 'cube-5', name: 'Cube Ice', pack: '5 kg bag', image: '', qty: 2, price: 149)],
  subtotal: 298,
  discount: 0,
  deliveryFee: 49,
  expressFee: 0,
  tip: 0,
  walletUsed: 47,
  total: 300,
  paymentMethod: PaymentMethod.upi,
  addressLabel: 'Home',
  addressText: 'Mumbai',
  receiverName: 'A',
  receiverPhone: '9876500000',
  latitude: 19,
  longitude: 72,
  deliveryDate: deliveryDate ?? placedAt,
  slot: '6 AM - 9 AM',
  placedAt: placedAt,
  otp: '1234',
  cancelledAt: cancelledAt,
);

void main() {
  group('bill', () {
    test('charges delivery below the free delivery amount', () {
      final bill = computeBill(mrpTotal: 350, subtotal: 300);
      expect(bill.deliveryFee, 49);
      expect(bill.total, 349);
      expect(bill.savings, 50);
    });

    test('delivers free at the free delivery amount', () {
      expect(computeBill(mrpTotal: 499, subtotal: 499).deliveryFee, 0);
    });

    test('a discount can take the order back below free delivery', () {
      final coupon = couponByCode('first50');
      expect(computeBill(mrpTotal: 500, subtotal: 500, coupon: coupon).deliveryFee, 49);
    });

    test('adds express and tip, and takes the wallet off what is left', () {
      final bill = computeBill(mrpTotal: 300, subtotal: 300, express: true, tip: 20, walletBalance: 100, useWallet: true);
      expect(bill.walletUsed, 100);
      expect(bill.total, 300 + 49 + 39 + 20 - 100);
    });

    test('the wallet never pays more than the bill', () {
      final bill = computeBill(mrpTotal: 100, subtotal: 100, walletBalance: 1000, useWallet: true);
      expect(bill.walletUsed, 149);
      expect(bill.total, 0);
    });

    test('ignores a wallet that is not switched on', () {
      expect(computeBill(mrpTotal: 100, subtotal: 100, walletBalance: 1000).walletUsed, 0);
    });
  });

  group('coupons', () {
    test('need the minimum order', () {
      final coupon = couponByCode('FIRST50')!;
      expect(couponDiscount(coupon, 298), 0);
      expect(couponProblem(coupon, 298), contains('Add ₹1 more'));
      expect(couponDiscount(coupon, 299), 50);
    });

    test('percent coupons stop at their limit', () {
      final coupon = couponByCode('COOL10')!;
      expect(couponDiscount(coupon, 200), 20);
      expect(couponDiscount(coupon, 5000), 100);
    });

    test('free delivery coupons remove only the delivery fee', () {
      final bill = computeBill(mrpTotal: 200, subtotal: 200, coupon: couponByCode('FREEDEL'));
      expect(bill.deliveryFee, 0);
      expect(bill.discount, 0);
    });

    test('unknown codes are refused', () {
      expect(couponByCode('NOPE'), isNull);
    });
  });

  group('delivery slots', () {
    test('a same-day slot closes before it starts', () {
      final labels = openSlots(DateTime(2026, 11, 4), DateTime(2026, 11, 4, 8)).map((s) => s.$2);
      expect(labels, [12, 15, 18]);
    });

    test('every slot is open on later days', () {
      expect(openSlots(DateTime(2026, 11, 5), DateTime(2026, 11, 4, 20)).length, 5);
    });

    test('none are left late at night', () {
      expect(openSlots(DateTime(2026, 11, 4), DateTime(2026, 11, 4, 20)), isEmpty);
    });
  });

  group('order', () {
    final placed = DateTime(2026, 11, 4, 10);

    test('moves through each step', () {
      final order = sampleOrder(placed);
      expect(order.statusAt(placed), OrderStatus.placed);
      expect(order.statusAt(placed.add(const Duration(minutes: 1))), OrderStatus.confirmed);
      expect(order.statusAt(placed.add(const Duration(minutes: 2))), OrderStatus.packed);
      expect(order.statusAt(placed.add(const Duration(minutes: 4))), OrderStatus.outForDelivery);
      expect(order.statusAt(placed.add(const Duration(minutes: 6))), OrderStatus.delivered);
    });

    test('a later delivery day waits at confirmed', () {
      final order = sampleOrder(placed, deliveryDate: DateTime(2026, 11, 6));
      expect(order.statusAt(DateTime(2026, 11, 5, 12)), OrderStatus.confirmed);
      expect(order.statusAt(DateTime(2026, 11, 6, 0, 2)), OrderStatus.packed);
    });

    test('can be cancelled only until it leaves', () {
      final order = sampleOrder(placed);
      expect(order.canCancelAt(placed.add(const Duration(minutes: 2))), isTrue);
      expect(order.canCancelAt(placed.add(const Duration(minutes: 3))), isFalse);
      expect(order.canCancelAt(placed.add(const Duration(minutes: 8))), isFalse);
    });

    test('a cancelled order stays cancelled and cannot be cancelled again', () {
      final order = sampleOrder(placed, cancelledAt: placed.add(const Duration(minutes: 1)));
      final later = placed.add(const Duration(hours: 1));
      expect(order.statusAt(later), OrderStatus.cancelled);
      expect(order.isActiveAt(later), isFalse);
      expect(order.canCancelAt(placed), isFalse);
    });

    test('the rider moves along the road and the ETA counts down', () {
      final order = sampleOrder(placed);
      final halfway = placed.add(const Duration(minutes: 4, seconds: 30));
      expect(order.tripProgressAt(halfway), closeTo(0.5, 0.01));
      expect(order.etaMinutesAt(halfway), 2);
      expect(order.tripProgressAt(placed), 0);
      expect(order.tripProgressAt(placed.add(const Duration(hours: 1))), 1);
    });

    test('survives being saved and read back', () {
      final order = sampleOrder(placed);
      final copy = Order.fromJson(order.toJson());
      expect(copy.grandTotal, 347);
      expect(copy.lines.first.amount, 298);
      expect(copy.paymentMethod, PaymentMethod.upi);
    });
  });

  group('subscription', () {
    final start = DateTime(2026, 11, 2);
    Subscription sub(Frequency frequency) => Subscription(id: '1', productId: 'tube-5', qty: 1, frequency: frequency, slot: '', addressId: '', startDate: start);

    test('lists days at its frequency, from today', () {
      final days = sub(Frequency.alternate).upcoming(DateTime(2026, 11, 5), count: 3);
      expect(days, [DateTime(2026, 11, 6), DateTime(2026, 11, 8), DateTime(2026, 11, 10)]);
    });

    test('next delivery passes over a skipped day', () {
      final s = sub(Frequency.daily).copyWith(skipped: [DateTime(2026, 11, 5)]);
      expect(s.nextDelivery(DateTime(2026, 11, 5, 9)), DateTime(2026, 11, 6));
    });

    test('has no next delivery while paused', () {
      expect(sub(Frequency.daily).copyWith(paused: true).nextDelivery(start), isNull);
    });

    test('keeps calendar days across a clock change', () {
      final days = sub(Frequency.weekly).upcoming(start, count: 3);
      expect(days.every((d) => d.hour == 0), isTrue);
    });
  });

  group('ice planner', () {
    test('half a kilo a guest for a short indoor party', () {
      expect(iceNeededKg(guests: 20, hours: 3, hotDay: false, coolingDrinks: false), 10);
    });

    test('needs more for a long, hot day with bottles to chill', () {
      expect(iceNeededKg(guests: 20, hours: 5, hotDay: true, coolingDrinks: true), 28);
    });

    test('never suggests a pack that is too small in total', () {
      for (final kg in [1, 3, 7, 19, 21, 44, 101]) {
        final plan = packsFor(kg, const [2, 5, 20]);
        final total = plan.entries.fold(0, (sum, e) => sum + e.key * e.value);
        expect(total, greaterThanOrEqualTo(kg));
      }
    });

    test('only suggests ice that is fit for drinks', () {
      for (final p in productsIn('tube')) {
        expect(p.forDrinks, isTrue);
        expect(p.warning, isNull);
      }
    });
  });

  group('catalog', () {
    test('ice that is not for drinks carries a warning', () {
      for (final p in products.where((p) => const {'crushed', 'block', 'slab', 'dry'}.contains(p.categoryId))) {
        expect(p.forDrinks, isFalse, reason: p.id);
        expect(p.warning, isNotNull, reason: p.id);
      }
    });

    test('search finds uses as well as names', () {
      expect(searchProducts('wedding').map((p) => p.id), contains('cube-20'));
      expect(searchProducts('DRY').every((p) => p.isDryIce), isTrue);
      expect(searchProducts('   '), isEmpty);
    });

    test('every product belongs to a real category and has a fair price', () {
      for (final p in products) {
        expect(categoryById(p.categoryId).id, p.categoryId);
        expect(p.price, lessThanOrEqualTo(p.mrp));
      }
    });
  });

  test('delivery area goes by PIN code', () {
    expect(deliversTo('400053'), isTrue);
    expect(deliversTo('110001'), isFalse);
  });

  group('where the customer is sent', () {
    String? go(String location, {bool onboarded = true, bool loggedIn = true, bool complete = true}) =>
        redirectFor(onboarded: onboarded, loggedIn: loggedIn, profileComplete: complete, location: location);

    test('a first-time visitor sees the welcome slides', () {
      expect(go(Routes.home, onboarded: false, loggedIn: false, complete: false), Routes.onboarding);
    });

    test('logged out people are sent to log in', () {
      expect(go(Routes.cart, loggedIn: false, complete: false), Routes.login);
      expect(go(Routes.otp, loggedIn: false, complete: false), isNull);
    });

    test('legal pages open without an account', () {
      expect(go(Routes.legal('terms'), onboarded: false, loggedIn: false, complete: false), isNull);
    });

    test('a new customer must give their name first', () {
      expect(go(Routes.home, complete: false), Routes.completeProfile);
    });

    test('a logged in customer skips the login pages', () {
      expect(go(Routes.login), Routes.home);
      expect(go(Routes.cart), isNull);
    });
  });
}
