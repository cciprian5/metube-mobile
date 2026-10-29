import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/folders_data.dart';
import '../../data/library_data.dart';
import '../../shell/error_text.dart';
import 'simple_panes.dart';
import '../../shell/folded_text.dart';

/// Whether the server holds cookies; null while unknown, and for a MeTube
/// too old to say.
final cookieStatusProvider = FutureProvider<bool?>(
  (ref) async => ref.watch(apiClientProvider)?.hasCookies(),
);

/// **Cookies for the platforms that want a login**, sent from files the
/// browser exported. **Nothing is kept on this computer**: the files are
/// read, sent and dropped, because they are live sign-ins to someone's
/// accounts.
class CookiesPane extends ConsumerStatefulWidget {
  const CookiesPane({super.key});

  @override
  ConsumerState<CookiesPane> createState() => _CookiesPaneState();
}

class _CookiesPaneState extends ConsumerState<CookiesPane> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(cookieStatusProvider);
      if (mounted) showMTNotice(context, message: done);
    } on Object catch (e) {
      // The server's own words, which for cookies are the useful ones
      // ("configured manually via YTDL_OPTIONS" sends its operator to the
      // container).
      if (mounted) {
        showMTNotice(
          context,
          message: errorText(context.mtl, e),
          kind: MTNoticeKind.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    final l = context.mtl;
    final files = await ref
        .read(desktopFoldersProvider)
        .openFiles(extensions: const ['txt']);
    if (files.isEmpty || !mounted) return;
    // The server keeps one file and each upload replaces it whole, so the
    // files chosen together are merged into one; one file goes as chosen.
    final (name, bytes) = files.length == 1
        ? files.single
        : ('cookies.txt', CookieFiles.merge([for (final f in files) f.$2]));
    if (bytes == null) {
      showMTNotice(
        context,
        message: l.cookiesNotNetscape,
        kind: MTNoticeKind.failed,
      );
      return;
    }
    final sites = CookieFiles.sites(bytes);
    await _run(
      () => api.uploadCookies(bytes, filename: name),
      sites.isEmpty
          ? l.cookiesUploaded
          : l.cookiesSentFor(mtLtrRun(sites.join(' · '))),
    );
  }

  Future<void> _delete() async {
    final api = ref.read(apiClientProvider);
    if (api == null) return;
    final l = context.mtl;
    final sure = await showMTConfirm(
      context,
      title: l.cookiesDelete,
      message: l.cookiesDeleteBody,
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (sure) await _run(api.deleteCookies, l.cookiesDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final api = ref.watch(apiClientProvider);
    final has = ref.watch(cookieStatusProvider).valueOrNull;
    final note = text.labelSmall?.copyWith(color: p.ink3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FoldedText(
          l.cookiesWhat,
          style: text.bodyMedium?.copyWith(color: p.ink2),
        ),
        const SizedBox(height: MTSpace.sm),
        SettingLine(
          title: api == null
              ? l.serverStatusUnconfigured
              : switch (has) {
                  true => l.cookiesPresent,
                  false => l.cookiesAbsent,
                  null => l.cookiesUnknown,
                },
          hint: l.cookiesSubtitle,
          trailing: MTLinkButton(
            label: has == true ? l.cookiesReplace : l.cookiesUpload,
            icon: MTIcons.cookie,
            onPressed: _busy || api == null ? null : () => unawaited(_send()),
          ),
        ),
        // Offered only when there is something to delete: a delete on a
        // server with none is refused, and teaches that the app guesses.
        if (has == true)
          SettingLine(
            title: l.cookiesDelete,
            hint: l.cookiesDeleteBody,
            trailing: MTLinkButton(
              label: l.delete,
              danger: true,
              icon: MTIcons.trash,
              onPressed: _busy ? null : () => unawaited(_delete()),
            ),
          ),
        const SizedBox(height: MTSpace.sm),
        FoldedText(l.desktopCookiesReplaceNote, style: note),
        const SizedBox(height: MTSpace.sm),
        FoldedText(l.cookiesHelp, style: note),
        const SizedBox(height: MTSpace.sm),
        FoldedText(l.desktopCookiesPrivacy, style: note),
      ],
    );
  }
}
