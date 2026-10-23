import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The platform's name for the interface: a site's own name as it is, and
/// the one platform that has none (anything else) in the user's language,
/// as in the phone apps.
String platformLabel(MTLocalizations l10n, MediaPlatform platform) =>
    platform == MediaPlatform.other ? l10n.platformOther : platform.label;
