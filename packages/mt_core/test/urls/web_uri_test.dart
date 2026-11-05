import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// The links the apps open in a browser come from the server's history:
/// only a web page may reach the system's opener.
void main() {
  test('**the guard**: a link that is not a web page is never opened', () {
    for (final bad in [
      'file:///C:/Windows/System32/calc.exe',
      r'\attacker\share\evil.lnk',
      'ms-settings:privacy',
      'tel:123',
      'intent://scan/#Intent;scheme=zxing;end',
      'otherapp://pay?ref=dQw4w9WgXcQ',
      'javascript:alert(1)',
      'https://',
      '',
      null,
    ]) {
      expect(UrlKit.webUri(bad), isNull, reason: '$bad');
    }
  });

  test('a web page opens as it is', () {
    expect(
      UrlKit.webUri('https://www.youtube.com/watch?v=dQw4w9WgXcQ').toString(),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(UrlKit.webUri(' http://nas:8081/x ')?.host, 'nas');
    expect(UrlKit.webUri('HTTPS://Example.com')?.host, 'example.com');
  });
}
