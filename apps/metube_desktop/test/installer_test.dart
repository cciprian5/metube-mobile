import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/identity.dart';

/// The installer script and the app must agree on the names Windows knows
/// the app by; a mismatch shows up only on a user's computer, as an
/// "unknown app" in the media flyout, notifications that never appear, or
/// data the uninstaller cannot find.
void main() {
  final iss = File('windows/installer/ember.iss').readAsStringSync();
  final runner = File('windows/runner/main.cpp').readAsStringSync();
  String? define(String name) =>
      RegExp('#define $name "([^"]*)"').firstMatch(iss)?.group(1);
  String? directive(String name) =>
      RegExp('^$name=(.*)\$', multiLine: true).firstMatch(iss)?.group(1);

  test('**the guard**: the Start menu shortcut carries the identity the '
      'app gives itself', () {
    final name = define('AppName');
    expect(name, EmberIdentity.displayName);
    // local_notifier looks for this shortcut, by this name, in the user's
    // Programs folder, and adopts it when its identity matches.
    expect(
      iss,
      contains(
        r'Name: "{userprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; '
        'AppUserModelID: "{#AppName}"',
      ),
    );
    expect(
      runner,
      contains('SetCurrentProcessExplicitAppUserModelID(L"$name")'),
    );
  });

  test('the identity is set before the first window appears', () {
    expect(
      runner.indexOf('SetCurrentProcessExplicitAppUserModelID'),
      lessThan(runner.indexOf('window.Create(')),
    );
  });

  test('the uninstaller sees the running app by the mutex the runner '
      'creates', () {
    final mutex = define('RunningMutex');
    expect(mutex, isNotEmpty);
    expect(runner, contains('CreateMutexW(nullptr, FALSE, L"$mutex")'));
  });

  test('Windows knows the installed app by an id fixed for good', () {
    expect(define('AppIdGuid'), 'E116A4DE-C492-40C0-9094-8A734813AAFB');
    expect(directive('AppId'), '{{{#AppIdGuid}}');
  });

  test('installs for the current user, with no administrator', () {
    expect(directive('PrivilegesRequired'), 'lowest');
    expect(directive('DefaultDirName'), r'{autopf}\{#AppName}');
  });

  test('the file names neither phone app, so neither phone takes it for '
      'its update', () {
    final name = directive('OutputBaseFilename')!;
    expect(name, 'MeTube-Ember-{#AppVersion}-windows-x64-setup');
    expect(name.toLowerCase(), isNot(contains('lite')));
    expect(name.toLowerCase(), isNot(contains('super')));
  });

  test('metube:// links open the app with the link as its argument', () {
    expect(define('Scheme'), 'metube');
    expect(
      iss,
      contains(
        r'Subkey: "Software\Classes\{#Scheme}\shell\open\command"; '
        r'ValueType: string; ValueName: ""; '
        r'ValueData: """{app}\{#AppExe}"" ""%1"""',
      ),
    );
    expect(iss, contains(r'ValueName: "URL Protocol"'));
  });

  test('the uninstaller removes the data folders the app writes, and only '
      'when asked', () {
    // The folders are named after the app (lib/identity.dart).
    expect(
      iss,
      contains(r"DelTree(ExpandConstant('{userappdata}\{#AppName}')"),
    );
    expect(
      iss,
      contains(r"DelTree(ExpandConstant('{localappdata}\{#AppName}')"),
    );
    expect(iss, contains('MB_YESNO or MB_DEFBUTTON2'));
    expect(iss, contains('not UninstallSilent()'));
    // "Start with Windows" is stored under the app's name.
    expect(
      iss,
      contains(
        r"RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion"
        r"\Run', '{#AppName}')",
      ),
    );
  });

  test('every message the installer adds is in English and Arabic', () {
    final keys = RegExp(
      r'^(english|arabic)\.(\w+)=',
      multiLine: true,
    ).allMatches(iss).map((m) => '${m[1]}.${m[2]}').toSet();
    final english = keys.where((k) => k.startsWith('english.'));
    expect(english, isNotEmpty);
    for (final key in english) {
      expect(keys, contains(key.replaceFirst('english.', 'arabic.')));
    }
  });

  test('the script is UTF-8 with a BOM, or Inno Setup garbles the Arabic', () {
    final bytes = File('windows/installer/ember.iss').readAsBytesSync();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('the wizard images exist for every display scale', () {
    final dir = Directory('windows/installer');
    final names = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();
    for (final percent in [100, 125, 150, 200]) {
      expect(names, contains('wizard_large_$percent.bmp'));
    }
    for (final side in [58, 77, 97, 124]) {
      expect(names, contains('wizard_small_$side.png'));
    }
  });
}
