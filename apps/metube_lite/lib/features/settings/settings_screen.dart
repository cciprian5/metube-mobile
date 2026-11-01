import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import 'settings_hub.dart';
import 'settings_sections.dart';
import 'widgets/server_keeps_files_notice.dart';
import 'widgets/server_status_card.dart';

/// **The settings home** (approved mock-up, 2026-10-14): the server card,
/// then three short groups whose rows show each setting as it stands, each
/// opening its own page. It used to be one long page that grew with every
/// feature. On a tablet held sideways the same rows open in two panes
/// ([SettingsHub]).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Kept here, above both shapes, so turning the tablet does not lose the
  /// open section.
  SettingsPane _pane = SettingsPane.server;

  @override
  Widget build(BuildContext context) {
    if (MTAdaptiveScaffold.hasEndPane(context)) {
      return SettingsHub(
        selected: _pane,
        onSelect: (pane) => setState(() => _pane = pane),
      );
    }
    final l10n = context.mtl;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: MTReadableWidth(
        child: ListView(
          // Neither the mini player nor the add button shows on this tab,
          // so the list ends just past its last card; the system's own bar
          // is added where no bottom bar takes it (an upright tablet).
          padding: EdgeInsets.fromLTRB(
            MTSpace.pagePad,
            0,
            MTSpace.pagePad,
            MTSpace.xl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const ServerStatusCard(),
            const ServerKeepsFilesNotice(),
            for (final (title, entries) in settingsGroups(context, ref))
              MTSettingsGroup(
                title: title,
                rows: [
                  for (final e in entries)
                    MTSettingsRow(
                      icon: e.icon,
                      title: e.title,
                      value: e.value,
                      onTap: () => context.go(e.pane.route),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
