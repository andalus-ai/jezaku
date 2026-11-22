import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/settings/services/settings_diagnostics_formatters.dart';

void main() {
  group('formatCacheBytes', () {
    test('uses bytes below one KiB', () {
      expect(formatCacheBytes(0), '0 B');
      expect(formatCacheBytes(1023), '1023 B');
    });

    test('uses one decimal for KB and MB', () {
      expect(formatCacheBytes(1024), '1.0 KB');
      expect(formatCacheBytes(1536), '1.5 KB');
      expect(formatCacheBytes(1024 * 1024), '1.0 MB');
      expect(formatCacheBytes(5 * 1024 * 1024 + 512 * 1024), '5.5 MB');
    });
  });

  test('twoDigits pads single digits only', () {
    expect(twoDigits(5), '05');
    expect(twoDigits(12), '12');
  });

  test('recentBundleLabel names the newest bundles', () {
    expect(recentBundleLabel(0), 'Latest');
    expect(recentBundleLabel(1), 'Previous');
    expect(recentBundleLabel(2), 'Earlier');
    expect(recentBundleLabel(9), 'Earlier');
  });

  test('formatBundleExportedAt prints local time to the minute', () {
    expect(
      formatBundleExportedAt(DateTime(2026, 11, 21, 8, 5, 59)),
      '2026-11-21 08:05',
    );
  });

  test('bundleSummaryLabel explains an empty cache', () {
    expect(bundleSummaryLabel(null), 'No AR diagnostics bundles cached');
  });
}
