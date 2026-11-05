import 'dart:async';

import 'package:customer_app/app/app.dart';
import 'package:customer_app/app/router.dart';
import 'package:customer_app/app/routes.dart';
import 'package:customer_app/core/storage/local_store.dart';
import 'package:customer_app/features/addresses/data/address_controller.dart';
import 'package:customer_app/features/addresses/domain/address.dart';
import 'package:customer_app/features/auth/data/auth_controller.dart';
import 'package:customer_app/features/cart/data/cart_controller.dart';
import 'package:customer_app/features/catalog/data/catalog_data.dart';
import 'package:customer_app/features/orders/data/orders_controller.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/planner/data/enquiries_controller.dart';
import 'package:customer_app/features/planner/domain/ice_plan.dart';
import 'package:customer_app/features/subscriptions/data/subscriptions_controller.dart';
import 'package:customer_app/features/subscriptions/domain/subscription.dart';
import 'package:customer_app/features/support/data/support_data.dart';
import 'package:customer_app/features/wallet/data/wallet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = Address(id: 'a1', label: 'Home', name: 'Asha Rao', phone: '9876500000', line: '12 Sea View', landmark: 'Near the park', city: 'Mumbai', pincode: '400053', latitude: 19.13, longitude: 72.82);

Future<ProviderContainer> _start(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': '{"seen":true}'});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CustomerApp()));
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _logIn(WidgetTester tester, ProviderContainer container) async {
  // Not awaited: its delay only passes while the test pumps frames.
  unawaited(container.read(authProvider.notifier).verifyOtp('9876500000', demoOtp));
  await _settle(tester);
  await container.read(authProvider.notifier).completeProfile(name: 'Asha Rao', email: 'asha@example.com');
  await _settle(tester);
}

/// Every page in the app, with data behind it so detail pages have something to show.
Future<List<String>> _everyPage(ProviderContainer c) async {
  c.read(addressesProvider.notifier).upsert(_home);
  c.read(cartProvider.notifier).add('cube-5', 2);
  c.read(cartProvider.notifier).add('dry-1');
  c.read(subscriptionsProvider.notifier).upsert(Subscription(id: 's1', productId: 'tube-5', qty: 2, frequency: Frequency.daily, slot: '6 AM - 9 AM', addressId: 'a1', startDate: DateTime.now()));
  c.read(enquiriesProvider.notifier).add(BulkEnquiry(id: 'e1', eventType: 'Wedding', date: DateTime.now(), quantityKg: 200, location: 'Andheri', notes: 'Evening function', at: DateTime.now()));
  final ticket = await c.read(ticketsProvider.notifier).open('A very long subject line about a late delivery', 'Order or delivery', 'Where is my ice?');
  await c.read(savedUpiProvider.notifier).add('asha@okbank');
  final orders = c.read(ordersProvider);
  final active = orders.first;
  final delivered = orders[1];
  final issue = await c.read(issuesProvider.notifier).report(delivered, IssueType.melted, 'The bag had melted', const []);
  return [
    Routes.home,
    Routes.shop,
    Routes.orders,
    Routes.wallet,
    Routes.account,
    Routes.search,
    Routes.favourites,
    Routes.serviceCheck,
    for (final cat in categories) Routes.category(cat.id),
    for (final p in products) Routes.product(p.id),
    Routes.reviews('cube-5'),
    Routes.cart,
    Routes.coupons,
    Routes.checkout,
    Routes.paymentFailed,
    Routes.orderPlaced(active.id),
    Routes.order(active.id),
    Routes.order(delivered.id),
    Routes.order(orders[3].id),
    Routes.track(active.id),
    Routes.track(delivered.id),
    Routes.bill(delivered.id),
    Routes.cancelOrder(active.id),
    Routes.rateOrder(delivered.id),
    Routes.reportIssue(delivered.id),
    Routes.issues,
    Routes.issue(issue.id),
    Routes.addresses,
    Routes.addAddress,
    Routes.editAddress('a1'),
    Routes.offers,
    Routes.offer('COOL10'),
    Routes.referral,
    Routes.rewards,
    Routes.addMoney,
    Routes.paymentMethods,
    Routes.subscriptions,
    Routes.newSubscription,
    Routes.subscription('s1'),
    Routes.editSubscription('s1'),
    Routes.planner,
    Routes.bulkEnquiry,
    Routes.enquiries,
    Routes.notifications,
    Routes.notificationSettings,
    Routes.help,
    Routes.contact,
    Routes.tickets,
    Routes.newTicket,
    Routes.ticket(ticket.id),
    Routes.editProfile,
    Routes.settings,
    Routes.stores,
    Routes.safety,
    Routes.feedback,
    Routes.about,
    Routes.deleteAccount,
    Routes.legal('terms'),
    Routes.legal('privacy'),
    Routes.legal('refunds'),
  ];
}

/// Opens each page and reports every problem found, not only the first.
Future<void> _openEveryPage(WidgetTester tester) async {
  final problems = <String>[];
  var current = 'login';
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final where = details.informationCollector?.call().map((d) => d.toString()).where((t) => t.contains('.dart')).firstOrNull ?? '';
    problems.add('$current: ${details.exceptionAsString().split(RegExp(r'[\r\n]')).first} $where');
  };
  addTearDown(() => FlutterError.onError = original);
  final container = await _start(tester);
  await _settle(tester);
  await _logIn(tester, container);
  final pages = await _everyPage(container);
  final router = container.read(routerProvider);
  for (final page in pages) {
    current = page;
    router.go(page);
    await _settle(tester);
    if (router.state.matchedLocation != page) problems.add('$page: redirected to ${router.state.matchedLocation}');
  }
  // Removes the app so its timers stop before the test ends.
  await tester.pumpWidget(const SizedBox());
  FlutterError.onError = original;
  expect(problems.toSet().toList(), isEmpty);
}

