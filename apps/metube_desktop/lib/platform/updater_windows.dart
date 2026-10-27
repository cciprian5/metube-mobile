import 'dart:io';

/// **Updating in place**: starts the downloaded installer without its
/// wizard, then closes the app. The installer (windows/installer/ember.iss)
/// waits for the app to go, replaces it, keeps the data, and opens it
/// again.
///
/// [quit] is the window's own close, so the player and the window's place
/// are saved first, as when the user closes it.
Future<bool> runInstaller(String path, Future<void> Function() quit) async {
  try {
    await Process.start(path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      // Windows' Restart Manager closes whatever still holds a file,
      // such as the app hidden in the tray.
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
  } on Object {
    return false;
  }
  await quit();
  return true;
}
