import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/incoming_links.dart';
import 'add_dialog.dart';

/// Links from outside the window (a `metube://` link, a copied link the
/// user chose to add) each open the add dialog, **one at a time**: the next
/// waits for the one before to close, rather than a pile of dialogs one
/// over another, and none is lost.
class OutsideLinks extends ConsumerStatefulWidget {
  const OutsideLinks({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OutsideLinks> createState() => _OutsideLinksState();
}

class _OutsideLinksState extends ConsumerState<OutsideLinks> {
  late final IncomingLinks _incoming;
  final _waiting = <String>[];
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _incoming = ref.read(incomingLinksProvider);
    // Once there is a window to show the dialog in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _incoming.listen(_arrived);
    });
  }

  @override
  void dispose() {
    _incoming.cancel();
    super.dispose();
  }

  void _arrived(String text) {
    _waiting.add(text);
    if (!_showing) unawaited(_showAll());
  }

  Future<void> _showAll() async {
    _showing = true;
    while (_waiting.isNotEmpty && mounted) {
      await openAddDialog(context, text: _waiting.removeAt(0));
    }
    _showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
