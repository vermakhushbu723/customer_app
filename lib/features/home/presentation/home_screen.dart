import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../addresses/data/address_controller.dart';
import '../../auth/data/auth_controller.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/checkout_screens.dart';
import '../../catalog/data/catalog_data.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_screens.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../orders/data/orders_controller.dart';
import '../../orders/presentation/order_screens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(authProvider);
    ref.watch(catalogVersionProvider);
    final address = ref.watch(defaultAddressProvider);
    final unread = ref.watch(unreadCountProvider);
    final cartCount = ref.watch(cartCountProvider);
    final now = DateTime.now();
    final active = ref.watch(ordersProvider).where((o) => o.isActiveAt(now)).toList();
    final bestsellers = products.where((p) => p.bestseller).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () async {
                      if (address == null) {
                        context.push(Routes.addAddress);
                      } else {
                        final picked = await showAddressPicker(context, ref);
                        if (picked != null) ref.read(addressesProvider.notifier).setDefault(picked.id);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.sky700, size: 20),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi ${customer?.firstName ?? ''}', style: Theme.of(context).textTheme.titleSmall),
                              Text(
                                address?.singleLine ?? 'Add a delivery address',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
                _BadgeIcon(icon: Icons.notifications_none, tooltip: 'Notifications', count: unread, onTap: () => context.push(Routes.notifications)),
                _BadgeIcon(icon: Icons.shopping_cart_outlined, tooltip: 'Cart', count: cartCount, onTap: () => context.push(Routes.cart)),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => context.push(Routes.search),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.sky200)),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 18, color: AppColors.neutral500),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Search for ice, packs or uses', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.neutral500)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _OfferCarousel(),
            if (active.isNotEmpty) ...[
              const SectionTitle('Your active order'),
              OrderCard(order: active.first, now: now),
            ],
            SectionTitle('Shop by type', actionLabel: 'See all', onAction: () => context.go(Routes.shop)),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, i) => SizedBox(width: 104, child: CategoryCard(category: categories[i])),
              ),
            ),
            const SectionTitle('Plan and save'),
            Row(
              children: [
                Expanded(child: _QuickCard(icon: Icons.celebration_outlined, title: 'Ice planner', text: 'How much do I need?', onTap: () => context.push(Routes.planner))),
                const SizedBox(width: 9),
                Expanded(child: _QuickCard(icon: Icons.autorenew, title: 'Subscribe', text: 'Regular deliveries', onTap: () => context.push(Routes.subscriptions))),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _QuickCard(icon: Icons.local_shipping_outlined, title: 'Bulk order', text: 'Weddings and events', onTap: () => context.push(Routes.bulkEnquiry))),
                const SizedBox(width: 9),
                Expanded(child: _QuickCard(icon: Icons.card_giftcard, title: 'Refer and earn', text: 'Invite your friends', onTap: () => context.push(Routes.referral))),
              ],
            ),
            const SectionTitle('Bestsellers'),
            for (final Product p in bestsellers) ProductTile(product: p),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.tooltip, required this.count, required this.onTap});

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: Icon(icon)),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.title, required this.text, required this.onTap});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.sky700),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OfferCarousel extends StatefulWidget {
  const _OfferCarousel();

  @override
  State<_OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends State<_OfferCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % coupons.length, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 112,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final c in coupons)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => context.push(Routes.offer(c.code)),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.sky700, AppColors.sky500]),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    // Shrinks to fit on small phones and with large text.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                          Text(c.description, style: const TextStyle(color: Colors.white, fontSize: AppTextStyles.xs)),
                          const SizedBox(height: 4),
                          Text('Use code ${c.code}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < coupons.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                width: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? AppColors.sky700 : AppColors.sky200),
              ),
          ],
        ),
      ],
    );
  }
}
