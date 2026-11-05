import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/cart_controller.dart';

/// A bar that takes the customer to the cart. It only shows when the cart has something in it.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    if (count == 0) return const SizedBox.shrink();
    final total = subtotalOf(ref.watch(cartLinesProvider));
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 6, 13, 6),
      child: Material(
        color: AppColors.sky700,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(Routes.cart),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'item' : 'items'}  |  ${money(total)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
                Text('View cart', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
