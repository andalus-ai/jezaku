import 'package:ar_engine/ar_engine.dart';

Map<String, Object?>? normalizedARCaptureDiagnosticsPayload(Object? value) {
  return ARCaptureDiagnostics.tryNormalizeSyncableMap(value);
}
