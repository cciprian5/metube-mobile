import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:metube_desktop/shell/shell_metrics.dart';

void main() {
  const open = ShellLayout();
  const folded = ShellLayout(sidebarNarrow: true);

  test('1280 and wider: three columns, the sidebar as the user left it', () {
    for (final width in <double>[1280, 1440, 2560]) {
      final wide = arrangeShell(width, open);
      expect(wide.sidebarWidth, EmberShellSize.sidebarWide, reason: '$width');
      expect(wide.panelBeside, isTrue);
      expect(wide.canWidenSidebar, isTrue);
      expect(arrangeShell(width, folded).sidebarNarrow, isTrue);
    }
  });

  test('1100 to 1279: the sidebar narrows by itself, the panel stays', () {
    for (final width in <double>[1100, 1200, 1279]) {
      final a = arrangeShell(width, open);
      expect(a.sidebarNarrow, isTrue, reason: '$width');
      expect(a.panelBeside, isTrue);
      expect(a.canWidenSidebar, isFalse);
    }
  });

  test('960 to 1099: the panel becomes a layer over the content', () {
    for (final width in <double>[960, 1000, 1099]) {
      final a = arrangeShell(width, open);
      expect(a.sidebarNarrow, isTrue, reason: '$width');
      expect(a.panelBeside, isFalse);
    }
  });

  test("the user's wide sidebar comes back when the window grows", () {
    expect(arrangeShell(1200, open).sidebarNarrow, isTrue);
    expect(arrangeShell(1400, open).sidebarNarrow, isFalse);
  });
}
