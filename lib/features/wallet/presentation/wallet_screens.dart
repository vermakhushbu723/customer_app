import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../orders/data/orders_controller.dart';
import '../data/wallet_controller.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(walletProvider);
    final balance = ref.watch(walletBalanceProvider);
    final points = availablePoints(ref.watch(ordersProvider), ref.watch(redeemedPointsProvider).fold(0, (sum, r) => sum + r.points), DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), automaticallyImplyLeading: false),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.sky700, AppColors.sky500]), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet balance', style: TextStyle(color: Colors.white)),
                Text(money(balance), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.sky700),
                  onPressed: () => context.push(Routes.addMoney),
                  child: const Text('Add money'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MenuTile(icon: Icons.stars_outlined, title: 'Reward points', subtitle: '$points points', onTap: () => context.push(Routes.rewards)),
                MenuTile(icon: Icons.credit_card, title: 'Payment methods', onTap: () => context.push(Routes.paymentMethods)),
              ],
            ),
          ),
          const SectionTitle('Transactions'),
          AppCard(
            child: entries.isEmpty
                ? const Text('No transactions yet.')
                : Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(e.amount > 0 ? Icons.south_west : Icons.north_east, size: 16, color: e.amount > 0 ? AppColors.green700 : AppColors.neutral700),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: Theme.of(context).textTheme.labelLarge),
                                    Text(formatDateTime(e.at), style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.amount > 0 ? '+' : '-'}${money(e.amount.abs())}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: e.amount > 0 ? AppColors.green700 : AppColors.neutral900),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  static const _maxTopUp = 10000.0;
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add money')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeBanner('Demo: no real money moves. This only adds to the sample balance.'),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Amount',
                controller: _amount,
                digitsOnly: true,
                maxLength: 5,
                prefix: '₹',
                validator: (v) {
                  final problem = Validators.positiveAmount(v);
                  if (problem != null) return problem;
                  return double.parse(v!) > _maxTopUp ? 'You can add up to ${money(_maxTopUp)} at a time' : null;
                },
              ),
              Wrap(
                spacing: 7,
                children: [
                  for (final a in const [100, 200, 500, 1000])
                    ActionChip(label: Text(money(a)), onPressed: () => _amount.text = '$a'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  try {
                    await ref.read(walletProvider.notifier).add(double.parse(_amount.text), 'Added money');
                    if (!context.mounted) return;
                    showMessage(context, 'Money added');
                    context.pop();
                  } catch (e) {
                    if (context.mounted) showMessage(context, '$e', isError: true);
                  }
                },
                child: const Text('Add money'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redeemed = ref.watch(redeemedPointsProvider);
    final points = availablePoints(ref.watch(ordersProvider), redeemed.fold(0, (sum, r) => sum + r.points), DateTime.now());
    final canRedeem = points >= AppConstants.pointsToRedeem;
    return Scaffold(
      appBar: AppBar(title: const Text('Reward points')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.stars, size: 40, color: AppColors.amber600),
                const SizedBox(height: 4),
                Text('$points points', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                Text('Worth ${money(roundMoney(points * AppConstants.rupeesPerPoint))}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: canRedeem
                      ? () async {
                          try {
                            await ref.read(redeemedPointsProvider.notifier).redeem(points, points);
                            if (context.mounted) showMessage(context, 'Points added to your wallet');
                          } catch (e) {
                            if (context.mounted) showMessage(context, '$e', isError: true);
                          }
                        }
                      : null,
                  child: Text(canRedeem ? 'Redeem all to wallet' : 'Earn ${AppConstants.pointsToRedeem - points} more to redeem'),
                ),
              ],
            ),
          ),
          const SectionTitle('How it works'),
          AppCard(
            child: Column(
              children: [
                InfoRow('Earn', '1 point for every ₹${AppConstants.pointsPerRupees} on delivered orders'),
                const InfoRow('Value', '10 points = ₹1'),
                InfoRow('Redeem', 'From ${AppConstants.pointsToRedeem} points, into your wallet'),
              ],
            ),
          ),
          if (redeemed.isNotEmpty) ...[
            const SectionTitle('Redeemed'),
            AppCard(child: Column(children: [for (final r in redeemed) InfoRow(formatDate(r.at), '${r.points} points')])),
          ],
        ],
      ),
    );
  }
}

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  final _form = GlobalKey<FormState>();
  final _upi = TextEditingController();

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedUpiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const SectionTitle('Saved UPI IDs'),
          if (saved.isEmpty)
            const Text('No UPI IDs saved yet.')
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final id in saved)
                    MenuTile(
                      icon: Icons.qr_code_2,
                      title: id,
                      trailing: IconButton(tooltip: 'Remove $id', icon: const Icon(Icons.delete_outline, color: AppColors.red600), onPressed: () => ref.read(savedUpiProvider.notifier).remove(id)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'UPI ID',
                  controller: _upi,
                  validator: (v) => RegExp(r'^[\w.\-]+@[\w]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid UPI ID, like name@bank',
                ),
                OutlinedButton(
                  onPressed: () async {
                    if (!_form.currentState!.validate()) return;
                    try {
                      await ref.read(savedUpiProvider.notifier).add(_upi.text.trim());
                      _upi.clear();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', isError: true);
                    }
                  },
                  child: const Text('Save UPI ID'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const NoticeBanner('Card details are never saved in this app. The payment gateway will handle them when it connects.', icon: Icons.lock_outline),
        ],
      ),
    );
  }
}
