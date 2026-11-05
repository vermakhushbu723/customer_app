import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../data/cart_controller.dart';
import '../domain/cart_pricing.dart';

/// The bill lines, shared by the cart, checkout and order screens.
class BillCard extends StatelessWidget {
  const BillCard({super.key, required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          InfoRow('Item total', money(bill.subtotal)),
          if (bill.discount > 0) InfoRow('Coupon discount', '- ${money(bill.discount)}', valueColor: AppColors.green700),
          InfoRow('Delivery', bill.deliveryFee == 0 ? 'Free' : money(bill.deliveryFee), valueColor: bill.deliveryFee == 0 ? AppColors.green700 : null),
          if (bill.expressFee > 0) InfoRow('Express delivery', money(bill.expressFee)),
          if (bill.tip > 0) InfoRow('Tip for the rider', money(bill.tip)),
          if (bill.walletUsed > 0) InfoRow('Paid from wallet', '- ${money(bill.walletUsed)}', valueColor: AppColors.green700),
          const Divider(),
          InfoRow('To pay', money(bill.total), bold: true),
          if (bill.savings > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('You save ${money(bill.savings)} on this order', style: const TextStyle(fontSize: AppTextStyles.xs, fontWeight: FontWeight.w700, color: AppColors.green700)),
            ),
        ],
      ),
    );
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartLinesProvider);
    final coupon = ref.watch(appliedCouponProvider);
    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Add some ice and it will show up here.',
          actionLabel: 'Browse ice',
          onAction: () => context.go(Routes.shop),
        ),
      );
    }
    final subtotal = subtotalOf(lines);
    final bill = computeBill(mrpTotal: mrpTotalOf(lines), subtotal: subtotal, coupon: coupon);
    final problem = coupon == null ? null : couponProblem(coupon, subtotal);
    final belowMinimum = subtotal < AppConstants.minOrderValue;
    final hasColdWarning = lines.any((l) => l.product.warning != null && !l.product.isDryIce);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          TextButton(
            onPressed: () async {
              if (await confirmDialog(context, title: 'Empty the cart?', message: 'Everything in your cart will be removed.', confirmLabel: 'Empty cart')) {
                ref.read(cartProvider.notifier).clear();
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: AppSpacing.bottomBar,
          child: FilledButton(
            onPressed: belowMinimum ? null : () => context.push(Routes.checkout),
            child: Text(belowMinimum ? 'Add ${money(AppConstants.minOrderValue - subtotal)} more to order' : 'Checkout  |  ${money(bill.total)}'),
          ),
        ),
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => context.push(Routes.product(l.product.id)),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.asset(l.product.image, height: 54, width: 54, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.product.name, style: Theme.of(context).textTheme.labelLarge),
                          Text(l.product.pack, style: Theme.of(context).textTheme.bodySmall),
                          Text(money(l.product.price * l.qty), style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ),
                    QuantityStepper(value: l.qty, min: 0, max: maxQtyPerItem, onChanged: (v) => ref.read(cartProvider.notifier).setQty(l.product.id, v)),
                  ],
                ),
              ),
            ),
          if (hasColdWarning) ...[
            const NoticeBanner('Crushed, block and slab ice are for chilling only. Not for human consumption.', icon: Icons.warning_amber_rounded),
            const SizedBox(height: 8),
          ],
          AppCard(
            onTap: () => context.push(Routes.coupons),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: AppColors.sky700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon == null ? 'Apply a coupon' : '${coupon.code} applied', style: Theme.of(context).textTheme.labelLarge),
                      if (problem != null) Text(problem, style: const TextStyle(fontSize: AppTextStyles.xs, color: AppColors.amber600)),
                    ],
                  ),
                ),
                if (coupon != null)
                  IconButton(tooltip: 'Remove coupon', icon: const Icon(Icons.close, size: 18), onPressed: () => ref.read(appliedCouponProvider.notifier).set(null))
                else
                  const Icon(Icons.chevron_right, color: AppColors.neutral500),
              ],
            ),
          ),
          const SectionTitle('Bill details'),
          BillCard(bill: bill),
          if (bill.deliveryFee > 0) ...[
            const SizedBox(height: 8),
            Text('Add ${money(AppConstants.freeDeliveryAbove - (subtotal - bill.discount))} more for free delivery.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply(Coupon coupon) {
    final problem = couponProblem(coupon, subtotalOf(ref.read(cartLinesProvider)));
    if (problem != null) {
      showMessage(context, problem, isError: true);
      return;
    }
    ref.read(appliedCouponProvider.notifier).set(coupon);
    showMessage(context, '${coupon.code} applied');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = subtotalOf(ref.watch(cartLinesProvider));
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Enter coupon code'),
                ),
              ),
              const SizedBox(width: 8),
              SmallButton(
                label: 'Apply',
                onPressed: () {
                  final coupon = couponByCode(_code.text);
                  if (coupon == null) {
                    showMessage(context, 'That coupon code is not valid', isError: true);
                  } else {
                    _apply(coupon);
                  }
                },
              ),
            ],
          ),
          const SectionTitle('Available coupons'),
          for (final c in coupons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(c.code),
                          const SizedBox(height: 5),
                          Text(c.title, style: Theme.of(context).textTheme.labelLarge),
                          Text(c.description, style: Theme.of(context).textTheme.bodySmall),
                          if (couponProblem(c, subtotal) case final problem?)
                            Text(problem, style: const TextStyle(fontSize: AppTextStyles.xs, color: AppColors.amber600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SmallButton(label: 'Apply', outlined: true, onPressed: () => _apply(c)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
