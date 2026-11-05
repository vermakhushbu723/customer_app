/// Business details published on iceclubstore.in.
abstract final class AppConstants {
  static const appName = 'ICECLUB';
  static const companyName = 'ICECLUB';
  static const serviceArea = 'Mumbai, Thane, Navi Mumbai & Palghar';
  static const supportPhone = '+917009090977';
  static const whatsappNumber = '917009090977';
  static const website = 'https://iceclubstore.in';

  static const logo = 'assets/images/app_logo.png';

  // Placeholders: confirm these with the business before going live.
  // The server's values replace these when they arrive, so an admin change reaches the bill.
  static double minOrderValue = 99.0;
  static double freeDeliveryAbove = 499.0;
  static double deliveryFee = 49.0;
  static double expressFee = 39.0;
  static double referralReward = 50.0;
  static int pointsPerRupees = 10; // one reward point for every ₹10 on a delivered order
  static int pointsToRedeem = 100; // the smallest number of points that can be redeemed
  static double rupeesPerPoint = 0.1;

  /// PIN code starts this app delivers to. Placeholder until the real list is confirmed.
  static List<String> servicePinPrefixes = const ['400', '401', '410', '421'];

  /// Slot label and the hour it starts.
  static const deliverySlots = [
    ('6 AM - 9 AM', 6),
    ('9 AM - 12 PM', 9),
    ('12 PM - 3 PM', 12),
    ('3 PM - 6 PM', 15),
    ('6 PM - 9 PM', 18),
  ];

  /// A same-day slot can be booked until this many hours before it starts.
  static const slotLeadHours = 2;

  static void applyServerConfig(Map<String, dynamic> config) {
    final charges = config['charges'] as Map<String, dynamic>;
    minOrderValue = (charges['minOrder'] as num).toDouble();
    freeDeliveryAbove = (charges['freeDeliveryAbove'] as num).toDouble();
    deliveryFee = (charges['deliveryFee'] as num).toDouble();
    expressFee = (charges['expressFee'] as num).toDouble();
    referralReward = (charges['referralReward'] as num).toDouble();
    pointsPerRupees = (charges['pointsPerRupees'] as num).toInt();
    pointsToRedeem = (charges['pointsToRedeem'] as num).toInt();
    rupeesPerPoint = (charges['rupeesPerPoint'] as num).toDouble();
    servicePinPrefixes = (config['servicePinPrefixes'] as List).cast<String>();
  }

  static const stores = [('Andheri', '918282884949'), ('Goregaon West', '919889881970'), ('Worli', '919920090037')];
}
