import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mt_core/mt_core.dart';

/// A server for development, read from a local file: **debug builds only**,
/// until the first-run setup asks the user for one.
///
/// `--lab-config=<file>` names a JSON file holding `targets` (address by
/// name), `user` and `pass`; `--lab-target=<name>` picks the address
/// (`local` by default). The file stays outside the repository, and
/// nothing here prints what it holds.
ServerConfig? labServerFrom(List<String> args) {
  if (!kDebugMode) return null;
  String? arg(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  final path = arg('lab-config');
  if (path == null) return null;
  try {
    final json = jsonDecode(File(path).readAsStringSync());
    if (json is! Map) return null;
    final targets = json['targets'];
    final url = targets is Map ? targets[arg('lab-target') ?? 'local'] : null;
    if (url is! String || url.isEmpty) return null;
    return ServerConfig(
      baseUrl: url,
      username: json['user'] as String?,
      password: json['pass'] as String?,
    );
  } on Object {
    // A missing or damaged file is no server, never a failed start.
    return null;
  }
}

/// The interface language for development, `--lab-locale=en`: **debug
/// builds only**, so both languages can be checked in the real window
/// without changing Windows' own. Null follows Windows, as every user's
/// copy does.
String? labLocaleFrom(List<String> args) {
  if (!kDebugMode) return null;
  for (final a in args) {
    if (a.startsWith('--lab-locale=')) return a.substring(13);
  }
  return null;
}

/// The page the window opens on, `--lab-route=/settings/appearance`, and
/// day or night, `--lab-theme=dark`: **debug builds only**, so every page
/// can be photographed in the real window without a click and without
/// touching what the user chose.
String? labRouteFrom(List<String> args) => _labValue(args, '--lab-route=');

String? labThemeFrom(List<String> args) => _labValue(args, '--lab-theme=');

String? _labValue(List<String> args, String prefix) {
  if (!kDebugMode) return null;
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

/// Every address in the lab file, the chosen one first, to seed the
/// address list the first time; empty outside a debug build.
List<String> labAddressesFrom(List<String> args) {
  final first = labServerFrom(args)?.baseUrl;
  if (first == null) return const [];
  String? path;
  for (final a in args) {
    if (a.startsWith('--lab-config=')) path = a.substring(13);
  }
  try {
    final json = jsonDecode(File(path!).readAsStringSync());
    final targets = json is Map ? json['targets'] : null;
    return [
      first,
      if (targets is Map)
        for (final url in targets.values)
          if (url is String && url.isNotEmpty && url != first) url,
    ];
  } on Object {
    return [first];
  }
}
