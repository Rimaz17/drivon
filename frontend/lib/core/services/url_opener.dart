import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app (a PDF in the system viewer or browser).
class UrlOpener {
  /// False when no app could open [url].
  Future<bool> openExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

final urlOpenerProvider = Provider<UrlOpener>((ref) => UrlOpener());
