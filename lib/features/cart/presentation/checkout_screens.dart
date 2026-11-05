import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../addresses/data/address_controller.dart';
import '../../addresses/domain/address.dart';
import '../../orders/data/orders_controller.dart';
import '../../orders/domain/order.dart';
import '../../wallet/data/wallet_controller.dart';
import '../data/cart_controller.dart';
import '../domain/cart_pricing.dart';
import 'cart_screens.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _instructions = TextEditingController();
  String? _addressId;
  late DateTime _date = dateOnly(DateTime.now());
  String? _slot;
  bool _express = false;
  double _tip = 0;
  bool _useWallet = false;
  PaymentMethod? _method = PaymentMethod.upi;
  bool _dryIceAccepted = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Address? _address(List<Address> all) {
    for (final a in all) {
      if (a.id == _addressId) return a;
    }
    return ref.read(defaultAddressProvider);
  }

  CheckoutRequest _request(Address? address) => CheckoutRequest(
    address: address,
    date: _date,
    slot: _express ? AppConstants.deliverySlots.first.$1 : _slot,
    express: _express,
    tip: _tip,
    useWallet: _useWallet,
    method: _method,
    instructions: _instructions.text,
    dryIceAccepted: _dryIceAccepted,
  );

  Future<void> _continue(Address? address, List<CartLine> lines) async {
    final request = _request(address);
    final orders = ref.read(ordersProvider.notifier);
    try {
      final bill = orders.billFor(lines, request);
      // An earlier error must not stay on screen and cover the next page's buttons.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (bill.total > 0 && request.method != PaymentMethod.cod) {
        context.push(Routes.payment, extra: (request: request, amount: bill.total));
      } else {
        final order = await orders.place(request);
        if (mounted) context.go(Routes.orderPlaced(order.id));
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartLinesProvider);
    final addresses = ref.watch(addressesProvider);
    final balance = ref.watch(walletBalanceProvider);
    final coupon = ref.watch(appliedCouponProvider);
    final address = _address(addresses);
    final now = DateTime.now();
    final slots = openSlots(_date, now);
    if (_slot != null && !slots.any((s) => s.$1 == _slot)) _slot = null;
    final bill = computeBill(mrpTotal: mrpTotalOf(lines), subtotal: subtotalOf(lines), coupon: coupon, express: _express, tip: _tip, walletBalance: balance, useWallet: _useWallet);
    final hasDryIce = lines.any((l) => l.product.isDryIce);
    final isToday = isSameDay(_date, now);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: AppSpacing.bottomBar,
          child: FilledButton(
            onPressed: lines.isEmpty ? null : () => _continue(address, lines),
            child: Text(bill.total > 0 && _method != PaymentMethod.cod ? 'Pay ${money(bill.total)}' : 'Place order'),
          ),
        ),
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const SectionTitle('Deliver to'),
          if (address == null)
            AppCard(
              onTap: () => context.push(Routes.addAddress),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_outlined, color: AppColors.sky700),
                  SizedBox(width: 10),
                  Expanded(child: Text('Add a delivery address')),
                  Icon(Icons.chevron_right, color: AppColors.neutral500),
                ],
              ),
            )
          else ...[
            AppCard(
              onTap: () async {
                final picked = await showAddressPicker(context, ref);
                if (picked != null) setState(() => _addressId = picked.id);
              },
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.sky700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address.label, style: Theme.of(context).textTheme.labelLarge),
                        Text(address.singleLine),
                      ],
                    ),
                  ),
                  const Text('Change', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.sky700)),
                ],
              ),
            ),
            if (!deliversTo(address.pincode)) ...[
              const SizedBox(height: 8),
              NoticeBanner('We do not deliver to ${address.pincode} yet. Please choose another address.', color: AppColors.red600),
            ],
          ],
          const SectionTitle('Delivery time'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Builder(
                      builder: (context) {
                        final day = dateOnly(now).add(Duration(days: i));
                        return ChoiceChip(
                          label: Text(i == 0 ? 'Today' : i == 1 ? 'Tomorrow' : formatDateShort(day)),
                          selected: isSameDay(day, _date),
                          onSelected: (_) => setState(() {
                            _date = day;
                            if (i != 0) _express = false;
                          }),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isToday)
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.amber600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Express delivery', style: Theme.of(context).textTheme.labelLarge),
                        Text('Within 60 minutes for ${money(AppConstants.expressFee)}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Switch(value: _express, onChanged: (v) => setState(() => _express = v)),
                ],
              ),
            ),
          if (!_express) ...[
            const SizedBox(height: 8),
            if (slots.isEmpty)
              const NoticeBanner('No more slots today. Please choose another day, or use express delivery.')
            else
              Wrap(
                spacing: 7,
                runSpacing: 2,
                children: [
                  for (final (label, _) in slots)
                    ChoiceChip(label: Text(label), selected: _slot == label, onSelected: (_) => setState(() => _slot = label)),
                ],
              ),
          ],
          const SectionTitle('Delivery instructions'),
          TextField(
            controller: _instructions,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Enter instructions for the rider (optional)'),
          ),
          const SectionTitle('Tip for the rider'),
          Wrap(
            spacing: 7,
            children: [
              for (final tip in const [0.0, 10.0, 20.0, 30.0, 50.0])
                ChoiceChip(label: Text(tip == 0 ? 'No tip' : money(tip)), selected: _tip == tip, onSelected: (_) => setState(() => _tip = tip)),
            ],
          ),
          const SectionTitle('Payment'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _useWallet && balance > 0,
                  onChanged: balance > 0 ? (v) => setState(() => _useWallet = v) : null,
                  title: Text('Use wallet', style: Theme.of(context).textTheme.labelLarge),
                  subtitle: Text('Balance ${money(balance)}'),
                ),
                if (bill.total > 0)
                  RadioGroup<PaymentMethod>(
                    groupValue: _method,
                    onChanged: (v) => setState(() => _method = v),
                    child: Column(
                      children: [
                        for (final m in PaymentMethod.values.where((m) => m != PaymentMethod.wallet))
                          RadioListTile<PaymentMethod>(
                            value: m,
                            title: Text(m.label, style: Theme.of(context).textTheme.labelLarge),
                            secondary: Icon(m.icon, color: AppColors.sky700),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (hasDryIce) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: CheckboxListTile(
                value: _dryIceAccepted,
                onChanged: (v) => setState(() => _dryIceAccepted = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I will handle dry ice with insulated gloves in a ventilated place, and will not eat it or seal it in an airtight container.'),
              ),
            ),
          ],
          const SectionTitle('Bill details'),
          BillCard(bill: bill),
        ],
      ),
    );
  }
}

