import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/update_data.dart';
import '../../router.dart';
import 'simple_panes.dart';
import 'whats_new.dart';

/// At start-up: "what's new" for a version just installed, then a quiet
/// look for a newer one, said in a notice that opens this section.
Future<void> startupNotes(BuildContext context, WidgetRef ref) async {
  await maybeShowWhatsNew(context, ref);
  await ref.read(updateProvider.notifier).checkSilently();
  final release = ref.read(updateProvider).release;
  if (release == null || !context.mounted) return;
  final router = GoRouter.of(context);
  showMTNotice(
    context,
    message: context.mtl.updateVersionAvailable(release.version.toString()),
    icon: MTIcons.info,
    actionLabel: context.mtl.updateWhatsNew,
    onAction: () => router.go(EmberSettingsPane.updates.route),
    duration: const Duration(seconds: 10),
  );
}

/// Updates: the version running, a check on request, the one found with
/// its notes, and installing it in place.
class UpdatesPane extends ConsumerWidget {
  const UpdatesPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(updateProvider);
    final update = ref.read(updateProvider.notifier);
    final version = ref.watch(installedVersionProvider).valueOrNull;
    final checked = state.checkedAt;
    final failure = switch (state.failure) {
      UpdateFailure.check => l.updateCheckFailed,
      UpdateFailure.download => l.updateDownloadFailed,
      UpdateFailure.install => l.updateFailedToStart,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(
          title: l.version,
          value: version,
          hint: checked == null
              ? l.neverChecked
              : l.lastCheckedAt(mtTimeAgo(context, checked)),
          trailing: state.phase == UpdatePhase.checking
              ? Text(l.updateChecking, style: text.bodyMedium)
              : MTLinkButton(
                  label: l.checkNow,
                  onPressed: state.busy
                      ? null
                      : () => unawaited(update.checkNow()),
                ),
        ),
        if (state.upToDate)
          _Line(l.updateUpToDate, color: p.ink2, icon: MTIcons.check),
        if (failure != null) _Line(failure, color: p.err, icon: MTIcons.info),
        if (state.release case final release?) ...[
          const SizedBox(height: MTSpace.md),
          _Release(release: release, state: state),
        ],
        const SizedBox(height: MTSpace.md),
        SwitchLine(
          title: l.autoCheckUpdates,
          hint: l.autoCheckUpdatesHelp,
          value: state.autoCheck,
          onChanged: (on) => unawaited(update.setAutoCheck(on)),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {required this.color, required this.icon});

  final String text;
  final Color color;
  final MTIconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
    child: Row(
      children: [
        MTIcon(icon, size: MTSpace.lg, color: color),
        const SizedBox(width: MTSpace.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

/// The version found: its size, its notes, and what can be done with it.
class _Release extends ConsumerWidget {
  const _Release({required this.release, required this.state});

  final UpdateRelease release;
  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final update = ref.read(updateProvider.notifier);
    final size = release.sizeMb;
    final notes = mtReleaseNotesFor(
      release.notes,
      arabic: Localizations.localeOf(context).languageCode == 'ar',
      app: 'ember',
    ).trim();
    final downloading = state.phase == UpdatePhase.downloading;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(MTCorners.desktop.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.updateVersionAvailable(release.version.toString()),
              style: text.titleMedium?.copyWith(color: p.ink),
            ),
            if (size != null)
              Text(
                l.updateSizeMb(size.toStringAsFixed(1)),
                style: text.bodySmall?.copyWith(color: p.ink3),
              ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: MTSpace.md),
              Text(
                l.updateWhatsNew,
                style: text.labelLarge?.copyWith(color: p.ink2),
              ),
              const SizedBox(height: MTSpace.xs),
              MTMarkdownText(source: notes),
            ],
            const SizedBox(height: MTSpace.lg),
            if (downloading) ...[
              Text(l.updateDownloading, style: text.bodyMedium),
              const SizedBox(height: MTSpace.xs),
              MTProgressBar(value: state.progress),
              const SizedBox(height: MTSpace.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MTLinkButton(label: l.cancel, onPressed: update.cancel),
              ),
            ] else ...[
              Text(
                l.desktopUpdateRestartHint,
                style: text.bodySmall?.copyWith(color: p.ink3),
              ),
              const SizedBox(height: MTSpace.sm),
              Wrap(
                spacing: MTSpace.sm,
                runSpacing: MTSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => unawaited(update.install()),
                    child: Text(l.desktopUpdateInstall),
                  ),
                  MTLinkButton(
                    label: l.updateSkipVersion,
                    onPressed: () => unawaited(update.skip()),
                  ),
                  MTLinkButton(label: l.updateLater, onPressed: update.later),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
