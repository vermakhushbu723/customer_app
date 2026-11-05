import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

abstract final class ContactLauncher {
  static Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  static Future<bool> whatsapp({String number = AppConstants.whatsappNumber, String message = ''}) => launchUrl(
    Uri.https('wa.me', '/$number', message.isEmpty ? null : {'text': message}),
    mode: LaunchMode.externalApplication,
  );

  /// Opens WhatsApp's own contact picker with the text ready to send.
  static Future<bool> shareOnWhatsapp(String message) =>
      launchUrl(Uri.https('wa.me', '/', {'text': message}), mode: LaunchMode.externalApplication);

  static Future<bool> website([String url = AppConstants.website]) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
