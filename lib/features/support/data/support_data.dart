import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../domain/ticket.dart';

const ticketCategories = ['Order or delivery', 'Payment or refund', 'Product quality', 'Subscription', 'Account', 'Something else'];

const faqs = <(String, List<(String, String)>)>[
  ('Orders and delivery', [
    ('Where do you deliver?', 'We deliver in Mumbai, Thane, Navi Mumbai and Palghar. Enter your PIN code on the delivery check screen to confirm.'),
    ('How fast is express delivery?', 'Express orders aim to arrive within 60 minutes, for a small extra fee. Availability depends on your area.'),
    ('Why do you ask for an OTP on delivery?', 'The OTP confirms that the order reached you. Share it with the rider only when you have your ice.'),
    ('Can I cancel my order?', 'Yes, until it leaves with the rider. Open the order and tap Cancel order.'),
  ]),
  ('Payments and refunds', [
    ('How do refunds work?', 'When you cancel a paid order, the money goes to your ICECLUB wallet straight away.'),
    ('Is cash on delivery available?', 'Yes. You can pay the rider in cash when your ice arrives.'),
    ('Can I take money out of the wallet?', 'Wallet money can be spent on ICECLUB orders. Contact support for help with a refund.'),
  ]),
  ('Ice and safety', [
    ('Which ice can I put in drinks?', 'Use tube ice or cube ice in drinks. Crushed, block and slab ice are for chilling only, and are not for human consumption.'),
    ('How do I handle dry ice safely?', 'Wear insulated gloves, keep it in a ventilated place, and never eat it, touch it with bare hands or seal it in an airtight container.'),
    ('How long will the ice last?', 'That depends on the weather and how it is stored. An insulated ice box keeps it frozen for much longer.'),
  ]),
  ('Subscriptions', [
    ('How does a subscription work?', 'Choose a product, a quantity and how often you want it. You can pause, skip a day or cancel at any time.'),
    ('When do I pay for a subscription?', 'You pay for each delivery when it arrives.'),
  ]),
];

class TicketsController extends ListStore<Ticket> {
  @override
  String get key => 'tickets';
  @override
  String get path => '/customer/tickets';
  @override
  Ticket fromJson(Json json) => Ticket.fromJson(json);
  @override
  Json toJson(Ticket item) => item.toJson();

  Future<Ticket> open(String subject, String category, String message) async {
    if (!useFakeBackend) {
      final body = await api.post('/customer/tickets', {'subject': subject, 'category': category, 'message': message});
      final ticket = Ticket.fromJson(body as Map<String, dynamic>);
      save([ticket, ...state]);
      return ticket;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ticket = Ticket(
      id: id,
      subject: subject.trim(),
      category: category,
      messages: [TicketMessage(text: message.trim(), fromCustomer: true, at: DateTime.now())],
    );
    save([ticket, ...state]);
    return ticket;
  }

  Future<void> reply(String id, String text) async {
    if (!useFakeBackend) {
      final body = await api.post('/customer/tickets/$id/reply', {'message': text});
      final saved = Ticket.fromJson(body as Map<String, dynamic>);
      save([for (final t in state) t.id == id ? saved : t]);
      return;
    }
    save([
      for (final t in state)
        t.id == id ? t.copyWith(messages: [...t.messages, TicketMessage(text: text.trim(), fromCustomer: true, at: DateTime.now())]) : t,
    ]);
  }

  Future<void> close(String id) async {
    if (!useFakeBackend) await api.post('/customer/tickets/$id/resolve');
    save([for (final t in state) t.id == id ? t.copyWith(closed: true) : t]);
  }
}

final ticketsProvider = NotifierProvider<TicketsController, List<Ticket>>(TicketsController.new);
