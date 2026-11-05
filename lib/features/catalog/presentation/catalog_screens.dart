import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/cart_bar.dart';
import '../data/catalog_data.dart';
import '../domain/product.dart';
import 'catalog_widgets.dart';

/// All categories, a tab of its own.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => context.push(Routes.search)),
          IconButton(tooltip: 'Favourites', icon: const Icon(Icons.favorite_border), onPressed: () => context.push(Routes.favourites)),
        ],
      ),
      body: GridView.builder(
        padding: AppSpacing.page,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.92),
        itemCount: categories.length,
        itemBuilder: (context, i) => CategoryCard(category: categories[i]),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category});

  final IceCategory category;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      onTap: () => context.push(Routes.category(category.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(category.image, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          Text(category.tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(categoryId);
    final items = productsIn(categoryId);
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      bottomNavigationBar: const CartBar(),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final p in items) ProductTile(product: p),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _suggestions = ['Tube ice', 'Party', 'Dry ice', 'Crushed', 'Ice box'];
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchProducts(_query.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      bottomNavigationBar: const CartBar(),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter ice type or use',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (_query.text.trim().isEmpty) ...[
            Text('Try searching for', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => _query.text = s),
                  ),
              ],
            ),
          ] else if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(icon: Icons.search_off, title: 'Nothing found', message: 'No products match "${_query.text.trim()}".'),
            )
          else
            for (final p in results) ProductTile(product: p),
        ],
      ),
    );
  }
}

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favouritesProvider);
    final items = products.where((p) => ids.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      bottomNavigationBar: const CartBar(),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border,
              title: 'No favourites yet',
              message: 'Tap the heart on a product to save it here.',
              actionLabel: 'Browse ice',
              onAction: () => context.go(Routes.shop),
            )
          : ListView(padding: AppSpacing.page, children: [for (final p in items) ProductTile(product: p)]),
    );
  }
}

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = productById(productId);
    if (product == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Product not found'));
    }
    final favourite = ref.watch(favouritesProvider).contains(product.id);
    final reviews = ref.watch(productReviewsProvider(product.id)).value ?? const <Review>[];
    final inCart = ref.watch(cartProvider)[product.id] ?? 0;
    final siblings = products.where((p) => p.categoryId == product.categoryId && p.id != product.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            tooltip: favourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(favourite ? Icons.favorite : Icons.favorite_border, color: favourite ? AppColors.red600 : null),
            onPressed: () => ref.read(favouritesProvider.notifier).toggle(product.id),
          ),
          IconButton(tooltip: 'Cart', icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => context.push(Routes.cart)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: AppSpacing.bottomBar,
          child: Row(
            children: [
              Expanded(child: Price(product)),
              const SizedBox(width: 10),
              if (!product.inStock)
                const StatusChip('Out of stock', color: AppColors.neutral500)
              else if (inCart == 0)
                Expanded(
                  child: FilledButton(onPressed: () => ref.read(cartProvider.notifier).add(product.id), child: const Text('Add to cart')),
                )
              else ...[
                AddToCartButton(product: product),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: () => context.push(Routes.cart), child: const Text('View cart')),
                ),
              ],
            ],
          ),
        ),
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.asset(product.image, height: 210, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('${product.name}, ${product.pack}', style: Theme.of(context).textTheme.titleLarge)),
              if (product.percentOff > 0) StatusChip('${product.percentOff}% off', color: AppColors.green700),
            ],
          ),
          const SizedBox(height: 4),
          RatingLine(product.rating),
          const SizedBox(height: 8),
          Text(product.description),
          const SizedBox(height: 4),
          Text('Price includes GST.', style: Theme.of(context).textTheme.bodySmall),
          if (product.warning != null) ...[
            const SizedBox(height: 12),
            NoticeBanner(product.warning!, color: product.warningColor, icon: Icons.warning_amber_rounded),
          ],
          const SectionTitle('Good for'),
          Wrap(spacing: 8, runSpacing: 6, children: [for (final use in product.uses) StatusChip(use)]),
          if (product.subscribable) ...[
            const SizedBox(height: 14),
            AppCard(
              onTap: () => context.push(Routes.newSubscription, extra: product.id),
              child: Row(
                children: [
                  const Icon(Icons.autorenew, color: AppColors.sky700),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Need this regularly? Set up a subscription.', style: Theme.of(context).textTheme.labelLarge)),
                  const Icon(Icons.chevron_right, color: AppColors.neutral500),
                ],
              ),
            ),
          ],
          if (siblings.isNotEmpty) ...[
            const SectionTitle('Other packs'),
            for (final p in siblings) ProductTile(product: p),
          ],
          SectionTitle('Reviews (${reviews.length})', actionLabel: 'See all', onAction: () => context.push(Routes.reviews(product.id))),
          for (final r in reviews.take(2)) _ReviewCard(review: r),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(review.author, style: Theme.of(context).textTheme.labelLarge)),
                for (var i = 1; i <= 5; i++) Icon(i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: AppColors.amber600),
              ],
            ),
            const SizedBox(height: 4),
            Text(review.text),
            const SizedBox(height: 2),
            Text(formatDate(review.at), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(productReviewsProvider(productId)).value ?? const <Review>[];
    final product = productById(productId);
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          if (product != null) ...[
            Text('${product.name}, ${product.pack}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const SizedBox(height: 10),
          ],
          for (final r in reviews) _ReviewCard(review: r),
        ],
      ),
    );
  }
}
