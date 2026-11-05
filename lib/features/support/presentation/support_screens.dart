import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/form_fields.dart';
import '../data/support_data.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    bool matches((String, String) item) => q.isEmpty || '${item.$1} ${item.$2}'.toLowerCase().contains(q);
    final sections = [
      for (final (title, items) in faqs)
        if (items.any(matches)) (title, items.where(matches).toList()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Help centre')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Enter your question', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.support_agent, size: 17), label: const Text('Contact us'), onPressed: () => context.push(Routes.contact))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.forum_outlined, size: 17), label: const Text('My tickets'), onPressed: () => context.push(Routes.tickets))),
            ],
          ),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(icon: Icons.search_off, title: 'Nothing found', message: 'Try other words, or contact us.'),
            ),
          for (final (title, items) in sections) ...[
            SectionTitle(title),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (question, answer) in items)
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(question, style: Theme.of(context).textTheme.labelLarge),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(answer)],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                MenuTile(icon: Icons.call_outlined, title: 'Call us', subtitle: AppConstants.supportPhone, onTap: () => ContactLauncher.call(AppConstants.supportPhone)),
                MenuTile(icon: Icons.chat_outlined, title: 'WhatsApp', subtitle: 'Message our team', color: AppColors.green700, onTap: () => ContactLauncher.whatsapp()),
                MenuTile(icon: Icons.confirmation_number_outlined, title: 'Raise a ticket', subtitle: 'We reply in the app', onTap: () => context.push(Routes.newTicket)),
                MenuTile(icon: Icons.storefront_outlined, title: 'Find a store', onTap: () => context.push(Routes.stores)),
                MenuTile(icon: Icons.language, title: 'Website', subtitle: AppConstants.website, onTap: () => ContactLauncher.website()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push(Routes.newTicket), icon: const Icon(Icons.add), label: const Text('New ticket')),
      body: tickets.isEmpty
          ? const EmptyState(icon: Icons.forum_outlined, title: 'No tickets yet', message: 'Raise a ticket and our team will help you.')
          : ListView(
              padding: AppSpacing.pageWithFab,
              children: [
                for (final t in tickets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push(Routes.ticket(t.id)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.subject, style: Theme.of(context).textTheme.labelLarge),
                                Text('${t.category}, ${formatDate(t.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          StatusChip(t.closed ? 'Closed' : 'Open', color: t.closed ? AppColors.neutral500 : AppColors.green700),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New ticket')),
      body: SingleChildScrollView(
        padding: AppSpacing.page,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown<String>(
                label: 'Category',
                value: _category,
                items: {for (final c in ticketCategories) c: c},
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Select a category' : null,
              ),
              AppTextField(label: 'Subject', controller: _subject, validator: Validators.required),
              AppTextField(label: 'Message', controller: _message, maxLines: 4, validator: Validators.required),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  try {
                    final ticket = await ref.read(ticketsProvider.notifier).open(_subject.text, _category!, _message.text);
                    if (context.mounted) context.pushReplacement(Routes.ticket(ticket.id));
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

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(ticketsProvider).where((t) => t.id == widget.ticketId);
    if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Ticket not found'));
    final ticket = matches.first;
    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.subject),
        actions: [
          if (!ticket.closed) TextButton(onPressed: () => ref.read(ticketsProvider.notifier).close(ticket.id), child: const Text('Close')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                for (final m in ticket.messages)
                  Align(
                    alignment: m.fromCustomer ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8, left: 40),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: m.fromCustomer ? AppColors.sky100 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(m.text),
                          Text(formatDateTime(m.at), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (ticket.closed)
            const Padding(padding: EdgeInsets.all(12), child: Text('This ticket is closed.'))
          else
            SafeArea(
              child: Container(
                color: Colors.white,
                padding: AppSpacing.bottomBar,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(controller: _reply, decoration: const InputDecoration(hintText: 'Enter your message')),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      icon: const Icon(Icons.send, color: AppColors.sky700),
                      onPressed: () async {
                        if (_reply.text.trim().isEmpty) return;
                        try {
                          await ref.read(ticketsProvider.notifier).reply(ticket.id, _reply.text);
                          _reply.clear();
                        } catch (e) {
                          if (context.mounted) showMessage(context, '$e', isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
