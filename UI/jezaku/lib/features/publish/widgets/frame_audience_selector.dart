import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:material_ui/material_ui.dart';

/// Chooses who a frame is shared with: everyone, friends, or only the author.
/// Friends and everyone else still see it only on site, inside the physical
/// radius.
class FrameAudienceSelector extends StatelessWidget {
  const FrameAudienceSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final FrameAudience selected;
  final ValueChanged<FrameAudience> onChanged;

  static String description(FrameAudience audience) {
    return switch (audience) {
      FrameAudience.public => 'Anyone standing at the place can see it.',
      FrameAudience.friends => 'Only your friends standing at the place can '
          'see it.',
      FrameAudience.private => 'Only you can see it.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who can see this frame', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<FrameAudience>(
          segments: const [
            ButtonSegment(
              value: FrameAudience.public,
              icon: Icon(Icons.public),
              label: Text('Public'),
            ),
            ButtonSegment(
              value: FrameAudience.friends,
              icon: Icon(Icons.group_outlined),
              label: Text('Friends'),
            ),
            ButtonSegment(
              value: FrameAudience.private,
              icon: Icon(Icons.lock_outline),
              label: Text('Only me'),
            ),
          ],
          selected: {selected},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onChanged(values.first),
        ),
        const SizedBox(height: 6),
        Text(
          description(selected),
          key: const ValueKey('publish_audience_description'),
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
