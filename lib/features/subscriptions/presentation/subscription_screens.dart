import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../addresses/data/address_controller.dart';
import '../../catalog/data/catalog_data.dart';
import '../data/subscriptions_controller.dart';
import '../domain/subscription.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSubscription),
        icon: const Icon(Icons.add),
        label: const Text('New subscription'),
      ),
      body: subs.isEmpty
          ? const EmptyState(icon: Icons.autorenew, title: 'No subscriptions yet', message: 'Get ice delivered regularly, without placing an order each time.')
          : ListView(
              padding: AppSpacing.pageWithFab,
              children: [
                for (final s in subs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppCard(
                      onTap: () => context.push(Routes.subscription(s.id)),
                      child: Builder(
                        builder: (context) {
                          final p = productById(s.productId);
                          final next = s.nextDelivery(now);
                          return Row(
                            children: [
                              if (p != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: Image.asset(p.image, height: 52, width: 52, fit: BoxFit.cover),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${p?.name}, ${p?.pack} × ${s.qty}', style: Theme.of(context).textTheme.labelLarge),
                                    Text(s.frequency.label, style: Theme.of(context).textTheme.bodySmall),
                                    Text(next == null ? 'Paused' : 'Next: ${formatDateShort(next)}', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              StatusChip(s.paused ? 'Paused' : 'Active', color: s.paused ? AppColors.amber600 : AppColors.green700),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({super.key, this.subscriptionId, this.productId});

  final String? subscriptionId;
  final String? productId;

  @override
  ConsumerState<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends ConsumerState<SubscriptionFormScreen> {
  final _form = GlobalKey<FormState>();
  Subscription? _existing;
  String? _productId;
  int _qty = 1;
  Frequency _frequency = Frequency.daily;
  String? _slot;
  String? _addressId;
  DateTime _start = dateOnly(DateTime.now()).add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    final matches = ref.read(subscriptionsProvider).where((s) => s.id == widget.subscriptionId);
    _existing = matches.isEmpty ? null : matches.first;
    _productId = _existing?.productId ?? widget.productId;
    _qty = _existing?.qty ?? 1;
    _frequency = _existing?.frequency ?? Frequency.daily;
    _slot = _existing?.slot;
    _addressId = _existing?.addressId ?? ref.read(defaultAddressProvider)?.id;
    _start = _existing?.startDate ?? _start;
  }

  Future<void> _pickStart() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: _start.isBefore(today) ? today : _start, firstDate: today, lastDate: today.add(const Duration(days: 90)));
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final next = (_existing ?? Subscription(id: DateTime.now().millisecondsSinceEpoch.toString(), productId: _productId!, qty: _qty, frequency: _frequency, slot: _slot!, addressId: _addressId!, startDate: _start)).copyWith(
      qty: _qty,
      frequency: _frequency,
      slot: _slot,
      addressId: _addressId,
      startDate: _start,
    );
    try {
      await ref.read(subscriptionsProvider.notifier).upsert(next);
      if (!mounted) return;
      showMessage(context, 'Subscription saved');
      context.pop();
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final price = (productById(_productId ?? '')?.price ?? 0) * _qty;
    final addressOk = addresses.any((a) => a.id == _addressId);
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'New subscription' : 'Edit subscription')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown<String>(
                label: 'Product',
                value: _productId,
                items: {for (final p in products.where((p) => p.subscribable && p.inStock)) p.id: '${p.name}, ${p.pack}'},
                onChanged: (v) => setState(() => _productId = v),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              LabeledField(
                label: 'Quantity',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: QuantityStepper(value: _qty, max: 50, onChanged: (v) => setState(() => _qty = v)),
                ),
              ),
              const SizedBox(height: 14),
              AppDropdown<Frequency>(
                label: 'How often',
                value: _frequency,
                items: {for (final f in Frequency.values) f: f.label},
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              AppDropdown<String>(
                label: 'Delivery slot',
                value: _slot,
                items: {for (final s in AppConstants.deliverySlots) s.$1: s.$1},
                onChanged: (v) => setState(() => _slot = v),
                validator: (v) => v == null ? 'Select a delivery slot' : null,
              ),
              if (addresses.isEmpty) ...[
                OutlinedButton.icon(icon: const Icon(Icons.add_location_alt_outlined, size: 18), label: const Text('Add a delivery address'), onPressed: () => context.push(Routes.addAddress)),
                const SizedBox(height: 14),
              ] else
                AppDropdown<String>(
                  label: 'Delivery address',
                  value: addressOk ? _addressId : null,
                  items: {for (final a in addresses) a.id: '${a.label}, ${a.line}'},
                  onChanged: (v) => setState(() => _addressId = v),
                  validator: (v) => v == null ? 'Select a delivery address' : null,
                ),
              LabeledField(
                label: 'Start date',
                child: OutlinedButton.icon(onPressed: _pickStart, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(formatDateShort(_start))),
              ),
              const SizedBox(height: 14),
              if (price > 0) ...[
                NoticeBanner('${money(price)} per delivery, plus any delivery fee. You pay when it arrives.', color: AppColors.sky700),
                const SizedBox(height: 14),
              ],
              FilledButton(onPressed: addresses.isEmpty ? null : _save, child: const Text('Save subscription')),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionDetailScreen extends ConsumerWidget {
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(subscriptionsProvider).where((s) => s.id == subscriptionId);
    if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Subscription not found'));
    final s = matches.first;
    final p = productById(s.productId);
    final address = ref.watch(addressesProvider).where((a) => a.id == s.addressId);
    final controller = ref.read(subscriptionsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push(Routes.editSubscription(s.id)))],
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            child: Column(
              children: [
                InfoRow('Product', '${p?.name}, ${p?.pack}'),
                InfoRow('Quantity', '${s.qty}'),
                InfoRow('How often', s.frequency.label),
                InfoRow('Slot', s.slot),
                InfoRow('Deliver to', address.isEmpty ? 'Address removed' : address.first.singleLine, valueColor: address.isEmpty ? AppColors.red600 : null),
                InfoRow('Per delivery', money((p?.price ?? 0) * s.qty)),
                InfoRow('Status', s.paused ? 'Paused' : 'Active', valueColor: s.paused ? AppColors.amber600 : AppColors.green700),
              ],
            ),
          ),
          const SectionTitle('Upcoming deliveries'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final day in s.upcoming(DateTime.now()))
                  SwitchListTile(
                    title: Text(formatDateShort(day), style: Theme.of(context).textTheme.labelLarge),
                    subtitle: Text(s.isSkipped(day) ? 'Skipped' : s.paused ? 'Paused' : 'Coming'),
                    value: !s.isSkipped(day) && !s.paused,
                    onChanged: s.paused ? null : (_) => controller.toggleSkip(s.id, day),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Turn a day off to skip it.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(s.paused ? Icons.play_arrow : Icons.pause, size: 18),
            label: Text(s.paused ? 'Resume subscription' : 'Pause subscription'),
            onPressed: () => controller.setPaused(s.id, !s.paused),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red600),
            onPressed: () async {
              if (await confirmDialog(context, title: 'Cancel this subscription?', message: 'No more deliveries will come from it.', confirmLabel: 'Cancel subscription')) {
                await controller.remove(s.id);
                if (context.mounted) context.pop();
              }
            },
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
  }
}
