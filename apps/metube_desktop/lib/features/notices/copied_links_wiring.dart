import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/copied_links.dart';
import '../../data/desktop_habits.dart';
import '../../data/incoming_links.dart';
import '../../data/library_data.dart';
import '../../data/notices.dart';

/// **Links copied in other programs**, when the user asked to be offered
/// them: a Windows notice offering to add the link, whose button brings the
/// window back with the add dialog open on it. A copy made with the window
/// in front is let be: Ctrl+V adds it there.
class CopiedLinksWiring extends ConsumerStatefulWidget {
  const CopiedLinksWiring({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CopiedLinksWiring> createState() => _CopiedLinksWiringState();
}

class _CopiedLinksWiringState extends ConsumerState<CopiedLinksWiring> {
  /// Offered in this run, so one link is offered once however often it is
  /// copied.
  final _offered = <String>[];
  ClipboardPort? _watching;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      offerCopiedLinksProvider,
      (_, on) => _watch(on),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _watching?.stop();
    super.dispose();
  }

  void _watch(bool on) {
    _watching?.stop();
    _watching = null;
    if (!on) return;
    final port = ref.read(clipboardPortProvider)
      ..start((text) => unawaited(_onCopy(text)));
    _watching = port;
  }

  Future<void> _onCopy(String text) async {
    if (await ref.read(windowInFrontProvider)()) return;
    final items = ref.read(libraryItemsProvider).valueOrNull ?? const [];
    final link = linkToOffer(
      text,
      offered: _offered,
      library: [for (final item in items) item.canonicalUrl],
    );
    if (link == null || !mounted) return;
    _offered.add(link);
    final l = context.mtl;
    void add() {
      unawaited(ref.read(bringWindowBackProvider)());
      ref.read(incomingLinksProvider).add(link);
    }

    await ref
        .read(noticePortProvider)
        .show(
          EmberNotice(
            title: l.desktopCopiedLinkTitle,
            body: link,
            actions: [(label: l.desktopCopiedLinkAdd, onPressed: add)],
            onClick: add,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
