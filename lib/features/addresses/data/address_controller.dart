import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../domain/address.dart';

class AddressController extends ListStore<Address> {
  @override
  String get key => 'addresses';
  @override
  String get path => '/customer/addresses';
  @override
  Address fromJson(Json json) => Address.fromJson(json);
  @override
  Json toJson(Address item) => item.toJson();

  /// Adds or updates an address. The first one saved becomes the default.
  Future<void> upsert(Address address) async {
    if (!useFakeBackend) {
      saveJson(await api.post('/customer/addresses', address.toJson()));
      return;
    }
    final exists = state.any((a) => a.id == address.id);
    final saved = state.isEmpty ? address.copyWith(isDefault: true) : address;
    var next = exists ? [for (final a in state) a.id == address.id ? saved : a] : [...state, saved];
    if (saved.isDefault) next = [for (final a in next) a.copyWith(isDefault: a.id == saved.id)];
    save(next);
  }

  Future<void> setDefault(String id) async {
    if (!useFakeBackend) {
      saveJson(await api.post('/customer/addresses/$id/default'));
      return;
    }
    save([for (final a in state) a.copyWith(isDefault: a.id == id)]);
  }

  /// Removing the default passes that role to the next address.
  Future<void> remove(String id) async {
    if (!useFakeBackend) {
      saveJson(await api.delete('/customer/addresses/$id'));
      return;
    }
    final removedDefault = state.any((a) => a.id == id && a.isDefault);
    final next = state.where((a) => a.id != id).toList();
    if (removedDefault && next.isNotEmpty) next[0] = next[0].copyWith(isDefault: true);
    save(next);
  }
}

final addressesProvider = NotifierProvider<AddressController, List<Address>>(AddressController.new);

final defaultAddressProvider = Provider<Address?>((ref) {
  final addresses = ref.watch(addressesProvider);
  if (addresses.isEmpty) return null;
  return addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
});
