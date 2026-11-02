import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'phone_sync.dart';

/// A device as the user knows it: the kind, and the short part of its name
/// that tells two of them apart.
String syncDeviceName(MTLocalizations l10n, String id) {
  final dash = id.indexOf('-');
  final tail = dash < 0 ? id : id.substring(dash + 1);
  return id.startsWith('phone')
      ? l10n.desktopSyncPhone(tail)
      : l10n.desktopSyncComputer(tail);
}

/// The folder as the user picked it ("Sync"), not the system's address
/// for it (`content://…/tree/primary%3ASync`).
String syncFolderName(String tree) {
  final last = Uri.decodeComponent(tree.split('/tree/').last);
  final colon = last.indexOf(':');
  return colon < 0 ? last : last.substring(colon + 1);
}

/// **Sync with the computer** (off until a folder is chosen): the folder,
/// this phone's name in it, when each other device last wrote, and
/// forgetting one.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  Future<void> _choose(WidgetRef ref) async {
    if (await ref.read(phoneSyncSettingsProvider.notifier).choose()) {
      await ref.read(phoneSyncProvider).run();
    }
  }

  Future<void> _forget(
    BuildContext context,
    WidgetRef ref,
    SyncDevice device,
  ) async {
    final l10n = context.mtl;
    final sure = await showMTDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.desktopSyncForget),
        content: Text(
          l10n.syncPhoneForgetBody(syncDeviceName(l10n, device.id)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.desktopSyncForget),
          ),
        ],
      ),
    );
    if (sure == true) await ref.read(phoneSyncProvider).forget(device);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(phoneSyncSettingsProvider).valueOrNull;
    final report = ref.watch(phoneSyncReportProvider);
    final on = settings?.on ?? false;
    final small = text.bodySmall!.copyWith(color: p.ink3);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: MTReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad,
            MTSpace.md,
            MTSpace.pagePad,
            MTSpace.xxl,
          ),
          children: [
            Text(l10n.syncPhoneHint, style: text.bodyMedium),
            const SizedBox(height: MTSpace.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: MTIcon(MTIcons.folder, color: p.ink2),
              title: Text(l10n.desktopSyncFolder),
              subtitle: Text(
                on ? syncFolderName(settings!.tree!) : l10n.syncPhoneOff,
                style: text.bodySmall,
              ),
            ),
            // Under the line, not at its end: a long label at a large text
            // size would take the whole width of a small phone.
            Wrap(
              spacing: MTSpace.sm,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(_choose(ref)),
                  icon: const MTIcon(MTIcons.folder),
                  label: Text(l10n.desktopSyncChoose),
                ),
                if (on)
                  TextButton(
                    onPressed: () => unawaited(
                      ref.read(phoneSyncSettingsProvider.notifier).turnOff(),
                    ),
                    child: Text(l10n.desktopSyncTurnOff),
                  ),
              ],
            ),
            const SizedBox(height: MTSpace.sm),
            if (on) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MTIcon(MTIcons.phone, color: p.ink2),
                title: Text(
                  l10n.syncPhoneThisDevice(
                    syncDeviceName(l10n, settings!.deviceId!),
                  ),
                ),
                subtitle: switch (report) {
                  null => null,
                  PhoneSyncReport(failed: true) => Text(
                    l10n.syncPhoneFailed,
                    style: text.bodySmall!.copyWith(color: p.err),
                  ),
                  final r => Text(
                    l10n.desktopSyncLast(mtTimeAgo(context, r.at)),
                    style: text.bodySmall,
                  ),
                },
              ),
              if (report?.cameBack ?? false)
                Padding(
                  padding: const EdgeInsets.only(bottom: MTSpace.sm),
                  child: Text(
                    l10n.syncPhoneCameBack,
                    style: text.bodySmall!.copyWith(color: p.accent),
                  ),
                ),
              if (report != null && !report.failed && report.devices.isEmpty)
                Text(l10n.syncPhoneNoOthers, style: small),
              for (final device in report?.devices ?? const <SyncDevice>[])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: MTIcon(
                    device.id.startsWith('phone')
                        ? MTIcons.phone
                        : MTIcons.monitor,
                    color: p.ink2,
                  ),
                  title: Text(
                    l10n.desktopSyncFrom(
                      syncDeviceName(l10n, device.id),
                      mtTimeAgo(
                        context,
                        DateTime.fromMillisecondsSinceEpoch(
                          device.snapshot.writtenAt,
                        ),
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: l10n.desktopSyncForget,
                    icon: MTIcon(MTIcons.linkOff, color: p.ink3),
                    onPressed: () => unawaited(_forget(context, ref, device)),
                  ),
                ),
            ],
            const SizedBox(height: MTSpace.lg),
            Text(l10n.syncPhoneGuide, style: small),
            const SizedBox(height: MTSpace.sm),
            Text(l10n.desktopSyncNotBackup, style: small),
          ],
        ),
      ),
    );
  }
}
