import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/update_data.dart';
import '../../identity.dart';
import '../discover/discover_dialog.dart';
import 'simple_panes.dart';
import 'whats_new.dart';

/// About: the version, the developer, the code and its licence, what it is
/// built on, and the disclaimer. GPL-3.0 expects the copyright notice and
/// the absence of warranty to be found **inside the program**, not in the
/// repository alone.
class AboutPane extends ConsumerWidget {
  const AboutPane({super.key});

  static const _github = 'https://github.com/sagheerys';
  static const _x = 'https://x.com/Sagheer700';
  static const _repo = 'https://github.com/sagheerys/metube-mobile';
  static const _metube = 'https://github.com/alexta69/metube';
  static const _ytdlp = 'https://github.com/yt-dlp/yt-dlp';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final version = ref.watch(installedVersionProvider).valueOrNull;
    Widget link(String title, String shown, String url, {String? hint}) =>
        SettingLine(
          title: title,
          hint: hint,
          trailing: MTLinkButton(
            label: shown,
            icon: MTIcons.external,
            onPressed: () => unawaited(
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
          ),
        );
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: MTSpace.lg, bottom: MTSpace.xxs),
      child: Text(title, style: text.titleSmall?.copyWith(color: p.ink)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(
          title: EmberIdentity.displayName,
          // Without the build number: "+1" is the build tool's counter and
          // means nothing to the reader.
          value: version == null ? null : '${l.version} $version',
          hint: '${l.copyright} · ${l.licensedUnder}',
          trailing: MTLinkButton(
            label: l.whatsNewThisVersion,
            onPressed: () => unawaited(showWhatsNewNow(context, ref)),
          ),
        ),
        SettingLine(
          title: l.desktopDiscover,
          hint: l.desktopDiscoverHint,
          trailing: MTLinkButton(
            label: l.desktopDiscoverShow,
            onPressed: () => unawaited(showDiscoverDialog(context)),
          ),
        ),
        heading(l.developer),
        link(l.developerName, 'github.com/sagheerys', _github),
        link('X', 'x.com/Sagheer700', _x),
        link(l.reportBug, 'metube-mobile/issues', '$_repo/issues'),
        heading(l.sourceCode),
        link(l.sourceCode, 'sagheerys/metube-mobile', _repo),
        SettingLine(
          title: l.licenses,
          trailing: MTLinkButton(
            label: l.licenses,
            onPressed: () => showLicensePage(
              context: context,
              applicationName: EmberIdentity.displayName,
              applicationVersion: version,
              // The licences page lists the packages alone; the app's own
              // licence is passed here, or it would appear nowhere.
              applicationLegalese: '${l.copyright}\n${l.licensedUnder}',
            ),
          ),
        ),
        heading(l.builtWith),
        link('MeTube', 'alexta69/metube', _metube, hint: l.metubeCredit),
        link('yt-dlp', 'yt-dlp/yt-dlp', _ytdlp, hint: l.ytdlpCredit),
        heading(l.disclaimer),
        // The disclaimer of affiliation first: the name says what the app
        // connects to, not who made it.
        Text(
          l.notAffiliated,
          style: text.bodySmall?.copyWith(
            color: p.ink2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MTSpace.xs),
        Text(l.disclaimerText, style: text.bodySmall?.copyWith(color: p.ink2)),
      ],
    );
  }
}
