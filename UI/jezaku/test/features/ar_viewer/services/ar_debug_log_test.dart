import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_debug_log.dart';

void main() {
  late List<String> printed;
  late InMemoryARDebugLogSink sink;
  var clock = DateTime.utc(2026, 11, 19, 9);

  ARDebugLog make({bool enabled = true, int memoryLines = 400}) {
    return ARDebugLog(
      sink: sink,
      enabled: enabled,
      now: () => clock,
      printer: printed.add,
      memoryLines: memoryLines,
      flushDelay: const Duration(days: 1),
    );
  }

  setUp(() {
    printed = [];
    sink = InMemoryARDebugLogSink();
    clock = DateTime.utc(2026, 11, 19, 9);
  });

  test('is silent and writes nothing while disabled', () async {
    final log = make(enabled: false);

    log.log('scene', 'sync');
    log.logChange('k', 'scene', 'x');
    await log.flush();

    expect(printed, isEmpty);
    expect(log.recentLines, isEmpty);
    expect(await sink.readAll(), isEmpty);
  });

  test('formats lines, mirrors them to the terminal and the sink', () async {
    final log = make();

    log.log('scene', 'added=[a]');
    await log.flush();

    const line = '2026-11-19T09:00:00.000Z [scene] added=[a]';
    expect(printed, ['[ARDBG] $line']);
    expect(log.recentLines, [line]);
    expect(await sink.readAll(), '$line\n');
    log.dispose();
  });

  test('logChange skips repeats and logs again when the value changes', () {
    final log = make();

    log.logChange('sel', 'select', 'native=[a]');
    log.logChange('sel', 'select', 'native=[a]');
    log.logChange('sel', 'select', 'native=[a,b]');
    log.logChange('other', 'select', 'native=[a]');

    expect(log.recentLines.length, 3);
    log.dispose();
  });

  test('keeps only the most recent lines in memory', () {
    final log = make(memoryLines: 3);

    for (var i = 0; i < 6; i++) {
      log.log('t', 'line $i');
    }

    expect(log.recentLines.length, 3);
    expect(log.recentLines.first, endsWith('line 3'));
    expect(log.recentLines.last, endsWith('line 5'));
    log.dispose();
  });

  test('export flushes pending lines first; clear empties everything',
      () async {
    final log = make();

    log.log('t', 'one');
    final exported = await log.export();
    expect(exported, contains('one'));

    await log.clear();
    expect(await sink.readAll(), isEmpty);
    expect(log.recentLines, isEmpty);
  });

  test('toggling records the change and stops logging when off', () async {
    final log = make(enabled: false);

    log.enabled = true;
    log.log('t', 'while on');
    log.enabled = false;
    log.log('t', 'while off');
    await log.flush();

    final text = await sink.readAll();
    expect(text, contains('enabled'));
    expect(text, contains('while on'));
    expect(text, contains('disabled'));
    expect(text, isNot(contains('while off')));
  });

  test('a failing sink never throws into the caller', () async {
    final log = ARDebugLog(
      sink: _ThrowingSink(),
      enabled: true,
      printer: printed.add,
      flushDelay: const Duration(days: 1),
    );

    log.log('t', 'x');
    await log.flush();

    expect(printed.any((line) => line.contains('log write failed')), isTrue);
    log.dispose();
  });

  group('FileARDebugLogSink', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ar_debug_log_test');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('appends lines and reads them back', () async {
      final fileSink = FileARDebugLogSink(directory: () async => dir);

      await fileSink.append('a\n');
      await fileSink.append('b\n');

      expect(await fileSink.readAll(), 'a\nb\n');
      expect(fileSink.location, '${dir.path}/ar_debug.log');
    });

    test('rotates past maxBytes and keeps the previous file', () async {
      final fileSink = FileARDebugLogSink(
        directory: () async => dir,
        maxBytes: 10,
      );

      await fileSink.append('0123456789ABC\n');
      await fileSink.append('second\n');

      expect(File('${dir.path}/ar_debug.log.1').existsSync(), isTrue);
      expect(await fileSink.readAll(), '0123456789ABC\nsecond\n');

      await fileSink.append('third-line-long\n');
      await fileSink.append('fourth\n');
      final all = await fileSink.readAll();
      expect(all, isNot(contains('0123456789ABC')));
      expect(all, contains('fourth'));
    });

    test('clear removes both files', () async {
      final fileSink = FileARDebugLogSink(
        directory: () async => dir,
        maxBytes: 5,
      );
      await fileSink.append('aaaaaaaa\n');
      await fileSink.append('bbbb\n');

      await fileSink.clear();

      expect(await fileSink.readAll(), isEmpty);
    });
  });
}

class _ThrowingSink implements ARDebugLogSink {
  @override
  Future<void> append(String text) => throw const FileSystemException('full');

  @override
  Future<void> clear() async {}

  @override
  String? get location => null;

  @override
  Future<String> readAll() async => '';
}
