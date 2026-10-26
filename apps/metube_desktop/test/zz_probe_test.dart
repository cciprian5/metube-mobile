import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

void main() {
  testWidgets('probe', (tester) async {
    final handle = tester.ensureSemantics();
    ShellHarness.useWindow(tester, const Size(1440, 900));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': ''}
          : null,
    );
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final labels = <String>[];
    void walk(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.label.isNotEmpty || d.tooltip.isNotEmpty) labels.add('${d.label}|${d.tooltip}');
      n.visitChildren((c) { walk(c); return true; });
    }
    walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    // ignore: avoid_print
    print(labels.join('\n'));
    handle.dispose();
  });
}
