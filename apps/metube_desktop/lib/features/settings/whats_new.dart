import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/update_data.dart';
import '../../di.dart';
import '../../shell/shell_metrics.dart';

final whatsNewServiceProvider = Provider(
  (ref) => WhatsNewService(
    prefs: UpdatePrefs(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ),
    checker: ref.watch(updateCheckerProvider),
  ),
);

/// At start-up: the notes of a version newer than the last one shown,
/// once. A first install only records where it starts, and every failure
/// means "nothing to show".
Future<void> maybeShowWhatsNew(BuildContext context, WidgetRef ref) async {
  final WhatsNew? pending;
  try {
    final version = await ref.read(installedVersionProvider.future);
    // Windows says nothing of an install over an older copy; the version
    // recorded at the first start stands in for it.
    pending = await ref
        .read(whatsNewServiceProvider)
        .pending(currentVersion: version, upgraded: false);
  } on Object {
    return;
  }
  if (pending == null || !context.mounted) return;
  await ref.read(whatsNewServiceProvider).markSeen(pending.version);
  if (context.mounted) unawaited(showWhatsNewDialog(context, pending));
}

/// The notes of the version running now, on request from About.
Future<void> showWhatsNewNow(BuildContext context, WidgetRef ref) async {
  final WhatsNew? notes;
  try {
    final version = await ref.read(installedVersionProvider.future);
    notes = await ref.read(whatsNewServiceProvider).of(version);
  } on Object {
    return;
  }
  if (notes != null && context.mounted) {
    await showWhatsNewDialog(context, notes);
  }
}

/// "What's new" in the middle of the window, as a computer shows it, not
/// a sheet from the bottom edge as on the phone.
Future<void> showWhatsNewDialog(BuildContext context, WhatsNew notes) {
  final l = context.mtl;
  final p = MTThemeX.of(context).palette;
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final body = mtReleaseNotesFor(
    notes.notes,
    arabic: arabic,
    app: 'ember',
  ).trim();
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Row(
        children: [
          MTIcon(MTIcons.info, color: p.accent),
          const SizedBox(width: MTSpace.sm),
          Expanded(child: Text(l.whatsNewTitle(notes.version))),
        ],
      ),
      content: SizedBox(
        width: EmberShellSize.addDialog,
        child: SingleChildScrollView(
          child: body.isEmpty
              ? Text(l.whatsNewUnavailable)
              : MTMarkdownText(source: body),
        ),
      ),
      actions: [
        MTLinkButton(
          label: l.whatsNewReleasePage,
          icon: MTIcons.external,
          onPressed: () => unawaited(
            launchUrl(
              Uri.parse(notes.pageUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(l.whatsNewGotIt),
        ),
      ],
    ),
  );
}
