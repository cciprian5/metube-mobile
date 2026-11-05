import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/shared/open_web_link.dart';

/// "Open the original link" takes the link the server gave, so only a web
/// page may reach the system's opener.
void main() {
  test(
    '**the guard**: a server link that is not a web page opens nothing',
    () async {
      final opened = <Uri>[];
      Future<bool> launch(Uri uri) async {
        opened.add(uri);
        return true;
      }

      for (final bad in ['file:///C:/x.exe', 'tel:123', 'otherapp://pay', '']) {
        await openWebLink(bad, launch: launch);
      }
      expect(opened, isEmpty);

      await openWebLink('https://youtu.be/dQw4w9WgXcQ', launch: launch);
      expect(opened.single.toString(), 'https://youtu.be/dQw4w9WgXcQ');
    },
  );
}
