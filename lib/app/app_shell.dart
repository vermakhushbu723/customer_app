import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/auth/data/auth_controller.dart';
import '../features/cart/presentation/cart_bar.dart';

const List<NavTab> _tabs = [
  (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  (icon: Icons.ac_unit_outlined, activeIcon: Icons.ac_unit, label: 'Shop'),
  (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders'),
  (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Wallet'),
  (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Account'),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(syncProvider)());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Things may have changed on the server while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(syncProvider)();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shell.currentIndex < 2) const CartBar(),
          AppBottomNav(
            tabs: _tabs,
            currentIndex: shell.currentIndex,
            onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ],
      ),
    );
  }
}
