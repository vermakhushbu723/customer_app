@Tags(['contract'])
library;

import 'package:customer_app/core/network/api_client.dart';
import 'package:customer_app/core/storage/local_store.dart';
import 'package:customer_app/features/addresses/data/address_controller.dart';
import 'package:customer_app/features/addresses/domain/address.dart';
import 'package:customer_app/features/auth/data/auth_controller.dart';
import 'package:customer_app/features/cart/data/cart_controller.dart';
import 'package:customer_app/features/catalog/data/catalog_data.dart';
import 'package:customer_app/features/notifications/data/notifications_controller.dart';
import 'package:customer_app/features/orders/data/orders_controller.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/planner/data/enquiries_controller.dart';
import 'package:customer_app/features/planner/domain/ice_plan.dart';
import 'package:customer_app/features/subscriptions/data/subscriptions_controller.dart';
import 'package:customer_app/features/subscriptions/domain/subscription.dart';
import 'package:customer_app/features/support/data/support_data.dart';
import 'package:customer_app/features/wallet/data/wallet_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the app's real data code against a real server. See the dealer app's test for how to run it.
void main() {
  const home = Address(id: 'home', label: 'Home', name: 'Asha', phone: '9812500001', line: '12 Sea View', landmark: 'Near the park', city: 'Mumbai', pincode: '400053', latitude: 19.13, longitude: 72.82);

  late ProviderContainer c;
  late ApiClient adminApi;
  late ApiClient riderApi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    adminApi = ApiClient(LocalStore(prefs, scope: 'admin'));
    riderApi = ApiClient(LocalStore(prefs, scope: 'rider'));
    final admin = await adminApi.post('/auth/admin/login', {'email': 'admin@iceclub.online', 'password': 'Admin@1234'}) as Map<String, dynamic>;
    await adminApi.saveToken(admin['token'] as String);
    final rider = await riderApi.post('/auth/rider/login', {'phone': '9000000001', 'password': 'Rider@1234'}) as Map<String, dynamic>;
    await riderApi.saveToken(rider['token'] as String);
  });

  tearDownAll(() => c.dispose());

  CheckoutRequest request({PaymentMethod method = PaymentMethod.upi, bool useWallet = false, double tip = 0}) => CheckoutRequest(
    address: c.read(defaultAddressProvider),
    date: DateTime.now().add(const Duration(days: 1)),
    slot: '9 AM - 12 PM',
    express: false,
    tip: tip,
    useWallet: useWallet,
    method: method,
    instructions: 'Ring twice',
    dryIceAccepted: false,
  );

  test('a customer from sign up to a delivered order', () async {
    final auth = c.read(authProvider.notifier);
    await auth.sendOtp('9812500001');
    await expectLater(auth.verifyOtp('9812500001', '000000'), throwsA(isA<ApiException>()));
    await auth.verifyOtp('9812500001', '123456');
    expect(c.read(authProvider)!.profileComplete, isFalse);
    await auth.completeProfile(name: 'Asha Rao', email: 'asha@example.com');
    expect(c.read(authProvider)!.name, 'Asha Rao');
    expect(c.read(authProvider)!.referralCode, isNotEmpty);

    await c.read(syncProvider)();
    expect(products.any((p) => p.id == 'tube-5' && p.inStock), isTrue);
    expect(coupons.map((x) => x.code), contains('COOL10'));
    expect(c.read(walletBalanceProvider), 100);

    await c.read(addressesProvider.notifier).upsert(home);
    expect(c.read(defaultAddressProvider)!.id, 'home');
    await c.read(addressesProvider.notifier).upsert(const Address(id: 'work', label: 'Work', name: 'Asha', phone: '9812500001', line: '1 Office', landmark: '', city: 'Mumbai', pincode: '400001', latitude: 0, longitude: 0));
    await c.read(addressesProvider.notifier).setDefault('work');
    await c.read(addressesProvider.notifier).setDefault('home');
    await c.read(addressesProvider.notifier).remove('work');
    expect(c.read(addressesProvider).length, 1);

    await c.read(favouritesProvider.notifier).toggle('tube-5');
    await c.read(favouritesProvider.notifier).refresh();
    expect(c.read(favouritesProvider), contains('tube-5'));
    expect(await c.read(productReviewsProvider('tube-5').future), isNotEmpty);

    // The app's own bill has to match what the server charges, coupon and wallet included.
    final orders = c.read(ordersProvider.notifier);
    c.read(cartProvider.notifier).add('tube-5', 3);
    c.read(appliedCouponProvider.notifier).set(couponByCode('FIRST50'));
    final paid = await orders.place(request(useWallet: true, tip: 10));
    expect(paid.walletUsed, 100);
    expect(paid.discount, 50);
    expect(paid.total, 387 - 50 + 49 + 10 - 100);
    expect(paid.statusAt(DateTime.now()), OrderStatus.placed);
    expect(paid.instructions, 'Ring twice');
    expect(c.read(cartCountProvider), 0);
    expect(c.read(walletBalanceProvider), 0);

    await orders.cancel(paid.id, 'Plans changed', DateTime.now());
    expect(orders.byId(paid.id)!.statusAt(DateTime.now()), OrderStatus.cancelled);
    expect(c.read(walletBalanceProvider), 396, reason: 'wallet and online money both come back');

    c.read(cartProvider.notifier).add('cube-5', 2);
    final cod = await orders.place(request(method: PaymentMethod.cod));
    expect(cod.total, 298 + 49);
    expect(cod.otp.length, 4);

    // Staff and the rider take it from here.
    await adminApi.post('/admin/actions/advanceOrder', {'args': [cod.id]});
    await orders.refresh();
    expect(orders.byId(cod.id)!.statusAt(DateTime.now()), OrderStatus.confirmed);
    await adminApi.post('/admin/actions/advanceOrder', {'args': [cod.id]});
    await adminApi.post('/admin/actions/advanceOrder', {'args': [cod.id]});
    await orders.refresh();
    expect(orders.byId(cod.id)!.statusAt(DateTime.now()), OrderStatus.packed);
    expect(orders.byId(cod.id)!.canCancelAt(DateTime.now()), isTrue);
    await adminApi.post('/admin/actions/assignRider', {'args': [cod.id, 'R1']});
    await riderApi.post('/rider/orders/${cod.id}/accept');
    await riderApi.post('/rider/orders/${cod.id}/pickup');
    await orders.refresh();
    expect(orders.byId(cod.id)!.canCancelAt(DateTime.now()), isFalse);
    await riderApi.post('/rider/orders/${cod.id}/start');
    await riderApi.post('/rider/tracking/points', {'location': {'latitude': 19.12, 'longitude': 72.83}});
    await orders.refresh();
    final moving = orders.byId(cod.id)!;
    expect(moving.statusAt(DateTime.now()), OrderStatus.outForDelivery);
    expect(moving.riderName, isNotEmpty);
    final tracking = await c.read(apiProvider).get('/customer/orders/${cod.id}/tracking') as Map<String, dynamic>;
    expect((tracking['rider'] as Map)['latitude'], 19.12);
    await riderApi.post('/rider/orders/${cod.id}/complete', {'otp': cod.otp, 'mode': 'cash'});
    await orders.refresh();
    final delivered = orders.byId(cod.id)!;
    expect(delivered.statusAt(DateTime.now()), OrderStatus.delivered);
    expect(delivered.timeOf(OrderStatus.delivered).isAfter(delivered.placedAt), isTrue);

    await orders.rate(cod.id, delivery: 5, product: 4, text: 'Nice ice');
    expect(orders.byId(cod.id)!.productRating, 4);

    final issue = await c.read(issuesProvider.notifier).report(delivered, IssueType.melted, 'Half melted', const []);
    await adminApi.post('/admin/actions/decideComplaint', {'args': [issue.id, true, 'Sorry', 50]});
    await c.read(issuesProvider.notifier).refresh();
    expect(c.read(issuesProvider).first.status, 'approved');
    expect(c.read(issuesProvider).first.creditAmount, 50);

    final wallet = c.read(walletProvider.notifier);
    await wallet.refresh();
    final balance = c.read(walletBalanceProvider);
    await wallet.add(200, 'Added money');
    expect(c.read(walletBalanceProvider), balance + 200);

    await c.read(redeemedPointsProvider.notifier).refresh();
    final points = availablePoints(c.read(ordersProvider), 0, DateTime.now());
    expect(points, 34);
    await expectLater(c.read(redeemedPointsProvider.notifier).redeem(points, points), throwsA(isA<ApiException>()));

    final upi = c.read(savedUpiProvider.notifier);
    await upi.add('asha@okbank');
    expect(c.read(savedUpiProvider), contains('asha@okbank'));
    await upi.remove('asha@okbank');

    final subs = c.read(subscriptionsProvider.notifier);
    await subs.upsert(Subscription(id: 'local', productId: 'tube-5', qty: 2, frequency: Frequency.alternate, slot: '9 AM - 12 PM', addressId: 'home', startDate: DateTime.now().add(const Duration(days: 1))));
    final sub = c.read(subscriptionsProvider).single;
    await subs.upsert(sub.copyWith(qty: 3));
    expect(c.read(subscriptionsProvider).single.qty, 3);
    await subs.setPaused(sub.id, true);
    expect(c.read(subscriptionsProvider).single.paused, isTrue);
    await subs.setPaused(sub.id, false);
    final day = sub.upcoming(DateTime.now()).first;
    await subs.toggleSkip(sub.id, day);
    expect(c.read(subscriptionsProvider).single.isSkipped(day), isTrue);
    await subs.toggleSkip(sub.id, day);
    await subs.remove(sub.id);
    expect(c.read(subscriptionsProvider), isEmpty);

    await c.read(enquiriesProvider.notifier).add(BulkEnquiry(id: 'x', eventType: 'Wedding', date: DateTime.now().add(const Duration(days: 9)), quantityKg: 200, location: 'Andheri', notes: 'Evening', at: DateTime.now()));
    final enquiry = c.read(enquiriesProvider).single;
    await adminApi.post('/admin/actions/quoteEnquiry', {'args': [enquiry.id, '₹5 per kg']});
    await c.read(enquiriesProvider.notifier).refresh();
    expect(c.read(enquiriesProvider).single.status, EnquiryStatus.quoted);
    expect(c.read(enquiriesProvider).single.quote, '₹5 per kg');

    final notes = c.read(notificationsProvider.notifier);
    await notes.refresh();
    expect(c.read(notificationsProvider), isNotEmpty);
    await notes.markRead(c.read(notificationsProvider).first.id);
    await notes.markAllRead();
    await notes.remove(c.read(notificationsProvider).first.id);
    await c.read(notificationPrefsProvider.notifier).set('Order updates', false);
    await c.read(notificationPrefsProvider.notifier).refresh();
    expect(c.read(notificationPrefsProvider)['Order updates'], isFalse);

    final tickets = c.read(ticketsProvider.notifier);
    final ticket = await tickets.open('Hi', 'Account', 'Help');
    expect(ticket.messages.first.fromCustomer, isTrue);
    await tickets.reply(ticket.id, 'More');
    await tickets.close(ticket.id);
    await tickets.refresh();
    expect(c.read(ticketsProvider).first.closed, isTrue);

    await auth.deleteAccount();
    expect(c.read(authProvider), isNull);
    expect(c.read(addressesProvider), isEmpty, reason: 'nothing of this customer stays on the phone');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
