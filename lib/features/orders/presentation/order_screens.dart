import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../data/orders_controller.dart';
import '../domain/order.dart';

/// Rebuilds its child on a timer, so a live order moves along on screen.
class _Ticker extends ConsumerStatefulWidget {
  const _Ticker({required this.builder, this.every = const Duration(seconds: 5)});

  final Widget Function(DateTime now) builder;
  final Duration every;

  @override
  ConsumerState<_Ticker> createState() => _TickerState();
}

class _TickerState extends ConsumerState<_Ticker> {
  static const _serverRefresh = Duration(seconds: 20);

  late final Timer _timer;
  DateTime _lastFetch = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      setState(() {});
      if (!useFakeBackend && DateTime.now().difference(_lastFetch) >= _serverRefresh) {
        _lastFetch = DateTime.now();
        ref.read(ordersProvider.notifier).refresh().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(DateTime.now());
}

class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order, required this.now});

  final Order order;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order.statusAt(now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        onTap: () => context.push(Routes.order(order.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(order.lines.first.image, height: 46, width: 46, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.number, style: Theme.of(context).textTheme.labelLarge),
                      Text(formatDateTime(order.placedAt), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(child: StatusChip(status.label, color: status.color)),
              ],
            ),
            const SizedBox(height: 7),
            Text(order.lines.map((l) => '${l.name} ${l.pack} × ${l.qty}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: Text(money(order.grandTotal), style: Theme.of(context).textTheme.titleSmall)),
                if (order.isActiveAt(now) && status != OrderStatus.placed)
                  SmallButton(label: 'Track', icon: Icons.location_on_outlined, onPressed: () => context.push(Routes.track(order.id)))
                else if (!order.isActiveAt(now))
                  SmallButton(
                    label: 'Reorder',
                    icon: Icons.replay,
                    outlined: true,
                    onPressed: () {
                      final missing = ref.read(ordersProvider.notifier).reorder(order.id);
                      if (missing.isNotEmpty) showMessage(context, 'Out of stock: ${missing.join(', ')}', isError: true);
                      context.push(Routes.cart);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = [...ref.watch(ordersProvider)]..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'Delivered'), Tab(text: 'Cancelled')]),
        ),
        body: _Ticker(
          builder: (now) {
            Widget list(List<Order> items, String empty) => items.isEmpty
                ? EmptyState(icon: Icons.receipt_long_outlined, title: empty, actionLabel: 'Order ice', onAction: () => context.go(Routes.shop))
                : ListView(padding: AppSpacing.page, children: [for (final o in items) OrderCard(order: o, now: now)]);
            return TabBarView(
              children: [
                list(orders.where((o) => o.isActiveAt(now)).toList(), 'No active orders'),
                list(orders.where((o) => o.statusAt(now) == OrderStatus.delivered).toList(), 'No delivered orders yet'),
                list(orders.where((o) => o.statusAt(now) == OrderStatus.cancelled).toList(), 'No cancelled orders'),
              ],
            );
          },
        ),
      ),
    );
  }
}

