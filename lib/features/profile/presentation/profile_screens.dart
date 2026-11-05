import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/data/auth_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../support/data/support_data.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(authProvider);
    Widget group(String title, List<Widget> tiles) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        AppCard(padding: EdgeInsets.zero, child: Column(children: tiles)),
      ],
    );
    void go(String route) => context.push(route);
    return Scaffold(
      appBar: AppBar(title: const Text('Account'), automaticallyImplyLeading: false),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            onTap: () => go(Routes.editProfile),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.sky700,
                  child: Text(customer?.initials ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer?.name ?? '', style: Theme.of(context).textTheme.titleSmall),
                      Text('+91 ${customer?.phone ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                      if ((customer?.email ?? '').isNotEmpty) Text(customer!.email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.sky700),
              ],
            ),
          ),
          group('Orders and delivery', [
            MenuTile(icon: Icons.receipt_long_outlined, title: 'My orders', onTap: () => context.go(Routes.orders)),
            MenuTile(icon: Icons.autorenew, title: 'Subscriptions', onTap: () => go(Routes.subscriptions)),
            MenuTile(icon: Icons.location_on_outlined, title: 'Saved addresses', onTap: () => go(Routes.addresses)),
            MenuTile(icon: Icons.favorite_border, title: 'Favourites', onTap: () => go(Routes.favourites)),
            MenuTile(icon: Icons.report_problem_outlined, title: 'Reported problems', onTap: () => go(Routes.issues)),
            MenuTile(icon: Icons.pin_drop_outlined, title: 'Check delivery area', onTap: () => go(Routes.serviceCheck)),
          ]),
          group('Plan and save', [
            MenuTile(icon: Icons.celebration_outlined, title: 'Ice planner', onTap: () => go(Routes.planner)),
            MenuTile(icon: Icons.local_shipping_outlined, title: 'Bulk order', onTap: () => go(Routes.bulkEnquiry)),
            MenuTile(icon: Icons.local_offer_outlined, title: 'Offers', onTap: () => go(Routes.offers)),
            MenuTile(icon: Icons.stars_outlined, title: 'Reward points', onTap: () => go(Routes.rewards)),
            MenuTile(icon: Icons.card_giftcard, title: 'Refer and earn', onTap: () => go(Routes.referral)),
          ]),
          group('Help', [
            MenuTile(icon: Icons.help_outline, title: 'Help centre', onTap: () => go(Routes.help)),
            MenuTile(icon: Icons.support_agent, title: 'Contact us', onTap: () => go(Routes.contact)),
            MenuTile(icon: Icons.forum_outlined, title: 'My tickets', onTap: () => go(Routes.tickets)),
            MenuTile(icon: Icons.health_and_safety_outlined, title: 'Ice safety guide', onTap: () => go(Routes.safety)),
            MenuTile(icon: Icons.storefront_outlined, title: 'Find a store', onTap: () => go(Routes.stores)),
            MenuTile(icon: Icons.rate_review_outlined, title: 'Send feedback', onTap: () => go(Routes.feedback)),
          ]),
          group('App', [
            MenuTile(icon: Icons.notifications_none, title: 'Notifications', onTap: () => go(Routes.notifications)),
            MenuTile(icon: Icons.settings_outlined, title: 'Settings', onTap: () => go(Routes.settings)),
            MenuTile(icon: Icons.info_outline, title: 'About ICECLUB', onTap: () => go(Routes.about)),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red600),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
            onPressed: () async {
              if (await confirmDialog(context, title: 'Log out?', message: 'You can log back in with your mobile number.', confirmLabel: 'Log out')) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(authProvider)?.name);
  late final _email = TextEditingController(text: ref.read(authProvider)?.email);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authProvider)?.phone ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(label: 'Full name', controller: _name, capitalization: TextCapitalization.words, validator: Validators.required),
              AppTextField(label: 'Email (optional)', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.email),
              InfoRow('Mobile number', '+91 $phone'),
              const SizedBox(height: 4),
              Text('To change your mobile number, please contact support.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  try {
                    await ref.read(authProvider.notifier).completeProfile(name: _name.text, email: _email.text);
                    if (!context.mounted) return;
                    showMessage(context, 'Profile saved');
                    context.pop();
                  } catch (e) {
                    if (context.mounted) showMessage(context, '$e', isError: true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MenuTile(icon: Icons.person_outline, title: 'Edit profile', onTap: () => context.push(Routes.editProfile)),
                MenuTile(icon: Icons.notifications_none, title: 'Notification settings', onTap: () => context.push(Routes.notificationSettings)),
                MenuTile(icon: Icons.credit_card, title: 'Payment methods', onTap: () => context.push(Routes.paymentMethods)),
                MenuTile(icon: Icons.description_outlined, title: 'Terms of use', onTap: () => context.push(Routes.legal('terms'))),
                MenuTile(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', onTap: () => context.push(Routes.legal('privacy'))),
                MenuTile(icon: Icons.replay_circle_filled_outlined, title: 'Refund policy', onTap: () => context.push(Routes.legal('refunds'))),
                MenuTile(icon: Icons.delete_outline, title: 'Delete my account', color: AppColors.red600, onTap: () => context.push(Routes.deleteAccount)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete my account')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const NoticeBanner('This removes your profile, addresses, orders, wallet balance and points from this phone. It cannot be undone.', color: AppColors.red600, icon: Icons.warning_amber_rounded),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: _understood,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: const Text('I understand that I will lose all of this.'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red600),
            onPressed: _understood
                ? () async {
                    try {
                      await ref.read(authProvider.notifier).deleteAccount();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', isError: true);
                    }
                  }
                : null,
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}

class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a store')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final (name, whatsapp) in AppConstants.stores)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, color: AppColors.sky700),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall)),
                    SmallButton(label: 'WhatsApp', icon: Icons.chat_outlined, outlined: true, onPressed: () => ContactLauncher.whatsapp(number: whatsapp)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _sections = [
    ('For drinks', Icons.local_drink_outlined, AppColors.green700, ['Tube ice and cube ice can go in drinks.', 'Use clean hands or tongs, and keep the bag closed.']),
    ('For chilling only', Icons.ac_unit, AppColors.amber600, ['Crushed, block and slab ice are for industrial use and chilling.', 'They are not for human consumption.', 'Do not put them in drinks or on food you will eat directly.']),
    ('Dry ice', Icons.warning_amber_rounded, AppColors.red600, ['Wear insulated gloves. Do not touch it with bare hands.', 'Never eat it or put it in a drink.', 'Keep it in a ventilated place, never in a small closed room or car.', 'Never seal it in an airtight container, because it can burst.', 'Keep it away from children and pets.']),
    ('Storing ice', Icons.inventory_2_outlined, AppColors.sky700, ['Keep it in an insulated box, out of the sun.', 'Drain melted water so the rest lasts longer.']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ice safety guide')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final (title, icon, color, points) in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final p in points)
                      Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('•  $p')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  int _stars = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text('How do you like the app?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          StarPicker(value: _stars, onChanged: (v) => setState(() => _stars = v)),
          const SizedBox(height: 10),
          AppTextField(label: 'Your feedback', controller: _text, maxLines: 4),
          FilledButton(
            onPressed: _stars == 0
                ? null
                : () async {
                    try {
                      await ref.read(ticketsProvider.notifier).open('App feedback: $_stars out of 5', 'Something else', _text.text.trim().isEmpty ? 'Rated the app $_stars out of 5.' : _text.text);
                      if (!context.mounted) return;
                      showMessage(context, 'Thank you for your feedback');
                      context.pop();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', isError: true);
                    }
                  },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About ICECLUB')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Center(child: Image.asset(AppConstants.logo, height: 130)),
          const SizedBox(height: 10),
          const Text('ICECLUB makes and delivers ice across ${AppConstants.serviceArea}.', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MenuTile(icon: Icons.language, title: 'Website', subtitle: AppConstants.website, onTap: () => ContactLauncher.website()),
                MenuTile(icon: Icons.description_outlined, title: 'Terms of use', onTap: () => context.push(Routes.legal('terms'))),
                MenuTile(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', onTap: () => context.push(Routes.legal('privacy'))),
                MenuTile(icon: Icons.replay_circle_filled_outlined, title: 'Refund policy', onTap: () => context.push(Routes.legal('refunds'))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Version 0.1.0', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});

  final String page;

  // Sample wording. A lawyer needs to write the real text before launch.
  static const _pages = {
    'terms': ('Terms of use', ['Orders are subject to stock and our delivery area.', 'Prices include GST and may change without notice.', 'Share your delivery OTP only after you have received your order.', 'Ice melts. Please be available to receive it at the chosen time.']),
    'privacy': ('Privacy policy', ['We use your mobile number to log you in and to contact you about orders.', 'We use your address and location to deliver your order.', 'We do not sell your personal details.', 'You can delete your account from Settings.']),
    'refunds': ('Refund policy', ['A cancelled order that was paid for is refunded to your wallet.', 'An order cannot be cancelled once it is out for delivery.', 'To report damaged, melted or short deliveries, open the order and tap Report a problem.']),
  };

  @override
  Widget build(BuildContext context) {
    final content = _pages[page];
    if (content == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Page not found'));
    final (title, points) = content;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const NoticeBanner('Sample text, to be replaced with the final legal wording.'),
          const SizedBox(height: 12),
          for (final p in points)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('•  $p')),
        ],
      ),
    );
  }
}
