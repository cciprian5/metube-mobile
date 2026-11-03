import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/error_text.dart';
import '../library_actions.dart';
import '../share_flow.dart';

bool _asking = false;
bool _sheetOpen = false;

/// Shares [item]: at once when the phone has a copy, otherwise after
/// pulling one, with a sheet that shows how far it has got.
///
/// A share already running is shown rather than started again, so a
/// second tap on any clip opens the same sheet.
Future<void> shareClip(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) async {
  final local = item.localPath;
  if (local != null) return ref.read(shareSendProvider)(local);
  if (ref.read(shareFlowProvider) == null) {
    if (_asking) return;
    if (!ref.read(libraryActionsProvider).canPullNow) {
      throw const NetworkException(wifiOnlyRejection);
    }
    if (item.serverFilename == null) throw const UnsafeFilenameException();
    final size = item.sizeBytes;
    if (size != null && size >= shareConfirmBytes) {
      _asking = true;
      final go = await _confirmLarge(
        context,
        size,
      ).whenComplete(() => _asking = false);
      if (!go || !context.mounted) return;
    }
    unawaited(ref.read(shareFlowProvider.notifier).start(item));
  }
  if (_sheetOpen) return;
  _sheetOpen = true;
  unawaited(
    showMTSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const ShareSheet(),
    ).whenComplete(() => _sheetOpen = false),
  );
}

Future<bool> _confirmLarge(BuildContext context, int size) {
  final l10n = context.mtl;
  return showMTConfirm(
    context,
    title: l10n.shareLargeTitle(mtFormatSize(size)),
    message: l10n.shareLargeBody,
    confirmLabel: l10n.download,
    cancelLabel: l10n.cancel,
  );
}

/// How far the copy for a share has got, with a way out. Closing the sheet
/// does not stop the copy: the share menu still opens when it is done.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key});

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late final ShareFlow _flow = ref.read(shareFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    _flow.watched = true;
  }

  @override
  void dispose() {
    _flow.sheetClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shareFlowProvider, (_, next) {
      if (next == null && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    });
    final job = ref.watch(shareFlowProvider);
    if (job == null) return const SizedBox.shrink();
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.lg,
        MTSpace.xl,
        mtSheetBottomPad(context, MTSpace.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (job.phase) {
            SharePhase.pulling => l10n.sharePreparing,
            SharePhase.ready => l10n.shareReady,
            SharePhase.failed => l10n.failed,
          }, style: text.titleMedium),
          const SizedBox(height: MTSpace.xs),
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: p.ink2),
          ),
          const SizedBox(height: MTSpace.lg),
          ...switch (job.phase) {
            SharePhase.pulling => _pulling(job, l10n, p, text),
            SharePhase.ready => [
              FilledButton.icon(
                onPressed: () => unawaited(_flow.sendReady()),
                icon: const MTIcon(MTIcons.share, size: 18),
                label: Text(l10n.share),
              ),
              TextButton(onPressed: _flow.cancel, child: Text(l10n.cancel)),
            ],
            SharePhase.failed => [
              Text(
                errorText(l10n, job.error!),
                style: text.bodyMedium!.copyWith(color: p.err),
              ),
              const SizedBox(height: MTSpace.sm),
              TextButton(onPressed: _flow.dismiss, child: Text(l10n.done)),
            ],
          },
        ],
      ),
    );
  }

  List<Widget> _pulling(
    ShareJob job,
    MTLocalizations l10n,
    MTPalette p,
    TextTheme text,
  ) {
    final progress = job.progress;
    final rate = job.rate;
    final line = [
      job.total > 0
          ? l10n.shareProgressOf(
              mtFormatSize(job.received),
              mtFormatSize(job.total),
            )
          : mtFormatSize(job.received),
      if (rate != null) mtFormatTransferRate(rate),
    ].join(' · ');
    final small = text.labelSmall!.copyWith(color: p.ink2);
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(MTRadius.pill),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          // Both colours from the palette, as in the update sheet: the
          // Material track comes out greenish over the Wahaj ground.
          backgroundColor: p.accent.withValues(alpha: 0.16),
          valueColor: AlwaysStoppedAnimation(p.accent),
        ),
      ),
      const SizedBox(height: MTSpace.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(line, style: small)),
          if (progress != null) ...[
            const SizedBox(width: MTSpace.sm),
            Text(mtLtrRun('${(progress * 100).floor()}%'), style: small),
          ],
        ],
      ),
      const SizedBox(height: MTSpace.sm),
      TextButton(onPressed: _flow.cancel, child: Text(l10n.cancel)),
    ];
  }
}
