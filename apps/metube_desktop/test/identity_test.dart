import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/identity.dart';
import 'package:metube_desktop/platform/single_instance.dart';

/// The names Windows shows, and the data folder derived from them, must
/// not drift apart or change after the first release.
void main() {
  final rc = File('windows/runner/Runner.rc').readAsStringSync();
  String? field(String name) =>
      RegExp('VALUE "$name", "([^"]*)"').firstMatch(rc)?.group(1);

  test('the name is fixed for good', () {
    expect(EmberIdentity.displayName, 'MeTube Ember');
  });

  test('**the guard**: the data folder is %APPDATA%\\MeTube Ember', () {
    // path_provider names the folder ProductName, under CompanyName when
    // that is set: a company here would move every user's data.
    expect(field('ProductName'), EmberIdentity.displayName);
    expect(field('CompanyName'), isEmpty);
  });

  test('Windows shows the same name for the program and its window', () {
    expect(field('FileDescription'), EmberIdentity.displayName);
    final runner = File('windows/runner/main.cpp').readAsStringSync();
    expect(runner, contains('window.Create(L"${EmberIdentity.displayName}"'));
  });

  test('one copy per Windows user, through a pipe name that stays whole', () {
    expect(instancePipeName('Yasir'), 'metube_ember.Yasir');
    expect(instancePipeName('Yasir'), isNot(instancePipeName('Sara')));
    // A backslash would end the pipe name; Arabic letters are replaced.
    expect(instancePipeName(r'DOMAIN\ياسر'), 'metube_ember.DOMAIN_____');
    expect(instancePipeName(null), 'metube_ember');
    expect(instancePipeName(''), 'metube_ember');
  });
}
