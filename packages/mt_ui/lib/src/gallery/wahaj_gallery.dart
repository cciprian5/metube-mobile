import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icons.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../wahaj/mt_badge.dart';
import '../wahaj/mt_boxed_settings.dart';
import '../wahaj/mt_confirm_dialog.dart';
import '../wahaj/mt_shortcut_tooltip.dart';
import '../wahaj/mt_switch.dart';

/// An internal sheet of the Wahaj components, for reviewing them by eye in
/// both themes and both directions. **Not a product screen**: its strings
/// are fixed samples on purpose, outside the arb rule, like
/// `MTGalleryScreen`.
class MTWahajGallery extends StatefulWidget {
  const MTWahajGallery({super.key, this.arabic = true});

  final bool arabic;

  @override
  State<MTWahajGallery> createState() => _MTWahajGalleryState();
}

class _MTWahajGalleryState extends State<MTWahajGallery> {
  bool _wifi = true;
  bool _notify = false;
  bool _check = true;
  int _radio = 1;

  String t(String ar, String en) => widget.arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: MTSpace.xl, bottom: MTSpace.xs),
      child: Text(s, style: text.titleMedium!.copyWith(color: p.ink3)),
    );
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(MTSpace.xxl),
          children: [
            Text(
              t('مكوّنات وهج', 'Wahaj components'),
              style: text.headlineLarge,
            ),
            label(t('المفتاح', 'Switch')),
            Wrap(
              spacing: MTSpace.xl,
              children: [
                MTSwitch(value: true, onChanged: (_) {}),
                MTSwitch(value: false, onChanged: (_) {}),
                const MTSwitch(value: true, onChanged: null),
              ],
            ),
            label(t('الاختيار والشارة', 'Choice and badge')),
            Wrap(
              spacing: MTSpace.lg,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Checkbox(
                  value: _check,
                  onChanged: (v) => setState(() => _check = v!),
                ),
                Checkbox(value: false, onChanged: (_) {}),
                RadioGroup<int>(
                  groupValue: _radio,
                  onChanged: (v) => setState(() => _radio = v!),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Radio<int>(value: 1), Radio<int>(value: 2)],
                  ),
                ),
                const MTBadge(count: 3),
                const MTBadge(count: 120),
                MTShortcutTooltip(
                  message: t('نزّل إلى الجهاز', 'Download to this computer'),
                  shortcut: 'Ctrl+D',
                  child: const MTIcon(MTIcons.download),
                ),
              ],
            ),
            label(t('صفوف الإعدادات', 'Settings rows')),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: MTBoxedGroup(
                title: t('التشغيل والتنزيل', 'Playback and download'),
                rows: [
                  MTBoxedRow(
                    icon: MTIcons.appearance,
                    title: t('المظهر', 'Appearance'),
                    subtitle: t('يتبع النظام', 'Follows the system'),
                    value: t('النظام', 'System'),
                    onTap: () {},
                  ),
                  MTBoxedRow(
                    icon: MTIcons.download,
                    title: t('Wi‑Fi فقط', 'Wi‑Fi only'),
                    subtitle: t(
                      'لا تنزيل على البيانات',
                      'No downloads on data',
                    ),
                    trailing: MTSwitch(
                      value: _wifi,
                      onChanged: (v) => setState(() => _wifi = v),
                    ),
                  ),
                  MTBoxedRow(
                    icon: MTIcons.subscriptions,
                    title: t('إشعار الاكتمال', 'Notify when done'),
                    trailing: MTSwitch(
                      value: _notify,
                      onChanged: (v) => setState(() => _notify = v),
                    ),
                  ),
                ],
              ),
            ),
            label(t('الحوار', 'Dialog')),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MTConfirmDialog(
                title: t('حذف المقطع؟', 'Delete the clip?'),
                message: t(
                  'سيُحذف الملف من السيرفر نهائياً، ولا يمكن التراجع.',
                  'The file is removed from the server for good.',
                ),
                confirmLabel: t('احذف', 'Delete'),
                cancelLabel: t('إلغاء', 'Cancel'),
                destructive: true,
                preview: MTDialogClip(
                  title: t(
                    'رحلة إلى وادي رم · 12:40',
                    'Trip to Wadi Rum · 12:40',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
