import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icons.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../wahaj/mt_empty_frame.dart';
import '../wahaj/mt_link_button.dart';
import '../wahaj/mt_notice.dart';
import '../wahaj/mt_progress.dart';

/// The second half of [MTWahajGallery]: the components that move (progress,
/// touch, notices) and the empty screen. Fixed sample strings, outside the
/// arb rule, like the rest of the gallery.
class MTWahajGalleryMotion extends StatelessWidget {
  const MTWahajGalleryMotion({super.key, required this.arabic});

  final bool arabic;

  String t(String ar, String en) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: MTSpace.xl, bottom: MTSpace.xs),
      child: Text(s, style: text.titleMedium!.copyWith(color: p.ink3)),
    );
    Widget notice(MTNoticeKind kind, String msg, {String? action}) => Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.miniBg,
          borderRadius: BorderRadius.circular(MTCorners.desktop.card),
        ),
        child: MTNotice(
          message: msg,
          kind: kind,
          actionLabel: action,
          onAction: () {},
          icon: kind == MTNoticeKind.info ? MTIcons.copy : null,
          duration: const Duration(hours: 1),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(t('الانتظار والتقدم', 'Waiting and progress')),
        Row(
          children: [
            const MTSpinner(),
            const SizedBox(width: MTSpace.xl),
            const Expanded(child: MTFilmStrip()),
            const SizedBox(width: MTSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('يحمّل… 62٪', 'Loading… 62%'), style: text.bodySmall),
                  const MTProgressBar(value: 0.62),
                ],
              ),
            ),
          ],
        ),
        label(t('الأزرار واللمس', 'Buttons and touch')),
        Wrap(
          spacing: MTSpace.lg,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(onPressed: () {}, icon: const MTIcon(MTIcons.list)),
            IconButton(onPressed: () {}, icon: const MTIcon(MTIcons.queue)),
            MTLinkButton(label: t('عرض الكل', 'See all'), onPressed: () {}),
          ],
        ),
        label(t('الإشعار السفلي', 'Notices')),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              notice(
                MTNoticeKind.done,
                t('بدأ التنزيل', 'Download started'),
                action: t('تراجع', 'Undo'),
              ),
              notice(
                MTNoticeKind.failed,
                t('تعذّر الوصول إلى السيرفر', 'Could not reach the server'),
              ),
              notice(MTNoticeKind.info, t('نُسخ الرابط', 'Link copied')),
            ],
          ),
        ),
        label(t('الشاشة الفارغة', 'Empty screen')),
        MTEmptyFrame(
          title: t('المكتبة فارغة', 'The library is empty'),
          message: t(
            'شارك رابطاً من أي تطبيق، أو الصقه هنا.',
            'Share a link from any app, or paste it here.',
          ),
          actionLabel: t('الصق رابطاً', 'Paste a link'),
          actionIcon: MTIcons.addlink,
          onAction: () {},
        ),
      ],
    );
  }
}