void main() {
  testWidgets('every page opens on a small phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3; // 360 x 640
    addTearDown(tester.view.reset);
    await _openEveryPage(tester);
  });

  testWidgets('every page still fits with large text', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openEveryPage(tester);
  });

  testWidgets('a new customer goes from welcome to login to their details', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CustomerApp()));
    await _settle(tester);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.text('Send OTP'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('Send OTP'));
    await _settle(tester);
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '9876500000');
    await tester.tap(find.text('Send OTP'));
    await _settle(tester);
    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.text('Verify and continue'));
    await _settle(tester);
    expect(container.read(authProvider), isNull);

    await tester.enterText(find.byType(TextFormField), demoOtp);
    await tester.tap(find.text('Verify and continue'));
    await _settle(tester);
    expect(find.text('Tell us about you'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Asha Rao');
    await tester.enterText(find.byType(TextFormField).last, 'ICE12345');
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('Do we deliver to you?'), findsOneWidget);
    expect(container.read(walletBalanceProvider), 150);

    await tester.tap(find.text('Skip for now'));
    await _settle(tester);
    expect(find.text('Hi Asha'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('placing, cancelling and refunding an order', (tester) async {
    final container = await _start(tester);
    await _settle(tester);
    await _logIn(tester, container);
    final orders = container.read(ordersProvider.notifier);
    final cart = container.read(cartProvider.notifier);
    container.read(addressesProvider.notifier).upsert(_home);

    CheckoutRequest request({Address? address = _home, String? slot = '6 PM - 9 PM', bool useWallet = true, PaymentMethod? method = PaymentMethod.upi, bool dryIceAccepted = false}) => CheckoutRequest(
      address: address,
      date: DateTime.now(),
      slot: slot,
      express: false,
      tip: 10,
      useWallet: useWallet,
      method: method,
      instructions: ' Ring twice ',
      dryIceAccepted: dryIceAccepted,
    );

    await expectLater(orders.place(request()), throwsA(hasMessage('Your cart is empty')));
    cart.add('cube-1');
    await expectLater(orders.place(request()), throwsA(hasMessage('The minimum order is ₹99')));
    cart.add('cube-5', 2);
    await expectLater(orders.place(request(address: null)), throwsA(hasMessage('Select a delivery address')));
    await expectLater(orders.place(request(slot: null)), throwsA(hasMessage('Select a delivery slot')));
    await expectLater(orders.place(request(address: const Address(id: 'x', label: '', name: '', phone: '', line: '', landmark: '', city: '', pincode: '110001', latitude: 0, longitude: 0))), throwsA(hasMessage('We do not deliver to 110001 yet')));

    cart.add('dry-1');
    await expectLater(orders.place(request()), throwsA(hasMessage('Please accept the dry ice safety note')));
    cart.setQty('dry-1', 0);

    cart.add('box-45');
    await expectLater(orders.place(request()), throwsA(hasMessage('Something in your cart is out of stock')));
    cart.setQty('box-45', 0);

    expect(container.read(walletBalanceProvider), 100);
    final order = await orders.place(request());
    expect(order.walletUsed, 100);
    expect(order.total, 39 + 298 + 49 + 10 - 100);
    expect(order.instructions, 'Ring twice');
    expect(container.read(walletBalanceProvider), 0);
    expect(container.read(cartCountProvider), 0);

    final now = DateTime.now();
    await expectLater(orders.cancel(order.id, '', now), throwsA(hasMessage('Select a reason')));
    await orders.cancel(order.id, 'Plans changed', now);
    expect(container.read(walletBalanceProvider), order.grandTotal);
    expect(orders.byId(order.id)!.statusAt(now), OrderStatus.cancelled);
    await expectLater(orders.cancel(order.id, 'Again', now), throwsA(hasMessage('This order can no longer be cancelled')));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('checking out with the real buttons, through a failed payment', (tester) async {
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = await _start(tester);
    await _settle(tester);
    await _logIn(tester, container);
    container.read(addressesProvider.notifier).upsert(_home);
    container.read(cartProvider.notifier).add('cube-5', 2);
    container.read(cartProvider.notifier).add('dry-1');
    final router = container.read(routerProvider);
    final ordersBefore = container.read(ordersProvider).length;

    router.go(Routes.cart);
    await _settle(tester);
    await tester.tap(find.textContaining('Checkout'));
    await _settle(tester);

    // Express needs no slot, so this test works at any time of day.
    await tester.tap(find.byType(Switch).first);
    await _settle(tester);
    await tester.tap(find.textContaining('Pay ₹'));
    await _settle(tester);
    expect(find.text('Please accept the dry ice safety note'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget); // still on checkout

    await tester.tap(find.byType(CheckboxListTile));
    await _settle(tester);
    await tester.tap(find.textContaining('Pay ₹'));
    await _settle(tester);

    await tester.tap(find.text('Payment fails'));
    await _settle(tester);
    expect(find.text('Your payment did not go through'), findsOneWidget);
    expect(container.read(ordersProvider).length, ordersBefore);
    expect(container.read(cartCountProvider), 3);

    await tester.tap(find.text('Back to checkout'));
    await _settle(tester);
    await tester.tap(find.textContaining('Pay ₹'));
    await _settle(tester);
    await tester.tap(find.text('Payment succeeds'));
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(find.text('Order placed!'), findsOneWidget);
    expect(container.read(ordersProvider).length, ordersBefore + 1);
    expect(container.read(cartCountProvider), 0);
    expect(container.read(ordersProvider).first.isExpress, isTrue);

    await tester.tap(find.text('Track order'));
    await _settle(tester);
    expect(find.text('Getting your ice ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the wallet, points and logging out', (tester) async {
    final container = await _start(tester);
    await _settle(tester);
    await _logIn(tester, container);
    final wallet = container.read(walletProvider.notifier);
    expect(() => wallet.spend(101, 'Too much'), throwsA(hasMessage('Not enough money in the wallet')));
    await expectLater(wallet.add(0, 'Nothing'), throwsA(hasMessage('Enter an amount above zero')));

    final points = container.read(redeemedPointsProvider.notifier);
    await expectLater(points.redeem(50, 500), throwsA(hasMessage('You need at least 100 points to redeem')));
    await expectLater(points.redeem(200, 150), throwsA(hasMessage('You do not have that many points')));
    await points.redeem(200, 500);
    expect(container.read(walletBalanceProvider), 120);

    final earned = availablePoints(container.read(ordersProvider), 0, DateTime.now());
    expect(earned, greaterThan(0));
    expect(availablePoints(container.read(ordersProvider), 100, DateTime.now()), earned - 100);

    await container.read(authProvider.notifier).logout();
    await _settle(tester);
    expect(find.text('Send OTP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deleting the account clears everything', (tester) async {
    final container = await _start(tester);
    await _settle(tester);
    await _logIn(tester, container);
    container.read(addressesProvider.notifier).upsert(_home);
    await container.read(walletProvider.notifier).add(500, 'Added money');
    await tester.runAsync(() => container.read(authProvider.notifier).deleteAccount());
    await _settle(tester);
    expect(container.read(authProvider), isNull);
    expect(container.read(addressesProvider), isEmpty);
    expect(container.read(walletBalanceProvider), 100);
    expect(find.text('Send OTP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('every product image exists', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final path in {...products.map((p) => p.image), ...categories.map((c) => c.image), 'assets/images/app_logo.png'}) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1000), reason: path);
    }
  });
}

Matcher hasMessage(String message) => isA<Object>().having((e) => '$e', 'message', message);
