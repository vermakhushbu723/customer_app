import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../domain/wallet.dart';

class WalletController extends ListStore<WalletEntry> {
  @override
  String get key => 'wallet';
  @override
  String get path => '/customer/wallet';
  @override
  WalletEntry fromJson(Json json) => WalletEntry.fromJson(json);
  @override
  Json toJson(WalletEntry item) => item.toJson();

  @override
  List<WalletEntry> seed() => [
    WalletEntry(id: 'welcome', amount: 100, title: 'Welcome bonus', at: DateTime.now().subtract(const Duration(days: 20))),
  ];

  Future<void> add(double amount, String title) async {
    if (!useFakeBackend) {
      await api.post('/customer/wallet/add', {'amount': amount});
      await refresh();
      return;
    }
    if (amount <= 0) throw const AppException('Enter an amount above zero');
    save([WalletEntry(id: DateTime.now().microsecondsSinceEpoch.toString(), amount: amount, title: title, at: DateTime.now()), ...state]);
  }

  /// Without a server only. On the server, an order takes its wallet money itself.
  void spend(double amount, String title) {
    if (amount <= 0) return;
    if (amount > balanceOf(state)) throw const AppException('Not enough money in the wallet');
    save([WalletEntry(id: DateTime.now().microsecondsSinceEpoch.toString(), amount: -amount, title: title, at: DateTime.now()), ...state]);
  }
}

double balanceOf(List<WalletEntry> entries) => roundMoney(entries.fold(0.0, (sum, e) => sum + e.amount));

final walletProvider = NotifierProvider<WalletController, List<WalletEntry>>(WalletController.new);

final walletBalanceProvider = Provider<double>((ref) => balanceOf(ref.watch(walletProvider)));

/// Points already redeemed. Points earned come from delivered orders.
class RedeemedPoints extends ListStore<RewardEntry> {
  @override
  String get key => 'redeemed_points';
  @override
  RewardEntry fromJson(Json json) => RewardEntry.fromJson(json);
  @override
  Json toJson(RewardEntry item) => item.toJson();

  @override
  Future<void> refresh() async {
    if (useFakeBackend) return;
    saveJson((await api.get('/customer/rewards') as Map<String, dynamic>)['redeemed']);
  }

  Future<void> redeem(int points, int available) async {
    if (!useFakeBackend) {
      await api.post('/customer/rewards/redeem', {'points': points});
      await refresh();
      await ref.read(walletProvider.notifier).refresh();
      return;
    }
    if (points < AppConstants.pointsToRedeem) {
      throw AppException('You need at least ${AppConstants.pointsToRedeem} points to redeem');
    }
    if (points > available) throw const AppException('You do not have that many points');
    save([RewardEntry(points: points, at: DateTime.now()), ...state]);
    await ref.read(walletProvider.notifier).add(roundMoney(points * AppConstants.rupeesPerPoint), 'Redeemed $points reward points');
  }
}

final redeemedPointsProvider = NotifierProvider<RedeemedPoints, List<RewardEntry>>(RedeemedPoints.new);

class SavedUpi extends Notifier<List<String>> {
  static const _key = 'saved_upi';

  @override
  List<String> build() {
    final saved = ref.watch(customerStoreProvider).readMap(_key);
    return saved == null ? [] : (saved['ids'] as List).cast<String>();
  }

  ApiClient get _api => ref.read(apiProvider);

  Future<void> refresh() async {
    if (useFakeBackend) return;
    _save(((await _api.get('/customer/saved-upi')) as List).cast<String>());
  }

  Future<void> add(String id) async {
    if (!useFakeBackend) {
      await _api.post('/customer/saved-upi', {'id': id});
      await refresh();
      return;
    }
    if (state.contains(id)) throw const AppException('That UPI ID is already saved');
    _save([...state, id]);
  }

  Future<void> remove(String id) async {
    if (!useFakeBackend) await _api.delete('/customer/saved-upi/${Uri.encodeComponent(id)}');
    _save(state.where((x) => x != id).toList());
  }

  void _save(List<String> next) {
    state = next;
    ref.read(customerStoreProvider).writeMap(_key, {'ids': next});
  }
}

final savedUpiProvider = NotifierProvider<SavedUpi, List<String>>(SavedUpi.new);
