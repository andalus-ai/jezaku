import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/services/ar_debug_log.dart';
import 'package:path_provider/path_provider.dart';

/// Turn the log on for a run with `--dart-define=AR_DEBUG_LOG=true`. It can
/// also be switched on and off at runtime from the AR diagnostics sheet.
const bool arDebugLogEnabledByDefault = bool.fromEnvironment('AR_DEBUG_LOG');

final arDebugLogProvider = Provider<ARDebugLog>((ref) {
  final log = ARDebugLog(
    sink: FileARDebugLogSink(directory: _logDirectory),
    enabled: arDebugLogEnabledByDefault,
  );
  ref.onDispose(log.dispose);
  return log;
});

/// Prefers the app's external files directory
/// (`/sdcard/Android/data/<package>/files`) because `adb pull` can read it
/// even from profile builds; falls back to private app storage.
Future<Directory> _logDirectory() async {
  try {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      return external;
    }
  } on Object {
    // Not supported on this platform (for example iOS).
  }
  return getApplicationSupportDirectory();
}
