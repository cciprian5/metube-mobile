import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icon_data.dart';
import '../icons/mt_icons.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A group of settings in its own box, under a small heading. The rows are
/// parted by a hairline **that starts where the text starts**, so the icons
/// stand in a clean column down the box.
class MTBoxedGroup extends StatelessWidget {
  const MTBoxedGroup({super.key, required this.title, required this.rows});

  final String title;
  final List<MTBoxedRow> rows;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final corners = MTCorners.desktop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MTBoxedRow.sidePad,
            MTSpace.sm,
            MTBoxedRow.sidePad,
            MTSpace.xxs,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall!
                .copyWith(color: p.ink3),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(
              color: p.line,
              width: MTThemeX.of(context).hairline,
            ),
            borderRadius: BorderRadius.circular(corners.card),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(corners.card),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: p.line,
                      indent: MTBoxedRow.textStart,
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of a [MTBoxedGroup]: an icon, the title with an optional line
/// beneath, and **the current value beside the chevron**, so the page
/// answers "how is this set?" without opening anything. Or a [trailing]
/// control, such as an MTSwitch, in place of the value.
class MTBoxedRow extends StatelessWidget {
  const MTBoxedRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  final MTIconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const sidePad = 14.0;
  static const _icon = 20.0;
  static const _minHeight = 52.0;

  /// Where the text, and so the hairline above the next row, begins.
  static const textStart = sidePad + _icon + MTSpace.md;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: p.cardAlt,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: sidePad),
            child: Row(
              children: [
                MTIcon(icon, size: _icon, color: p.ink2),
                const SizedBox(width: MTSpace.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: text.bodySmall!.copyWith(color: p.ink3),
                          ),
                      ],
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: MTSpace.sm),
                  Text(value!, style: text.bodySmall!.copyWith(color: p.ink3)),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: MTSpace.sm),
                  trailing!,
                ] else if (onTap != null)
                  // The chevron points the way the page will slide in.
                  MTIcon(
                    rtl ? MTIcons.back : MTIcons.forward,
                    size: 16,
                    color: p.ink3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
