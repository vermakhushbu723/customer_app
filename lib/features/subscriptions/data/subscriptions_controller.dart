import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../domain/subscription.dart';

/// The server places these every day, even if the customer doesn't open the app.
class SubscriptionsController extends ListStore<Subscription> {
  @override
  String get key => 'subscriptions';
  @override
  String get path => '/customer/subscriptions';
  @override
  Subscription fromJson(Json json) => Subscription.fromJson(json);
  @override
  Json toJson(Subscription item) => item.toJson();

  void _replace(Subscription sub) => save([for (final s in state) s.id == sub.id ? sub : s]);

  Future<void> upsert(Subscription sub) async {
    final exists = state.any((s) => s.id == sub.id);
    if (!useFakeBackend) {
      final body = await api.post('/customer/subscriptions', {...sub.toJson(), 'id': exists ? sub.id : null});
      final saved = Subscription.fromJson(body as Map<String, dynamic>);
      save(exists ? [for (final s in state) s.id == sub.id ? saved : s] : [saved, ...state]);
      return;
    }
    save(exists ? [for (final s in state) s.id == sub.id ? sub : s] : [sub, ...state]);
  }

  Future<void> setPaused(String id, bool paused) async {
    if (!useFakeBackend) {
      _replace(Subscription.fromJson(await api.post('/customer/subscriptions/$id/pause', {'paused': paused}) as Map<String, dynamic>));
      return;
    }
    save([for (final s in state) s.id == id ? s.copyWith(paused: paused) : s]);
  }

  /// Skips one delivery day, or brings it back if it was skipped.
  Future<void> toggleSkip(String id, DateTime day) async {
    if (!useFakeBackend) {
      _replace(Subscription.fromJson(await api.post('/customer/subscriptions/$id/skip', {'day': day.toIso8601String()}) as Map<String, dynamic>));
      return;
    }
    save([
      for (final s in state)
        if (s.id == id)
          s.copyWith(skipped: s.isSkipped(day) ? s.skipped.where((d) => !isSameDay(d, day)).toList() : [...s.skipped, day])
        else
          s,
    ]);
  }

  Future<void> remove(String id) async {
    if (!useFakeBackend) await api.delete('/customer/subscriptions/$id');
    save(state.where((s) => s.id != id).toList());
  }
}

final subscriptionsProvider = NotifierProvider<SubscriptionsController, List<Subscription>>(SubscriptionsController.new);
