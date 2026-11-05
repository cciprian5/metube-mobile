import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'simple_panes.dart';

/// The browser button: a bookmark whose address is this script, so one
/// click on a video's page opens `metube://add` with the page's link. The
/// installer registers `metube://`, and the link only opens the add
/// dialog, so a page can never add anything by itself.
const browserButtonCode =
    "javascript:location.href='metube://add?url='"
    '+encodeURIComponent(location.href)';

/// **The setup page**, written for the browser: the button ready to drag
/// to the bookmarks bar, three steps, and the code to paste for a browser
/// that will not take a dragged link. In the app's language and colours.
String browserButtonPage(MTLocalizations l, MTPalette p, {required bool rtl}) {
  String text(String value) => const HtmlEscape().convert(value);
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final code = const HtmlEscape(HtmlEscapeMode.attribute)
      .convert(browserButtonCode);
  return '''<!doctype html>
<html lang="${rtl ? 'ar' : 'en'}" dir="${rtl ? 'rtl' : 'ltr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${text(l.desktopBrowserPageTitle)}</title>
<style>
body{margin:0;background:${hex(p.bg)};color:${hex(p.ink)};
font:16px/1.7 Tajawal,"Segoe UI",Tahoma,sans-serif}
main{max-width:640px;margin:${MTSpace.xxl * 2}px auto;padding:0 ${MTSpace.lg}px}
h1{font-size:26px;margin:0 0 ${MTSpace.xl}px}
ol{padding-inline-start:${MTSpace.xl}px}li{margin:0 0 ${MTSpace.md}px}
kbd{direction:ltr;unicode-bidi:isolate;border:1px solid ${hex(p.line)};
border-radius:${MTRadius.badge}px;padding:0 ${MTSpace.xxs}px;
background:${hex(p.card)}}
.button{display:inline-block;margin:${MTSpace.xs}px 0 ${MTSpace.xxs}px;
padding:${MTSpace.sm}px ${MTSpace.xl}px;border-radius:999px;
background:${hex(p.accent)};color:${hex(p.onAccent)};
font-weight:700;text-decoration:none;cursor:grab}
.hint{color:${hex(p.ink3)};font-size:14px}
code{display:block;direction:ltr;text-align:left;word-break:break-all;
background:${hex(p.card)};border:1px solid ${hex(p.line)};
border-radius:${MTRadius.thumb}px;padding:${MTSpace.sm}px;
margin-top:${MTSpace.xs}px;user-select:all}
</style>
</head>
<body><main>
<h1>${text(l.desktopBrowserPageTitle)}</h1>
<ol>
<li>${text(l.desktopBrowserPageStep1)} <kbd>Ctrl+Shift+B</kbd></li>
<li>${text(l.desktopBrowserPageStep2)}<br>
<a class="button" href="$code" onclick="return false">${text(l.desktopBrowserButtonName)}</a>
<div class="hint">${text(l.desktopBrowserPageDragHint)}</div></li>
<li>${text(l.desktopBrowserPageStep3)}</li>
</ol>
<p class="hint">${text(l.desktopBrowserPageCopyInstead)}</p>
<code>${text(browserButtonCode)}</code>
</main></body>
</html>
''';
}

/// The settings line for the browser button: open the setup page, or copy
/// the code for a browser where dragging a link does not work.
class BrowserButtonLine extends StatelessWidget {
  const BrowserButtonLine({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return SettingLine(
      title: l.desktopBrowserButton,
      hint: l.desktopBrowserButtonHint,
      trailing: Wrap(
        alignment: WrapAlignment.end,
        spacing: MTSpace.sm,
        children: [
          MTLinkButton(
            label: l.desktopBrowserButtonOpen,
            onPressed: () => unawaited(_open(context)),
          ),
          MTLinkButton(
            label: l.desktopBrowserButtonCopy,
            onPressed: () => unawaited(_copy(context)),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(BuildContext context) async {
    final l = context.mtl;
    final page = browserButtonPage(
      l,
      MTThemeX.of(context).palette,
      rtl: Directionality.of(context) == TextDirection.rtl,
    );
    try {
      final file = File.fromUri(
        Directory.systemTemp.uri.resolve('metube-ember-browser-button.html'),
      );
      await file.writeAsString(page, flush: true);
      if (await launchUrl(Uri.file(file.path))) return;
    } on Object {
      // Said below, with the way that needs no page.
    }
    if (!context.mounted) return;
    showMTNotice(
      context,
      message: l.desktopBrowserButtonFailed,
      kind: MTNoticeKind.failed,
    );
  }

  static Future<void> _copy(BuildContext context) async {
    final message = context.mtl.desktopBrowserButtonCopied;
    await Clipboard.setData(const ClipboardData(text: browserButtonCode));
    if (context.mounted) showMTNotice(context, message: message);
  }
}
