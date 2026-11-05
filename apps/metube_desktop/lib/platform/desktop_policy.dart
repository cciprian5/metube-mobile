import 'package:mt_core/mt_core.dart';

/// What this app **should** do, whatever the machine can. These are the
/// Windows app's product rules, kept in one place so a screen never
/// re-decides them.
class DesktopPolicy {
  const DesktopPolicy();

  /// Clips stay on the server after they finish, as in Super. A computer
  /// that pulls a copy keeps it beside the server's, never instead of it.
  DeletePolicy get deletePolicy => DeletePolicy.keepOnServer;

  /// Saving a clip into a folder on this computer, the Lite habit, is
  /// offered here too; it copies and never deletes from the server.
  bool shouldOfferDownloadToFolder() => true;

  /// Always false: a computer sits on one network for hours, and picking an
  /// address by itself would surprise the user more than it helps. The
  /// address is chosen by hand.
  bool shouldSwitchAddressesAutomatically() => false;
}
