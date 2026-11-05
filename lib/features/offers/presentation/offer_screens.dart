import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/data/auth_controller.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/domain/cart_pricing.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final c in coupons)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: AppCard(
                onTap: () => context.push(Routes.offer(c.code)),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, color: AppColors.sky700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: Theme.of(context).textTheme.titleSmall),
                          Text(c.description),
                          const SizedBox(height: 4),
                          StatusChip(c.code),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.neutral500),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OfferDetailScreen extends ConsumerWidget {
  const OfferDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupon = couponByCode(code);
    if (coupon == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Offer not found'));
    final subtotal = subtotalOf(ref.watch(cartLinesProvider));
    return Scaffold(
      appBar: AppBar(title: const Text('Offer')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.sky700, AppColors.sky500]), borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(coupon.description, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                InfoRow('Code', coupon.code, bold: true),
                InfoRow('Minimum order', money(coupon.minOrder)),
                if (coupon.maxOff > 0) InfoRow('Most you can save', money(coupon.maxOff)),
                const InfoRow('Usage', 'One coupon per order'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: coupon.code));
              showMessage(context, 'Code copied');
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final problem = couponProblem(coupon, subtotal);
              if (problem != null) {
                showMessage(context, subtotal == 0 ? 'Add something to your cart first' : problem, isError: true);
                return;
              }
              ref.read(appliedCouponProvider.notifier).set(coupon);
              context.push(Routes.cart);
            },
            child: const Text('Use this offer'),
          ),
        ],
      ),
    );
  }
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(authProvider)?.referralCode ?? '';
    final message = 'I order ice from ${AppConstants.companyName}. Use my code $code when you sign up. ${AppConstants.website}';
    return Scaffold(
      appBar: AppBar(title: const Text('Refer and earn')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const Icon(Icons.card_giftcard, size: 52, color: AppColors.sky700),
          const SizedBox(height: 8),
          Text('Invite friends, earn ${money(AppConstants.referralReward)}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('You both get wallet money after their first delivered order.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your code', style: Theme.of(context).textTheme.bodySmall),
                      Text(code, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
                SmallButton(
                  label: 'Copy',
                  icon: Icons.copy,
                  outlined: true,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showMessage(context, 'Code copied');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Share on WhatsApp'), onPressed: () => ContactLauncher.shareOnWhatsapp(message)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
