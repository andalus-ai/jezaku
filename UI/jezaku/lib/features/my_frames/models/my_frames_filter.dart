import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';

/// Filters offered on the owner's own-frames gallery.
enum MyFramesFilter {
  all('All'),
  ar('AR'),
  videos('Videos'),
  friends('Friends'),
  private('Private'),
  needsCalibration('Needs calibration');

  const MyFramesFilter(this.label);

  final String label;

  bool matches(AnchorMemory frame) {
    return switch (this) {
      MyFramesFilter.all => true,
      MyFramesFilter.ar => frame.hasArExperience,
      MyFramesFilter.videos =>
        frame.mediaAttachment?.type == AnchorMediaType.arRecording,
      MyFramesFilter.friends => frame.audience == FrameAudience.friends,
      MyFramesFilter.private => frame.isPrivate,
      MyFramesFilter.needsCalibration => frame.needsCalibrationReview,
    };
  }
}

/// Newest first; frames without a capture time go last, keeping their order.
List<AnchorMemory> sortFramesNewestFirst(Iterable<AnchorMemory> frames) {
  final indexed = frames.toList().asMap().entries.toList()
    ..sort((a, b) {
      final left = a.value.capturedAt;
      final right = b.value.capturedAt;
      if (left == null && right == null) {
        return a.key.compareTo(b.key);
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      final byTime = right.compareTo(left);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}
