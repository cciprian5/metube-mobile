import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/appearance_data.dart';
import '../../shell/pill.dart';
import '../../shell/ui_zoom.dart';

/// Day or night, the language, and the interface size. Each follows
/// Windows (or 100%) until chosen, and each is this computer's alone.
class AppearancePane extends ConsumerWidget {
  const AppearancePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final look = ref.watch(appearanceProvider);
    final appearance = ref.read(appearanceProvider.notifier);
    final zoom = ref.watch(uiZoomProvider);
    final zooms = ref.read(uiZoomProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup(
          title: l.theme,
          children: [
            for (final (mode, label) in [
              (ThemeMode.system, l.themeSystem),
              (ThemeMode.light, l.themeLight),
              (ThemeMode.dark, l.themeDark),
            ])
              EmberPill(
                label: label,
                selected: look.theme == mode,
                onTap: () => appearance.setTheme(mode),
              ),
          ],
        ),
        ChoiceGroup(
          title: l.language,
          hint: look.locale == null ? l.desktopLanguageSystemHint : null,
          children: [
            EmberPill(
              label: l.languageSystem,
              selected: look.locale == null,
              onTap: () => appearance.setLocale(null),
            ),
            for (final code in appearanceLocales)
              EmberPill(
                label: mtLanguageName(code),
                selected: look.locale == code,
                onTap: () => appearance.setLocale(code),
              ),
          ],
        ),
        ChoiceGroup(
          title: l.desktopUiSize,
          // Each key name read left to right inside an Arabic sentence.
          hint: l.desktopUiSizeHint(
            mtLtrRun('Ctrl+='),
            mtLtrRun('Ctrl+−'),
            mtLtrRun('Ctrl+0'),
          ),
          children: [
            for (final step in uiZoomSteps)
              _Step(
                label: UiZoom(step).percent,
                selected: zoom.value == step,
                fits: zooms.fits(step),
                onTap: () => zooms.set(step),
              ),
          ],
        ),
      ],
    );
  }
}

/// A setting chosen among a few: its name, the choices, and a line on
/// what it does.
class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.title,
    required this.children,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.bodyLarge?.copyWith(color: p.ink)),
          const SizedBox(height: MTSpace.xs),
          Wrap(spacing: MTSpace.xs, runSpacing: MTSpace.xs, children: children),
          if (hint case final hint?) ...[
            const SizedBox(height: MTSpace.xs),
            Text(hint, style: text.labelSmall?.copyWith(color: p.ink3)),
          ],
        ],
      ),
    );
  }
}

/// One interface size; a size this screen cannot hold is shown faded and
/// says why, rather than missing.
class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.selected,
    required this.fits,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool fits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = EmberPill(label: label, selected: selected, onTap: onTap);
    if (fits || selected) return pill;
    return Tooltip(
      message: context.mtl.desktopUiSizeTooLarge,
      child: Semantics(
        enabled: false,
        child: IgnorePointer(child: Opacity(opacity: 0.4, child: pill)),
      ),
    );
  }
}
