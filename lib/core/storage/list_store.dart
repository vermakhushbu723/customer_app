import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'local_store.dart';

/// Everything this app keeps on the device, as a copy of what is on the server.
final customerStoreProvider = Provider<LocalStore>((ref) => ref.watch(localStoreProvider).scoped('customer'));

/// A list of records from the server, kept on the device so screens open instantly.
/// In tests there is no server, so [seed] fills it instead and changes stay on the device.
abstract class ListStore<T> extends Notifier<List<T>> {
  String get key;
  T fromJson(Json json);
  Json toJson(T item);
  List<T> seed() => const [];

  /// Where the list comes from on the server.
  String? get path => null;

  LocalStore get store => ref.read(customerStoreProvider);
  ApiClient get api => ref.read(apiProvider);

  @override
  List<T> build() {
    final saved = ref.watch(customerStoreProvider).readList(key);
    if (saved != null) return saved.map(fromJson).toList();
    return useFakeBackend ? seed() : const [];
  }

  void save(List<T> items) {
    state = items;
    store.writeList(key, items.map(toJson).toList());
  }

  void saveJson(dynamic rows) => save((rows as Object).mapped(fromJson));

  /// Brings in the latest from the server.
  Future<void> refresh() async {
    if (useFakeBackend || path == null) return;
    saveJson(await api.get(path!));
  }
}
