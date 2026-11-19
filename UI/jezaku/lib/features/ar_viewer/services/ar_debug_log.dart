import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// Where debug log lines end up.
abstract interface class ARDebugLogSink {
  /// Appends [text] (already newline-terminated lines).
  Future<void> append(String text);

  /// Everything currently stored, oldest first.
  Future<String> readAll();

  Future<void> clear();

  /// Human-readable location, such as a file path, or `null`.
  String? get location;
}

/// Keeps lines in memory. Used in tests and as a safe fallback.
class InMemoryARDebugLogSink implements ARDebugLogSink {
  final StringBuffer _buffer = StringBuffer();

  @override
  Future<void> append(String text) async => _buffer.write(text);

  @override
  Future<String> readAll() async => _buffer.toString();

  @override
  Future<void> clear() async => _buffer.clear();

  @override
  String? get location => null;
}

/// Appends to a file and rotates it once it grows past [maxBytes], keeping one
/// previous file, so the log never grows without bound.
class FileARDebugLogSink implements ARDebugLogSink {
  FileARDebugLogSink({
    required Future<Directory> Function() directory,
    this.fileName = 'ar_debug.log',
    this.maxBytes = 512 * 1024,
  }) : _directory = directory;

  final Future<Directory> Function() _directory;
  final String fileName;
  final int maxBytes;

  Directory? _resolved;

  @override
  String? get location {
    final dir = _resolved;
    return dir == null ? null : '${dir.path}/$fileName';
  }

  Future<File> _file() async {
    final dir = _resolved ??= await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  @override
  Future<void> append(String text) async {
    final file = await _file();
    if (await file.exists() && await file.length() > maxBytes) {
      final previous = File('${file.path}.1');
      if (await previous.exists()) {
        await previous.delete();
      }
      await file.rename(previous.path);
    }
    await file.writeAsString(text, mode: FileMode.append, flush: true);
  }

  @override
  Future<String> readAll() async {
    final file = await _file();
    final previous = File('${file.path}.1');
    final parts = <String>[
      if (await previous.exists()) await previous.readAsString(),
      if (await file.exists()) await file.readAsString(),
    ];
    return parts.join();
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    final previous = File('${file.path}.1');
    if (await file.exists()) {
      await file.delete();
    }
    if (await previous.exists()) {
      await previous.delete();
    }
  }
}

/// Opt-in diagnostic log for the AR viewer.
///
/// Every line is mirrored to the terminal (`debugPrint`, so it shows in
/// `flutter run` and logcat) and appended to a file on the device, so the
/// record survives a dropped wireless-debug connection. Writes are batched off
/// the UI path and the file is size-capped.
///
/// It is disabled by default and costs one boolean check per call when off.
/// Never log photos, captions, user ids or exact coordinates here: log memory
/// ids and counts only.
class ARDebugLog {
  ARDebugLog({
    required ARDebugLogSink sink,
    bool enabled = false,
    DateTime Function()? now,
    void Function(String line)? printer,
    this.memoryLines = 400,
    this.flushDelay = const Duration(seconds: 1),
  })  : _sink = sink,
        _enabled = enabled,
        _now = now ?? (() => DateTime.now().toUtc()),
        _printer = printer ?? _defaultPrinter;

  static void _defaultPrinter(String line) => debugPrint(line);

  final ARDebugLogSink _sink;
  final DateTime Function() _now;
  final void Function(String line) _printer;
  final int memoryLines;
  final Duration flushDelay;

  bool _enabled;
  final List<String> _recent = <String>[];
  final StringBuffer _pending = StringBuffer();
  final Map<String, String> _lastByKey = <String, String>{};
  Timer? _flushTimer;
  Future<void> _writing = Future<void>.value();

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    if (value) {
      _enabled = true;
      log('log', 'enabled');
    } else {
      log('log', 'disabled');
      _enabled = false;
      unawaited(flush());
    }
  }

  String? get location => _sink.location;

  /// The latest lines held in memory, oldest first.
  List<String> get recentLines => List<String>.unmodifiable(_recent);

  /// Records one line: `<utc time> [<tag>] <message>`.
  void log(String tag, String message) {
    if (!_enabled) {
      return;
    }
    final line = '${_now().toIso8601String()} [$tag] $message';
    _recent.add(line);
    if (_recent.length > memoryLines) {
      _recent.removeRange(0, _recent.length - memoryLines);
    }
    _printer('[ARDBG] $line');
    _pending.writeln(line);
    _flushTimer ??= Timer(flushDelay, () => unawaited(flush()));
  }

  /// Like [log] but skipped while [message] is identical to the last one
  /// logged under [key]; use it for state that is polled every frame.
  void logChange(String key, String tag, String message) {
    if (!_enabled || _lastByKey[key] == message) {
      return;
    }
    _lastByKey[key] = message;
    log(tag, message);
  }

  /// Writes pending lines now. Writes are serialised and never throw.
  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) {
      return _writing;
    }
    final text = _pending.toString();
    _pending.clear();
    _writing = _writing.then((_) async {
      try {
        await _sink.append(text);
      } catch (error) {
        _printer('[ARDBG] log write failed: $error');
      }
    });
    return _writing;
  }

  /// Everything stored so far, including lines not yet flushed.
  Future<String> export() async {
    await flush();
    try {
      return await _sink.readAll();
    } catch (error) {
      return 'log read failed: $error\n${_recent.join('\n')}';
    }
  }

  Future<void> clear() async {
    _pending.clear();
    _recent.clear();
    _lastByKey.clear();
    await _writing;
    try {
      await _sink.clear();
    } catch (_) {
      // Nothing useful to do if the file cannot be removed.
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
