import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/validators.dart';
import '../../addresses/data/address_controller.dart';
import '../../catalog/data/catalog_data.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../orders/data/orders_controller.dart';
import '../../planner/data/enquiries_controller.dart';
import '../../subscriptions/data/subscriptions_controller.dart';
import '../../support/data/support_data.dart';
import '../../wallet/data/wallet_controller.dart';
import '../domain/customer.dart';

/// The demo accepts this OTP. Sending a real SMS needs a provider on the server.
const demoOtp = '123456';

class AuthController extends Notifier<Customer?> {
  static const _key = 'session';

  LocalStore get _store => ref.read(customerStoreProvider);
  ApiClient get _api => ref.read(apiProvider);

  @override
  Customer? build() {
    final saved = ref.watch(customerStoreProvider).readMap(_key);
    if (saved == null) return null;
    if (!useFakeBackend && !ref.read(apiProvider).hasToken) return null;
    return Customer.fromJson(saved);
  }

  Future<void> sendOtp(String phone) async {
    if (!useFakeBackend) {
      await _api.post('/auth/customer/otp/send', {'phone': phone});
      return;
    }
    await fakeLatency();
    if (Validators.phone(phone) != null) throw const AppException('Enter a valid 10-digit mobile number');
  }

  Future<void> verifyOtp(String phone, String otp) async {
    if (!useFakeBackend) {
      final body = await _api.post('/auth/customer/otp/verify', {'phone': phone, 'otp': otp}) as Map<String, dynamic>;
      await _api.saveToken(body['token'] as String);
      _save(Customer.fromJson(body['user'] as Map<String, dynamic>));
      return;
    }
    await fakeLatency();
    if (otp != demoOtp) throw const AppException('That OTP is not correct. Please try again.');
    _save(Customer(phone: phone, referralCode: 'ICE${phone.substring(6)}'));
  }

  Future<void> completeProfile({required String name, required String email, String referralCode = ''}) async {
    if (!useFakeBackend) {
      final body = await _api.put('/customer/me', {'name': name, 'email': email, 'referralCode': referralCode});
      _save(Customer.fromJson(body as Map<String, dynamic>));
      return;
    }
    _save(state!.copyWith(name: name.trim(), email: email.trim()));
  }

  /// Picks up changes made elsewhere. An old session sends the customer back to log in.
  Future<void> refresh() async {
    if (useFakeBackend || state == null) return;
    try {
      _save(Customer.fromJson(await _api.get('/customer/me') as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await logout();
    }
  }

  Future<void> logout() async {
    if (useFakeBackend) {
      state = null;
      await _store.remove(_key);
      return;
    }
    await _api.clearToken();
    await _clearDevice();
  }

  Future<void> deleteAccount() async {
    if (!useFakeBackend) {
      await _api.delete('/customer/me');
      await _api.clearToken();
    }
    await _clearDevice();
  }

  /// Another customer may use this phone next, so nothing of this one stays.
  Future<void> _clearDevice() async {
    await _store.clearScope();
    ref.invalidate(customerStoreProvider);
  }

  void _save(Customer customer) {
    state = customer;
    _store.writeMap(_key, customer.toJson());
  }
}

final authProvider = NotifierProvider<AuthController, Customer?>(AuthController.new);

/// Whether the welcome slides have been seen. Kept when the customer logs out.
class OnboardingController extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() => ref.watch(localStoreProvider).readMap(_key) != null;

  void finish() {
    state = true;
    ref.read(localStoreProvider).writeMap(_key, {'seen': true});
  }
}

final onboardingProvider = NotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// Fetches everything for the signed-in customer. A failure leaves what's on the device in place.
final syncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (useFakeBackend || ref.read(authProvider) == null) return;
    final jobs = <Future<void> Function()>[
      ref.read(authProvider.notifier).refresh,
      ref.read(catalogSyncProvider),
      ref.read(addressesProvider.notifier).refresh,
      ref.read(ordersProvider.notifier).refresh,
      ref.read(issuesProvider.notifier).refresh,
      ref.read(walletProvider.notifier).refresh,
      ref.read(redeemedPointsProvider.notifier).refresh,
      ref.read(savedUpiProvider.notifier).refresh,
      ref.read(favouritesProvider.notifier).refresh,
      ref.read(notificationsProvider.notifier).refresh,
      ref.read(notificationPrefsProvider.notifier).refresh,
      ref.read(subscriptionsProvider.notifier).refresh,
      ref.read(enquiriesProvider.notifier).refresh,
      ref.read(ticketsProvider.notifier).refresh,
    ];
    await Future.wait(jobs.map((job) => job().catchError((_) {})));
  };
});