Scaffold _missing() => Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Order not found'));

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order, required this.now});

  final Order order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final current = order.statusAt(now);
    if (current == OrderStatus.failed) {
      return const NoticeBanner('We could not deliver this order. Our team will contact you.', color: AppColors.red600);
    }
    if (current == OrderStatus.cancelled) {
      return NoticeBanner('Cancelled on ${formatDateTime(order.cancelledAt!)}. Reason: ${order.cancelReason}', color: AppColors.red600);
    }
    final reached = orderSteps.indexOf(current);
    return Column(
      children: [
        for (final (i, step) in orderSteps.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(i <= reached ? Icons.check_circle : Icons.radio_button_unchecked, size: 19, color: i <= reached ? AppColors.green600 : AppColors.neutral500),
                  if (i < orderSteps.length - 1) Container(width: 2, height: 22, color: i < reached ? AppColors.green600 : AppColors.sky200),
                ],
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.label, style: Theme.of(context).textTheme.labelLarge),
                    if (i <= reached) Text(formatDateTime(order.timeOf(step)), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(orderId);
    if (order == null) return _missing();
    return Scaffold(
      appBar: AppBar(
        title: Text(order.number),
        actions: [IconButton(tooltip: 'Help', icon: const Icon(Icons.help_outline), onPressed: () => context.push(Routes.help))],
      ),
      body: _Ticker(
        builder: (now) {
          final status = order.statusAt(now);
          final delivered = status == OrderStatus.delivered;
          final active = order.isActiveAt(now);
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (active) ...[
                if (useFakeBackend) ...[const NoticeBanner('Demo: this order moves along by itself.'), const SizedBox(height: 10)],
                NoticeBanner('Delivery OTP: ${order.otp}. Share it with the rider only when you have your ice.', color: AppColors.sky700, icon: Icons.lock_outline),
                const SizedBox(height: 10),
              ],
              AppCard(child: _Timeline(order: order, now: now)),
              const SizedBox(height: 10),
              if (status == OrderStatus.outForDelivery || status == OrderStatus.packed)
                FilledButton.icon(icon: const Icon(Icons.location_on_outlined, size: 18), label: const Text('Track on the map'), onPressed: () => context.push(Routes.track(order.id))),
              if (delivered && order.deliveryRating == null)
                FilledButton.icon(icon: const Icon(Icons.star_outline, size: 18), label: const Text('Rate this order'), onPressed: () => context.push(Routes.rateOrder(order.id))),
              const SectionTitle('Items'),
              AppCard(
                child: Column(
                  children: [
                    for (final l in order.lines) InfoRow('${l.name}, ${l.pack} × ${l.qty}', money(l.amount)),
                    const Divider(),
                    InfoRow('Total', money(order.grandTotal), bold: true),
                  ],
                ),
              ),
              const SectionTitle('Delivery'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Deliver to', order.addressLabel),
                    InfoRow('Address', order.addressText),
                    InfoRow('Date', formatDate(order.deliveryDate)),
                    InfoRow('Time', order.slot),
                    if (order.instructions.isNotEmpty) InfoRow('Instructions', order.instructions),
                    InfoRow('Payment', order.paymentMethod.label),
                  ],
                ),
              ),
              if (order.deliveryRating != null) ...[
                const SectionTitle('Your rating'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoRow('Delivery', '${order.deliveryRating} out of 5'),
                      InfoRow('Ice quality', '${order.productRating} out of 5'),
                      if ((order.reviewText ?? '').isNotEmpty) Text(order.reviewText!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(icon: const Icon(Icons.description_outlined, size: 18), label: const Text('View bill'), onPressed: () => context.push(Routes.bill(order.id))),
              if (delivered) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(icon: const Icon(Icons.report_problem_outlined, size: 18), label: const Text('Report a problem'), onPressed: () => context.push(Routes.reportIssue(order.id))),
              ],
              if (!active) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Reorder'),
                  onPressed: () {
                    final missing = ref.read(ordersProvider.notifier).reorder(order.id);
                    if (missing.isNotEmpty) showMessage(context, 'Out of stock: ${missing.join(', ')}', isError: true);
                    context.push(Routes.cart);
                  },
                ),
              ],
              if (order.canCancelAt(now)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.red600),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel order'),
                  onPressed: () => context.push(Routes.cancelOrder(order.id)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Where the order is, from the server. The rider's position comes from the Rider App.
final orderTrackingProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  if (useFakeBackend) return null;
  return await ref.read(apiProvider).get('/customer/orders/$id/tracking') as Map<String, dynamic>;
});

class TrackOrderScreen extends ConsumerWidget {
  const TrackOrderScreen({super.key, required this.orderId});

  final String orderId;

  // A sample factory until the real ones are confirmed.
  static const _factory = LatLng(19.1136, 72.8697);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(orderId);
    if (order == null) return _missing();
    final destination = LatLng(order.latitude, order.longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Track order')),
      body: _Ticker(
        every: const Duration(seconds: 3),
        builder: (now) {
          // Polled rather than pushed, about as often as the Rider App sends a position.
          if (!useFakeBackend && now.second % 15 < 3) ref.invalidate(orderTrackingProvider(orderId));
          final live = ref.watch(orderTrackingProvider(orderId)).value;
          LatLng? point(String key) {
            final p = live?[key] as Map<String, dynamic>?;
            return p == null ? null : LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
          }

          final origin = point('origin') ?? _factory;
          final status = order.statusAt(now);
          final progress = order.tripProgressAt(now);
          final rider = useFakeBackend
              ? LatLng(origin.latitude + (destination.latitude - origin.latitude) * progress, origin.longitude + (destination.longitude - origin.longitude) * progress)
              : point('rider');
          final onRoad = status == OrderStatus.outForDelivery;
          final etaText = live?['eta'] as String?;
          final etaAt = etaText == null ? null : DateTime.parse(etaText);
          final etaMinutes = useFakeBackend ? order.etaMinutesAt(now) : etaAt?.difference(now).inMinutes.clamp(1, 600);
          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(coordinates: [origin, destination], padding: const EdgeInsets.all(48)),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.iceclubstore.customer_app'),
                    PolylineLayer(polylines: [Polyline(points: [origin, destination], color: AppColors.sky700, strokeWidth: 3)]),
                    MarkerLayer(
                      markers: [
                        Marker(point: origin, child: const Icon(Icons.factory, color: AppColors.neutral900)),
                        Marker(point: destination, child: const Icon(Icons.location_on, color: AppColors.red600, size: 30)),
                        if (onRoad && rider != null) Marker(point: rider, child: const Icon(Icons.delivery_dining, color: AppColors.sky700, size: 30)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: AppSpacing.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            switch (status) {
                              OrderStatus.outForDelivery => etaMinutes == null ? 'On the way' : 'Arriving in $etaMinutes min',
                              OrderStatus.delivered => 'Delivered',
                              OrderStatus.cancelled => 'Cancelled',
                              _ => 'Getting your ice ready',
                            },
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusChip(status.label, color: status.color),
                      ],
                    ),
                    if (order.isActiveAt(now)) ...[
                      const SizedBox(height: 4),
                      Text('Delivery OTP: ${order.otp}', style: Theme.of(context).textTheme.labelLarge),
                    ],
                    if (onRoad) ...[
                      const Divider(height: 18),
                      Row(
                        children: [
                          const CircleAvatar(radius: 17, backgroundColor: AppColors.sky100, child: Icon(Icons.person, color: AppColors.sky700, size: 18)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.riderName ?? 'Your rider', style: Theme.of(context).textTheme.labelLarge),
                                if (order.riderVehicle != null) Text(order.riderVehicle!, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          SmallButton(label: 'Call', icon: Icons.call, outlined: true, onPressed: () => ContactLauncher.call(order.riderPhone ?? AppConstants.supportPhone)),
                        ],
                      ),
                    ],
                    if (useFakeBackend) ...[const SizedBox(height: 6), Text('Demo: the rider position is simulated.', style: Theme.of(context).textTheme.bodySmall)],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BillScreen extends ConsumerWidget {
  const BillScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(orderId);
    if (order == null) return _missing();
    final text = StringBuffer('ICECLUB bill for ${order.number}\n');
    for (final l in order.lines) {
      text.writeln('${l.name} ${l.pack} x ${l.qty}: ${money(l.amount)}');
    }
    text.write('Total: ${money(order.grandTotal)}');
    return Scaffold(
      appBar: AppBar(title: const Text('Bill')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppConstants.companyName, style: Theme.of(context).textTheme.titleLarge),
                Text(AppConstants.serviceArea, style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 22),
                InfoRow('Order', order.number),
                InfoRow('Date', formatDateTime(order.placedAt)),
                InfoRow('Billed to', order.receiverName),
                InfoRow('Address', order.addressText),
                const Divider(height: 22),
                for (final l in order.lines) InfoRow('${l.name}, ${l.pack} × ${l.qty} at ${money(l.price)}', money(l.amount)),
                const Divider(height: 22),
                InfoRow('Item total', money(order.subtotal)),
                if (order.discount > 0) InfoRow('Coupon ${order.couponCode ?? ''}', '- ${money(order.discount)}'),
                InfoRow('Delivery', order.deliveryFee == 0 ? 'Free' : money(order.deliveryFee)),
                if (order.expressFee > 0) InfoRow('Express delivery', money(order.expressFee)),
                if (order.tip > 0) InfoRow('Tip for the rider', money(order.tip)),
                InfoRow('Total', money(order.grandTotal), bold: true),
                if (order.walletUsed > 0) InfoRow('Paid from wallet', money(order.walletUsed)),
                InfoRow(order.paymentMethod == PaymentMethod.cod ? 'To pay in cash' : 'Paid by ${order.paymentMethod.label}', money(order.total)),
                const SizedBox(height: 8),
                Text('Prices include GST. This is a sample bill, not a tax invoice.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Share on WhatsApp'), onPressed: () => ContactLauncher.shareOnWhatsapp(text.toString())),
        ],
      ),
    );
  }
}

class CancelOrderScreen extends ConsumerStatefulWidget {
  const CancelOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CancelOrderScreen> createState() => _CancelOrderScreenState();
}

class _CancelOrderScreenState extends ConsumerState<CancelOrderScreen> {
  static const _reasons = ['Plans changed', 'Ordered by mistake', 'Delivery time does not suit me', 'Found a better price', 'Something else'];
  String? _reason;

  @override
  Widget build(BuildContext context) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(widget.orderId);
    if (order == null) return _missing();
    final refund = order.walletUsed + (order.paymentMethod == PaymentMethod.cod ? 0 : order.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Cancel order')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text('Why are you cancelling ${order.number}?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(children: [for (final r in _reasons) RadioListTile<String>(value: r, title: Text(r))]),
            ),
          ),
          const SizedBox(height: 12),
          if (refund > 0) ...[
            NoticeBanner('${money(refund)} will go to your ICECLUB wallet.', color: AppColors.green700),
            const SizedBox(height: 12),
          ],
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red600),
            onPressed: _reason == null
                ? null
                : () async {
                    try {
                      await ref.read(ordersProvider.notifier).cancel(order.id, _reason!, DateTime.now());
                      if (!context.mounted) return;
                      showMessage(context, 'Order cancelled');
                      context.pop();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', isError: true);
                    }
                  },
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
  }
}

class RateOrderScreen extends ConsumerStatefulWidget {
  const RateOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends ConsumerState<RateOrderScreen> {
  final _text = TextEditingController();
  int _delivery = 0;
  int _product = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your order')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text('How was the delivery?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
          StarPicker(value: _delivery, onChanged: (v) => setState(() => _delivery = v)),
          const SizedBox(height: 10),
          Text('How was the ice?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
          StarPicker(value: _product, onChanged: (v) => setState(() => _product = v)),
          const SizedBox(height: 12),
          AppTextField(label: 'Your review (optional)', controller: _text, maxLines: 3),
          FilledButton(
            onPressed: _delivery == 0 || _product == 0
                ? null
                : () async {
                    try {
                      await ref.read(ordersProvider.notifier).rate(widget.orderId, delivery: _delivery, product: _product, text: _text.text);
                      if (!context.mounted) return;
                      showMessage(context, 'Thank you for your rating');
                      context.pop();
                    } catch (e) {
                      if (context.mounted) showMessage(context, '$e', isError: true);
                    }
                  },
            child: const Text('Submit rating'),
          ),
        ],
      ),
    );
  }
}

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  IssueType? _type;
  final List<String> _photos = [];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      if (file != null) setState(() => _photos.add(file.path));
    } catch (_) {
      if (mounted) showMessage(context, 'The camera could not be opened. Please check its permission.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(widget.orderId);
    if (order == null) return _missing();
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(order.number, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              AppDropdown<IssueType>(
                label: 'Problem',
                value: _type,
                items: {for (final t in IssueType.values) t: t.label},
                onChanged: (v) => setState(() => _type = v),
                validator: (v) => v == null ? 'Select the problem' : null,
              ),
              AppTextField(label: 'Tell us what went wrong', hint: 'Enter what went wrong', controller: _details, maxLines: 3, validator: (v) => (v ?? '').trim().isEmpty ? 'Tell us what went wrong' : null),
              Text('Photos', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              for (final p in _photos) ...[LocalImage(p, height: 120), const SizedBox(height: 8)],
              OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Take a photo'), onPressed: _addPhoto),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  try {
                    final issue = await ref.read(issuesProvider.notifier).report(order, _type!, _details.text, _photos);
                    if (context.mounted) context.pushReplacement(Routes.issue(issue.id));
                  } catch (e) {
                    if (context.mounted) showMessage(context, '$e', isError: true);
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _issueLabel(String status) => const {'approved': 'Approved', 'rejected': 'Not approved'}[status] ?? 'Under review';

Color _issueColor(String status) => const {'approved': AppColors.green700, 'rejected': AppColors.red600}[status] ?? AppColors.amber600;

class IssuesScreen extends ConsumerWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(issuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reported problems')),
      body: issues.isEmpty
          ? const EmptyState(icon: Icons.task_alt, title: 'No problems reported', message: 'To report one, open a delivered order.')
          : ListView(
              padding: AppSpacing.page,
              children: [
                for (final i in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push(Routes.issue(i.id)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.type.label, style: Theme.of(context).textTheme.labelLarge),
                                Text('${i.orderNumber}, ${formatDate(i.at)}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          StatusChip(_issueLabel(i.status), color: _issueColor(i.status)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(issuesProvider).where((i) => i.id == issueId);
    if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Report not found'));
    final issue = matches.first;
    return Scaffold(
      appBar: AppBar(title: Text(issue.number)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          if (issue.status == 'underReview') ...[const NoticeBanner('We have your report. It will be reviewed by the ICECLUB team.', color: AppColors.sky700), const SizedBox(height: 10)],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow('Status', _issueLabel(issue.status), valueColor: _issueColor(issue.status)),
                if (issue.remark.isNotEmpty) InfoRow('From our team', issue.remark),
                if (issue.creditAmount > 0) InfoRow('Refunded to wallet', money(issue.creditAmount)),
                InfoRow('Order', issue.orderNumber),
                InfoRow('Problem', issue.type.label),
                InfoRow('Reported', formatDateTime(issue.at)),
                const Divider(),
                Text(issue.details),
              ],
            ),
          ),
          for (final p in issue.photos) ...[const SizedBox(height: 10), LocalImage(p)],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.push(Routes.order(issue.orderId)), child: const Text('View order')),
        ],
      ),
    );
  }
}