/// Lets the customer choose from their saved addresses, or add one.
Future<Address?> showAddressPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final addresses = ref.watch(addressesProvider);
          return ListView(
            shrinkWrap: true,
            padding: AppSpacing.page,
            children: [
              Text('Choose an address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final a in addresses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.sky700),
                  title: Text(a.label, style: Theme.of(context).textTheme.labelLarge),
                  subtitle: Text(a.singleLine),
                  onTap: () => Navigator.pop(sheet, a),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add a new address'),
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push(Routes.addAddress);
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Stands in for the payment gateway until a real one is connected.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.request, required this.amount});

  final CheckoutRequest request;
  final double amount;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _busy = false;

  Future<void> _succeed() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    try {
      final order = await ref.read(ordersProvider.notifier).place(widget.request);
      if (mounted) context.go(Routes.orderPlaced(order.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: AppSpacing.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoticeBanner('Demo: no real money moves. The payment gateway connects later. Choose how this try should end.'),
            const SizedBox(height: 18),
            Icon(widget.request.method?.icon ?? Icons.payments_outlined, size: 44, color: AppColors.sky700),
            const SizedBox(height: 10),
            Text(money(widget.amount), textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
            Text('Paying by ${widget.request.method?.label ?? ''}', textAlign: TextAlign.center),
            const Spacer(),
            LoadingButton(label: 'Payment succeeds', loading: _busy, onPressed: _succeed),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => context.pushReplacement(Routes.paymentFailed),
              child: const Text('Payment fails'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment failed')),
      body: EmptyState(
        icon: Icons.error_outline,
        title: 'Your payment did not go through',
        message: 'No money was taken and your cart is safe. Please try again.',
        actionLabel: 'Back to checkout',
        onAction: () => context.pop(),
      ),
    );
  }
}

class OrderPlacedScreen extends ConsumerWidget {
  const OrderPlacedScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(orderId);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.check_circle, size: 76, color: AppColors.green600),
              const SizedBox(height: 14),
              Text('Order placed!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              if (order != null) ...[
                Text(order.number, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('${formatDateShort(order.deliveryDate)}, ${order.slot}', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                NoticeBanner('Your delivery OTP is ${order.otp}. Share it with the rider only when you have your ice.', color: AppColors.sky700, icon: Icons.lock_outline),
              ],
              const Spacer(),
              FilledButton(onPressed: () => context.go(Routes.track(orderId)), child: const Text('Track order')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
            ],
          ),
        ),
      ),
    );
  }
}
