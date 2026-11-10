import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether bundled sample memories and walls are mixed into the local data.
///
/// Samples are a development and demo aid. They default to on for debug and
/// test builds and off for profile/release builds, so a shipped app starts
/// with an honest empty state rather than fabricated nearby memories.
///
/// Override at build time:
/// `--dart-define=ENABLE_SAMPLE_DATA=true|false`
/// (`USE_DUMMY_DATA=true`, used by `scripts/run_demo_android.sh`, also enables
/// samples).
const bool sampleDataEnabledByEnvironment =
    bool.fromEnvironment('ENABLE_SAMPLE_DATA', defaultValue: kDebugMode) ||
        bool.fromEnvironment('USE_DUMMY_DATA');

final sampleDataEnabledProvider = Provider<bool>((ref) {
  return sampleDataEnabledByEnvironment;
});
