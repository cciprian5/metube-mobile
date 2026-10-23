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
