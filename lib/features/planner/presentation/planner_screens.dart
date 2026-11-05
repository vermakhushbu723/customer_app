import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../cart/data/cart_controller.dart';
import '../../catalog/data/catalog_data.dart';
import '../../catalog/domain/product.dart';
import '../data/enquiries_controller.dart';
import '../domain/ice_plan.dart';

/// Works out how much ice an event needs and fills the cart with it.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  int _guests = 25;
  int _hours = 4;
  bool _hotDay = true;
  bool _coolingDrinks = false;

  /// Only ice that is fit for drinks is suggested here.
  List<Product> get _packs => products.where((p) => p.categoryId == 'tube').toList();

  @override
  Widget build(BuildContext context) {
    final kg = iceNeededKg(guests: _guests, hours: _hours, hotDay: _hotDay, coolingDrinks: _coolingDrinks);
    final bySize = {for (final p in _packs) p.weightKg.toInt(): p};
    final plan = packsFor(kg, bySize.keys.toList());
    final cost = plan.entries.fold(0.0, (sum, e) => sum + bySize[e.key]!.price * e.value);
    return Scaffold(
      appBar: AppBar(title: const Text('Ice planner')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Counter(label: 'Guests', value: _guests, step: 5, min: 5, max: 1000, onChanged: (v) => setState(() => _guests = v)),
                const Divider(height: 20),
                _Counter(label: 'Hours', value: _hours, step: 1, min: 1, max: 24, onChanged: (v) => setState(() => _hours = v)),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Hot day or outdoors', style: Theme.of(context).textTheme.labelLarge),
                  value: _hotDay,
                  onChanged: (v) => setState(() => _hotDay = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Also chilling bottles in a tub', style: Theme.of(context).textTheme.labelLarge),
                  value: _coolingDrinks,
                  onChanged: (v) => setState(() => _coolingDrinks = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GradientHeader(
            child: Column(
              children: [
                const Text('You will need about', style: TextStyle(color: AppColors.neutral900)),
                Text('$kg kg of ice', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          const SectionTitle('We suggest'),
          AppCard(
            child: Column(
              children: [
                for (final e in plan.entries) InfoRow('Tube Ice, ${bySize[e.key]!.pack} × ${e.value}', money(bySize[e.key]!.price * e.value)),
                const Divider(),
                InfoRow('Estimated cost', money(cost), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('This is a rough guide. Delivery charges are extra.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              for (final e in plan.entries) {
                ref.read(cartProvider.notifier).add(bySize[e.key]!.id, e.value);
              }
              context.push(Routes.cart);
            },
            child: const Text('Add all to cart'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.push(Routes.bulkEnquiry, extra: kg), child: const Text('Need more? Ask for a bulk price')),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.step, required this.min, required this.max, required this.onChanged});

  final String label;
  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        QuantityStepper(value: value, step: step, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class BulkEnquiryScreen extends ConsumerStatefulWidget {
  const BulkEnquiryScreen({super.key, this.quantityKg});

  final int? quantityKg;

  @override
  ConsumerState<BulkEnquiryScreen> createState() => _BulkEnquiryScreenState();
}

class _BulkEnquiryScreenState extends ConsumerState<BulkEnquiryScreen> {
  static const _types = ['Wedding', 'Party', 'Corporate event', 'Restaurant or bar', 'Shop', 'Something else'];

  final _form = GlobalKey<FormState>();
  late final _quantity = TextEditingController(text: widget.quantityKg?.toString() ?? '');
  final _location = TextEditingController();
  final _notes = TextEditingController();
  String? _type;
  DateTime? _date;

  @override
  void dispose() {
    _quantity.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: _date ?? today.add(const Duration(days: 1)), firstDate: today, lastDate: today.add(const Duration(days: 365)));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_date == null) {
      showMessage(context, 'Select the event date', isError: true);
      return;
    }
    try {
      await ref.read(enquiriesProvider.notifier).add(
      BulkEnquiry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: _type!,
        date: _date!,
        quantityKg: int.parse(_quantity.text),
        location: _location.text.trim(),
        notes: _notes.text.trim(),
        at: DateTime.now(),
      ),
    );
      if (!mounted) return;
      showMessage(context, 'Enquiry sent');
      context.pushReplacement(Routes.enquiries);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk order'),
        actions: [TextButton(onPressed: () => context.push(Routes.enquiries), child: const Text('My enquiries'))],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tell us about your event and we will send you a price.'),
              const SizedBox(height: 14),
              AppDropdown<String>(
                label: 'Event type',
                value: _type,
                items: {for (final t in _types) t: t},
                onChanged: (v) => setState(() => _type = v),
                validator: (v) => v == null ? 'Select the event type' : null,
              ),
              LabeledField(
                label: 'Event date',
                child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(_date == null ? 'Select event date' : formatDateShort(_date!))),
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Quantity in kg', controller: _quantity, digitsOnly: true, maxLength: 6, validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter the quantity'),
              AppTextField(label: 'Delivery location', controller: _location, capitalization: TextCapitalization.words, validator: Validators.required),
              AppTextField(label: 'Notes (optional)', controller: _notes, maxLines: 3),
              FilledButton(onPressed: _submit, child: const Text('Send enquiry')),
            ],
          ),
        ),
      ),
    );
  }
}

class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enquiries = ref.watch(enquiriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My enquiries')),
      body: enquiries.isEmpty
          ? EmptyState(icon: Icons.local_shipping_outlined, title: 'No enquiries yet', actionLabel: 'Ask for a bulk price', onAction: () => context.pushReplacement(Routes.bulkEnquiry))
          : ListView(
              padding: AppSpacing.page,
              children: [
                for (final e in enquiries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(e.eventType, style: Theme.of(context).textTheme.titleSmall)),
                              StatusChip(e.status.label, color: e.status == EnquiryStatus.quoted ? AppColors.green700 : AppColors.amber600),
                            ],
                          ),
                          const SizedBox(height: 4),
                          InfoRow('Event date', formatDate(e.date)),
                          InfoRow('Quantity', '${e.quantityKg} kg'),
                          InfoRow('Location', e.location),
                          if (e.notes.isNotEmpty) InfoRow('Notes', e.notes),
                          if (e.quote.isNotEmpty) InfoRow('Our quote', e.quote),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
