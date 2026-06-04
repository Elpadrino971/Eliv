import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/user_model.dart';

/// TEMPORARY — demo data used to preview [TicketPassCard] in the Tickets
/// screen when the user has not bought any ticket yet.
///
/// This is purely for design review. Remove [demoTicketEvent] and its usage in
/// `my_tickets_screen.dart` once a real ticket can be purchased through the app.
Event demoTicketEvent() => Event(
  id: 0,
  name: 'After Hours Tour',
  status: 'published',
  coverImage: 'demo_ticket.png', // 404 -> ImageWidget placeholder, fine for demo
  ticketPrice: '560',
  startDateTime: DateTime(2025, 12, 26, 19, 30),
  artist: User(
    artistName: 'The Weeknd',
    fullName: 'The Weeknd',
    address: 'Accor Arena, Paris',
    artistProfile: 'demo_artist.png',
  ),
  tickets: [
    Ticket(
      id: 0,
      eventId: 0,
      pricePaid: '560',
      receiptNumber: 'VBZ-1245-6789',
      status: 'active',
    ),
  ],
);
