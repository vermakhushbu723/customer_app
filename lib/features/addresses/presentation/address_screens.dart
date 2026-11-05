import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/data/auth_controller.dart';
import '../data/address_controller.dart';
import '../domain/address.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addAddress),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addresses.isEmpty
          ? const EmptyState(icon: Icons.location_off_outlined, title: 'No saved addresses', message: 'Add one so we know where to bring your ice.')
          : ListView(
              padding: AppSpacing.pageWithFab,
              children: [
                for (final a in addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(a.label, style: Theme.of(context).textTheme.titleSmall)),
                              if (a.isDefault) const StatusChip('Default', color: AppColors.green700),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(a.singleLine),
                          Text('${a.name}, +91 ${a.phone}', style: Theme.of(context).textTheme.bodySmall),
                          if (!deliversTo(a.pincode)) ...[
                            const SizedBox(height: 6),
                            const StatusChip('We do not deliver here yet', color: AppColors.amber600),
                          ],
                          Wrap(
                            spacing: 2,
                            children: [
                              TextButton(onPressed: () => context.push(Routes.editAddress(a.id)), child: const Text('Edit')),
                              if (!a.isDefault) TextButton(onPressed: () => ref.read(addressesProvider.notifier).setDefault(a.id), child: const Text('Make default')),
                              TextButton(
                                onPressed: () async {
                                  if (await confirmDialog(context, title: 'Remove this address?', message: a.singleLine, confirmLabel: 'Remove')) {
                                    ref.read(addressesProvider.notifier).remove(a.id);
                                  }
                                },
                                child: const Text('Remove', style: TextStyle(color: AppColors.red600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  // Andheri, until the customer shares their location. The rider gets the address either way.
  static const _defaultLat = 19.1197;
  static const _defaultLng = 72.8464;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  String _label = 'Home';
  double? _lat;
  double? _lng;
  bool _locating = false;
  Address? _existing;

  @override
  void initState() {
    super.initState();
    final matches = ref.read(addressesProvider).where((a) => a.id == widget.addressId);
    _existing = matches.isEmpty ? null : matches.first;
    final customer = ref.read(authProvider);
    _name.text = _existing?.name ?? customer?.name ?? '';
    _phone.text = _existing?.phone ?? customer?.phone ?? '';
    _line.text = _existing?.line ?? '';
    _landmark.text = _existing?.landmark ?? '';
    _city.text = _existing?.city ?? '';
    _pincode.text = _existing?.pincode ?? '';
    _label = _existing?.label ?? 'Home';
    _lat = _existing?.latitude;
    _lng = _existing?.longitude;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _line, _landmark, _city, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final point = await LocationService.current();
      setState(() {
        _lat = point.latitude;
        _lng = point.longitude;
      });
      if (mounted) showMessage(context, 'Location added');
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await ref.read(addressesProvider.notifier).upsert(
      Address(
        id: _existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        label: _label,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        line: _line.text.trim(),
        landmark: _landmark.text.trim(),
        city: _city.text.trim(),
        pincode: _pincode.text.trim(),
        latitude: _lat ?? _defaultLat,
        longitude: _lng ?? _defaultLng,
        isDefault: _existing?.isDefault ?? false,
      ),
    );
      if (!mounted) return;
      showMessage(context, 'Address saved');
      context.pop();
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'Add address' : 'Edit address')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(_locating ? 'Finding you...' : _lat == null ? 'Use my current location' : 'Location added. Update it'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                children: [
                  for (final label in const ['Home', 'Work', 'Shop', 'Event'])
                    ChoiceChip(label: Text(label), selected: _label == label, onSelected: (_) => setState(() => _label = label)),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(label: 'Full name', controller: _name, capitalization: TextCapitalization.words, validator: Validators.required),
              AppTextField(label: 'Mobile number', controller: _phone, digitsOnly: true, keyboardType: TextInputType.phone, maxLength: 10, prefix: '+91', validator: Validators.phone),
              AppTextField(label: 'House, building and street', controller: _line, capitalization: TextCapitalization.words, validator: Validators.required),
              AppTextField(label: 'Landmark (optional)', controller: _landmark, capitalization: TextCapitalization.words),
              AppTextField(label: 'City', controller: _city, capitalization: TextCapitalization.words, validator: Validators.required),
              AppTextField(
                label: 'PIN code',
                controller: _pincode,
                digitsOnly: true,
                maxLength: 6,
                validator: Validators.pincode,
                onChanged: (_) => setState(() {}),
              ),
              if (_pincode.text.length == 6 && !deliversTo(_pincode.text)) ...[
                const NoticeBanner('We do not deliver to this PIN code yet. We deliver in ${AppConstants.serviceArea}.'),
                const SizedBox(height: 12),
              ],
              FilledButton(onPressed: _save, child: const Text('Save address')),
            ],
          ),
        ),
      ),
    );
  }
}
