import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arMemorySceneDiagnosticsKey = 'jejaku.ar_memory_scene_diagnostics';

final arMemorySceneDiagnosticsStoreProvider =
    Provider<ARMemorySceneDiagnosticsStore>((ref) {
  return InMemoryARMemorySceneDiagnosticsStore();
});

abstract class ARMemorySceneDiagnosticsStore {
  ARMemorySceneDiagnostics? loadLastDiagnostics();

  void saveLastDiagnostics(ARMemorySceneDiagnostics diagnostics);

  void clearLastDiagnostics();
}

class InMemoryARMemorySceneDiagnosticsStore
    implements ARMemorySceneDiagnosticsStore {
  ARMemorySceneDiagnostics? _diagnostics;

  @override
  ARMemorySceneDiagnostics? loadLastDiagnostics() {
    return _diagnostics;
  }

  @override
  void saveLastDiagnostics(ARMemorySceneDiagnostics diagnostics) {
    _diagnostics = diagnostics;
  }

  @override
  void clearLastDiagnostics() {
    _diagnostics = null;
  }
}

class SharedPreferencesARMemorySceneDiagnosticsStore
    implements ARMemorySceneDiagnosticsStore {
  const SharedPreferencesARMemorySceneDiagnosticsStore({
    required SharedPreferences preferences,
    String diagnosticsKey = _arMemorySceneDiagnosticsKey,
  })  : _preferences = preferences,
        _diagnosticsKey = diagnosticsKey;

  final SharedPreferences _preferences;
  final String _diagnosticsKey;

  @override
  ARMemorySceneDiagnostics? loadLastDiagnostics() {
    final encodedDiagnostics = _preferences.getString(_diagnosticsKey);
    if (encodedDiagnostics == null || encodedDiagnostics.trim().isEmpty) {
      return null;
    }

    try {
      final decodedDiagnostics = jsonDecode(encodedDiagnostics);
      if (decodedDiagnostics is! Map) {
        clearLastDiagnostics();
        return null;
      }
      return ARMemorySceneDiagnostics.fromMap(
        Map<dynamic, dynamic>.from(decodedDiagnostics),
      );
    } on Object {
      clearLastDiagnostics();
      return null;
    }
  }

  @override
  void saveLastDiagnostics(ARMemorySceneDiagnostics diagnostics) {
    unawaited(
      _preferences.setString(
        _diagnosticsKey,
        jsonEncode(diagnostics.toMap()),
      ),
    );
  }

  @override
  void clearLastDiagnostics() {
    unawaited(_preferences.remove(_diagnosticsKey));
  }
}

persistentARMemorySceneDiagnosticsStoreOverride({
  required SharedPreferences preferences,
}) {
  return arMemorySceneDiagnosticsStoreProvider.overrideWith((ref) {
    return SharedPreferencesARMemorySceneDiagnosticsStore(
      preferences: preferences,
    );
  });
}
