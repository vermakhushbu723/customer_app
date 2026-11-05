import '../../../core/storage/local_store.dart';

class TicketMessage {
  const TicketMessage({required this.text, required this.fromCustomer, required this.at});

  final String text;
  final bool fromCustomer;
  final DateTime at;

  Json toJson() => {'text': text, 'fromCustomer': fromCustomer, 'at': at.toIso8601String()};

  factory TicketMessage.fromJson(Json j) => TicketMessage(text: j['text'] as String, fromCustomer: j['fromCustomer'] as bool, at: DateTime.parse(j['at'] as String));
}

class Ticket {
  const Ticket({required this.id, required this.subject, required this.category, required this.messages, this.closed = false});

  final String id;
  final String subject;
  final String category;
  final List<TicketMessage> messages;
  final bool closed;

  DateTime get updatedAt => messages.last.at;

  Ticket copyWith({List<TicketMessage>? messages, bool? closed}) =>
      Ticket(id: id, subject: subject, category: category, messages: messages ?? this.messages, closed: closed ?? this.closed);

  Json toJson() => {'id': id, 'subject': subject, 'category': category, 'messages': messages.map((m) => m.toJson()).toList(), 'closed': closed};

  factory Ticket.fromJson(Json j) => Ticket(
    id: j['id'] as String,
    subject: j['subject'] as String,
    category: j['category'] as String,
    messages: (j['messages'] as List).cast<Json>().map(TicketMessage.fromJson).toList(),
    closed: j['closed'] as bool? ?? false,
  );
}
