import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/addresses/presentation/address_screens.dart';
import '../features/auth/data/auth_controller.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/cart/presentation/cart_screens.dart';
import '../features/cart/presentation/checkout_screens.dart';
import '../features/catalog/presentation/catalog_screens.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notification_screens.dart';
import '../features/offers/presentation/offer_screens.dart';
import '../features/orders/data/orders_controller.dart';
import '../features/orders/presentation/order_screens.dart';
import '../features/planner/presentation/planner_screens.dart';
import '../features/profile/presentation/profile_screens.dart';
import '../features/subscriptions/presentation/subscription_screens.dart';
import '../features/support/presentation/support_screens.dart';
import '../features/wallet/presentation/wallet_screens.dart';
import 'app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Pages anyone can read before logging in.
bool _isPublicPage(String location) => location.startsWith('/legal/');

/// Where the customer must be for their account state, or null if they may stay.
String? redirectFor({required bool onboarded, required bool loggedIn, required bool profileComplete, required String location}) {
  if (_isPublicPage(location)) return null;
  if (!loggedIn) {
    if (!onboarded) return location == Routes.onboarding ? null : Routes.onboarding;
    return location == Routes.login || location == Routes.otp ? null : Routes.login;
  }
  if (!profileComplete) return location == Routes.completeProfile ? null : Routes.completeProfile;
  const outside = {Routes.onboarding, Routes.login, Routes.otp, Routes.completeProfile};
  return outside.contains(location) ? Routes.home : null;
}

GoRoute _page(String path, Widget Function(GoRouterState state) builder) =>
    GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (_, state) => builder(state));

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(onboardingProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (_, state) {
      final customer = ref.read(authProvider);
      final target = redirectFor(
        onboarded: ref.read(onboardingProvider),
        loggedIn: customer != null,
        profileComplete: customer?.profileComplete ?? false,
        location: state.matchedLocation,
      );
      if (target != null || state.extra != null) return target;
      // A page reload on the web loses what these two pages were opened with.
      if (state.matchedLocation == Routes.otp) return Routes.login;
      if (state.matchedLocation == Routes.payment) return Routes.checkout;
      return null;
    },
    routes: [
      _page(Routes.onboarding, (_) => const OnboardingScreen()),
      _page(Routes.login, (_) => const LoginScreen()),
      _page(Routes.otp, (s) => OtpScreen(phone: s.extra as String? ?? '')),
      _page(Routes.completeProfile, (_) => const CompleteProfileScreen()),
      _page(Routes.serviceCheck, (_) => const ServiceCheckScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _tab(Routes.home, const HomeScreen()),
          _tab(Routes.shop, const ShopScreen()),
          _tab(Routes.orders, const OrdersScreen()),
          _tab(Routes.wallet, const WalletScreen()),
          _tab(Routes.account, const AccountScreen()),
        ],
      ),
      _page(Routes.search, (_) => const SearchScreen()),
      _page(Routes.favourites, (_) => const FavouritesScreen()),
      _page('/category/:id', (s) => CategoryScreen(categoryId: s.pathParameters['id']!)),
      _page('/product/:id', (s) => ProductScreen(productId: s.pathParameters['id']!)),
      _page('/product/:id/reviews', (s) => ReviewsScreen(productId: s.pathParameters['id']!)),
      _page(Routes.cart, (_) => const CartScreen()),
      _page(Routes.coupons, (_) => const CouponsScreen()),
      _page(Routes.checkout, (_) => const CheckoutScreen()),
      _page(Routes.payment, (s) {
        final args = s.extra! as ({CheckoutRequest request, double amount});
        return PaymentScreen(request: args.request, amount: args.amount);
      }),
      _page(Routes.paymentFailed, (_) => const PaymentFailedScreen()),
      _page('/order-placed/:id', (s) => OrderPlacedScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id', (s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id/track', (s) => TrackOrderScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id/bill', (s) => BillScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id/cancel', (s) => CancelOrderScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id/rate', (s) => RateOrderScreen(orderId: s.pathParameters['id']!)),
      _page('/orders/:id/report', (s) => ReportIssueScreen(orderId: s.pathParameters['id']!)),
      _page(Routes.issues, (_) => const IssuesScreen()),
      _page('/order-issues/:id', (s) => IssueDetailScreen(issueId: s.pathParameters['id']!)),
      _page(Routes.addresses, (_) => const AddressesScreen()),
      _page(Routes.addAddress, (_) => const AddressFormScreen()),
      _page('/addresses/:id', (s) => AddressFormScreen(addressId: s.pathParameters['id'])),
      _page(Routes.offers, (_) => const OffersScreen()),
      _page('/offers/:code', (s) => OfferDetailScreen(code: s.pathParameters['code']!)),
      _page(Routes.referral, (_) => const ReferralScreen()),
      _page(Routes.rewards, (_) => const RewardsScreen()),
      _page(Routes.addMoney, (_) => const AddMoneyScreen()),
      _page(Routes.paymentMethods, (_) => const PaymentMethodsScreen()),
      _page(Routes.subscriptions, (_) => const SubscriptionsScreen()),
      _page(Routes.newSubscription, (s) => SubscriptionFormScreen(productId: s.extra as String?)),
      _page('/subscriptions/:id', (s) => SubscriptionDetailScreen(subscriptionId: s.pathParameters['id']!)),
      _page('/subscriptions/:id/edit', (s) => SubscriptionFormScreen(subscriptionId: s.pathParameters['id'])),
      _page(Routes.planner, (_) => const PlannerScreen()),
      _page(Routes.bulkEnquiry, (s) => BulkEnquiryScreen(quantityKg: s.extra as int?)),
      _page(Routes.enquiries, (_) => const EnquiriesScreen()),
      _page(Routes.notifications, (_) => const NotificationsScreen()),
      _page(Routes.notificationSettings, (_) => const NotificationSettingsScreen()),
      _page(Routes.help, (_) => const HelpScreen()),
      _page(Routes.contact, (_) => const ContactScreen()),
      _page(Routes.tickets, (_) => const TicketsScreen()),
      _page(Routes.newTicket, (_) => const NewTicketScreen()),
      _page('/tickets/:id', (s) => TicketDetailScreen(ticketId: s.pathParameters['id']!)),
      _page(Routes.editProfile, (_) => const EditProfileScreen()),
      _page(Routes.settings, (_) => const SettingsScreen()),
      _page(Routes.stores, (_) => const StoresScreen()),
      _page(Routes.safety, (_) => const SafetyScreen()),
      _page(Routes.feedback, (_) => const FeedbackScreen()),
      _page(Routes.about, (_) => const AboutScreen()),
      _page(Routes.deleteAccount, (_) => const DeleteAccountScreen()),
      _page('/legal/:page', (s) => LegalScreen(page: s.pathParameters['page']!)),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
