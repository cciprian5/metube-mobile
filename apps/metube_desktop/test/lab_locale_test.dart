import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/lab_server.dart';

void main() {
  test('--lab-locale picks the language for development; without it the '
      'app follows Windows', () {
    expect(labLocaleFrom(['--lab-config=x', '--lab-locale=en']), 'en');
    expect(labLocaleFrom(['--lab-config=x']), isNull);
  });
}
