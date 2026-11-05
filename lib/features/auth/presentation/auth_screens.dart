import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../addresses/domain/address.dart';
import '../../wallet/data/wallet_controller.dart';
import '../data/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _slides = [
    ('assets/images/CubeIce.png', 'Clean ice, at your door', 'Tube, cube, crushed, block and dry ice, ordered in a few taps.'),
    ('assets/images/IceBox.png', 'On time, every time', 'Book express delivery or choose a slot, then follow your rider live.'),
    ('assets/images/CrushedBlockIce.png', 'Parties made easy', 'Work out how much ice you need, or set up a regular delivery.'),
  ];

  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingProvider.notifier).finish();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (image, title, text) in _slides)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sheet),
                              child: Image.asset(image, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 7,
                    width: i == _page ? 20 : 7,
                    decoration: BoxDecoration(color: i == _page ? AppColors.sky700 : AppColors.sky200, borderRadius: BorderRadius.circular(9)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: last ? _finish : () => _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Image.asset(AppConstants.logo, height: 110)),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(subtitle),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).sendOtp(_phone.text.trim());
      if (mounted) context.push(Routes.otp, extra: _phone.text.trim());
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Welcome to ICECLUB',
      subtitle: 'Log in or sign up with your mobile number.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Mobile number', controller: _phone, digitsOnly: true, keyboardType: TextInputType.phone, maxLength: 10, prefix: '+91', validator: Validators.phone),
            LoadingButton(label: 'Send OTP', loading: _busy, onPressed: _send),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: const [TextSpan(text: 'By continuing, you agree to our Terms and Privacy Policy.')],
              ),
              textAlign: TextAlign.center,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(onPressed: () => context.push(Routes.legal('terms')), child: const Text('Terms')),
                TextButton(onPressed: () => context.push(Routes.legal('privacy')), child: const Text('Privacy Policy')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendAfter = 30;

  final _form = GlobalKey<FormState>();
  final _otp = TextEditingController();
  Timer? _timer;
  int _wait = _resendAfter;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _wait = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      setState(() => _wait--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(widget.phone, _otp.text.trim());
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Enter the OTP',
      subtitle: 'We sent a 6-digit code to +91 ${widget.phone}.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDemoHint) ...[const NoticeBanner('Demo: no SMS is sent yet. Use the OTP 123456.'), const SizedBox(height: 14)],
            AppTextField(
              label: 'OTP',
              controller: _otp,
              digitsOnly: true,
              maxLength: 6,
              validator: (v) => (v ?? '').length == 6 ? null : 'Enter the 6-digit OTP',
            ),
            LoadingButton(label: 'Verify and continue', loading: _busy, onPressed: _verify),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _wait > 0
                  ? null
                  : () {
                      ref.read(authProvider.notifier).sendOtp(widget.phone);
                      setState(_startTimer);
                      showMessage(context, 'OTP sent again');
                    },
              child: Text(_wait > 0 ? 'Resend OTP in $_wait seconds' : 'Resend OTP'),
            ),
            TextButton(onPressed: () => context.pop(), child: const Text('Change mobile number')),
          ],
        ),
      ),
    );
  }
}

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _referral = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _referral.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Tell us about you',
      subtitle: 'This takes a few seconds, and you only do it once.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Full name', controller: _name, capitalization: TextCapitalization.words, validator: Validators.required),
            AppTextField(label: 'Email (optional)', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.email),
            AppTextField(label: 'Referral code (optional)', controller: _referral, capitalization: TextCapitalization.characters),
            FilledButton(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                try {
                  await ref.read(authProvider.notifier).completeProfile(name: _name.text, email: _email.text, referralCode: _referral.text);
                  if (useFakeBackend && _referral.text.trim().isNotEmpty) {
                    await ref.read(walletProvider.notifier).add(AppConstants.referralReward, 'Referral bonus');
                  }
                  if (context.mounted) context.push(Routes.serviceCheck);
                } catch (e) {
                  if (context.mounted) showMessage(context, '$e', isError: true);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checks a PIN code before the customer starts shopping.
class ServiceCheckScreen extends StatefulWidget {
  const ServiceCheckScreen({super.key});

  @override
  State<ServiceCheckScreen> createState() => _ServiceCheckScreenState();
}

class _ServiceCheckScreenState extends State<ServiceCheckScreen> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  bool? _covered;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check delivery')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.location_on_outlined, size: 44, color: AppColors.sky700),
              const SizedBox(height: 8),
              Text('Do we deliver to you?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('We deliver in ${AppConstants.serviceArea}.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              AppTextField(label: 'PIN code', controller: _pin, digitsOnly: true, maxLength: 6, validator: Validators.pincode),
              FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _covered = deliversTo(_pin.text));
                },
                child: const Text('Check'),
              ),
              if (_covered != null) ...[
                const SizedBox(height: 14),
                NoticeBanner(
                  _covered! ? 'Good news! We deliver to ${_pin.text}.' : "We don't deliver to ${_pin.text} yet. You can still look around.",
                  color: _covered! ? AppColors.green700 : AppColors.amber600,
                  icon: _covered! ? Icons.check_circle_outline : Icons.info_outline,
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                child: Text(_covered == true ? 'Start shopping' : 'Skip for now', style: const TextStyle(fontSize: AppTextStyles.sm)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
