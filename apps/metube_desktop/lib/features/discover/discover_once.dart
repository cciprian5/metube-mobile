import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../data/setup_data.dart';
import '../../data/update_data.dart';
import '../../di.dart';
import '../settings/updates_pane.dart';
import '../setup/setup_dialog.dart';
import 'discover_dialog.dart';

/// Set when the first setup closed with no server: Discover waits for the
/// first start that has one.
const discoverPendingKey = 'ember_discover_pending';

/// **What opens by itself at start, one thing at most.** The first start
/// with no server opens the setup and, once a server is set, "Discover
/// MeTube Ember": a first install has nothing "new" to tell, so the notes
/// that link to Discover never came, and the features went unseen. Every
/// later start may show what is new in an update, which links to Discover
/// itself; someone who updates is never shown Discover unasked.
Future<void> startupOffers(BuildContext context, WidgetRef ref) async {
  final store = ref.read(keyValueStoreProvider);
  if (ref.read(offerSetupAtStartProvider) &&
      ref.read(serverSetupProvider) == null) {
    await showSetupDialog(context);
    if (!context.mounted) return;
    if (ref.read(serverSetupProvider) == null) {
      // "Later": the library's button opens the setup again.
      await store.setBool(discoverPendingKey, true);
      return;
    }
    await showDiscoverDialog(context);
    return;
  }
  // Still waiting for a server, an update's notes come as usual.
  if ((await store.getBool(discoverPendingKey) ?? false) &&
      ref.read(serverSetupProvider) != null &&
      context.mounted) {
    await store.remove(discoverPendingKey);
    if (context.mounted) await showDiscoverDialog(context);
    return;
  }
  if (ref.read(offerWhatsNewProvider) && context.mounted) {
    await startupNotes(context, ref);
  }
}
