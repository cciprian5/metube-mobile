import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../device_pulls.dart';
import '../share_flow.dart';

/// How far a copy to this phone has got: a bar, the size so far of the
/// whole, the speed, and the share done. One look for the share sheet and
/// the downloads screen.
class PhonePullProgress extends StatelessWidget {
  const PhonePullProgress({required this.pull, super.key});

  /// Null for the moment before the copy has begun.
  final DevicePull? pull;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final small = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: p.ink2);
    final pull = this.pull;
    final progress = pull?.progress;
    final rate = pull?.rate;
    final line = [
      if (pull != null)
        pull.total > 0
            ? l10n.shareProgressOf(
                mtFormatSize(pull.received),
                mtFormatSize(pull.total),
              )
            : mtFormatSize(pull.received),
      if (rate != null) mtFormatTransferRate(rate),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

/// The copies to this phone, at the top of the downloads screen. Apart
/// from the server's downloads on purpose: they are not counted with them
/// and do not move the download arrow, which both stand for the server.
class PhonePullsSection extends ConsumerWidget {
  const PhonePullsSection({required this.pulls, super.key});

  final List<DevicePull> pulls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.phoneCopiesSection,
            style: text.labelLarge!.copyWith(color: p.ink2),
          ),
          for (final pull in pulls)
            Padding(
              key: ValueKey(DevicePull.keyOf(pull.kind, pull.url)),
              padding: const EdgeInsets.only(top: MTSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MTIcon(
                    pull.kind == PullKind.share
                        ? MTIcons.share
                        : MTIcons.offline,
                    color: p.ink2,
                  ),
                  const SizedBox(width: MTSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          pull.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                        Text(
                          pull.kind == PullKind.share
                              ? l10n.sharePreparing
                              : l10n.pullingToDevice,
                          style: text.labelSmall!.copyWith(color: p.ink3),
                        ),
                        const SizedBox(height: MTSpace.xs),
                        PhonePullProgress(pull: pull),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    icon: MTIcon(MTIcons.close, color: p.ink2),
                    onPressed: () => pull.kind == PullKind.share
                        ? ref.read(shareFlowProvider.notifier).cancel()
                        : ref
                              .read(devicePullsProvider.notifier)
                              .cancel(PullKind.offline, pull.url),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
