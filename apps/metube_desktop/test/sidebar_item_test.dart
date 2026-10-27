import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/sidebar_items.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  testWidgets('**the guard**: a full sidebar line squeezed mid-animation '
      'shows its icon alone rather than overflow', (tester) async {
    for (final width in [80.0, 100.0, 120.0, 140.0, 240.0]) {
      await tester.pumpWidget(
        MTDesktopApp(
          child: MaterialApp(
            theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: SidebarItem(
                    icon: MTIcons.folder,
                    label: 'Homelab recordings',
                    narrow: false,
                    selected: false,
                    depth: 2,
                    trailing: '128',
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'at $width');
    }
  });
}
