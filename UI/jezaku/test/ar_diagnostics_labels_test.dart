import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_diagnostics_labels.dart';

void main() {
  group('ARDiagnosticsLabels', () {
    test('time is rendered in UTC with zero padding', () {
      expect(
        ARDiagnosticsLabels.time(DateTime.utc(2026, 6, 2, 7, 5)),
        '2026-06-02 07:05 UTC',
      );
      // A local-offset timestamp is converted, not printed as-is.
      expect(
        ARDiagnosticsLabels.time(DateTime.parse('2026-06-02T07:05:00+07:00')),
        '2026-06-02 00:05 UTC',
      );
    });

    test('history rows are named by recency', () {
      expect(ARDiagnosticsLabels.historyRow(0), 'Latest');
      expect(ARDiagnosticsLabels.historyRow(1), 'Previous');
      expect(ARDiagnosticsLabels.historyRow(2), 'Earlier');
      expect(ARDiagnosticsLabels.historyRow(9), 'Earlier');
    });

    test('vectors and quaternions use three decimals', () {
      expect(
        ARDiagnosticsLabels.vector(const ARVector3(1, 0.5, -0.12345)),
        '(1.000,0.500,-0.123)',
      );
      expect(
        ARDiagnosticsLabels.quaternion(const ARQuaternion(0, 0, 0, 1)),
        '(0.000,0.000,0.000,1.000)',
      );
    });
  });
}
