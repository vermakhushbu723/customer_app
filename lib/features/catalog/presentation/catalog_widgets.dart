import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../cart/data/cart_controller.dart';
import '../domain/product.dart';

/// Add button that becomes a quantity stepper once the item is in the cart.
class AddToCartButton extends ConsumerWidget {
  const AddToCartButton({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider)[product.id] ?? 0;
    if (!product.inStock) {
      return const StatusChip('Out of stock', color: AppColors.neutral500);
    }
    if (qty == 0) {
      return SmallButton(label: 'Add', icon: Icons.add, onPressed: () => ref.read(cartProvider.notifier).add(product.id));
    }
    return QuantityStepper(value: qty, min: 0, max: maxQtyPerItem, onChanged: (v) => ref.read(cartProvider.notifier).setQty(product.id, v));
  }
}

class Price extends StatelessWidget {
  const Price(this.product, {super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(money(product.price), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: AppTextStyles.base)),
        if (product.percentOff > 0)
          Text(money(product.mrp), style: const TextStyle(fontSize: AppTextStyles.xs, decoration: TextDecoration.lineThrough, color: AppColors.neutral500)),
      ],
    );
  }
}

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => context.push(Routes.product(product.id)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(product.image, height: 78, width: 78, fit: BoxFit.cover),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(product.pack, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  RatingLine(product.rating),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: Price(product)),
                      AddToCartButton(product: product),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatingLine extends StatelessWidget {
  const RatingLine(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: AppColors.amber600),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Five tappable stars.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i out of 5',
            onPressed: () => onChanged(i),
            icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: AppColors.amber600),
          ),
      ],
    );
  }
}
