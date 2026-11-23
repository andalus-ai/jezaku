import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/widgets/memory_empty_state.dart';
import 'package:jejaku/features/my_frames/models/my_frames_filter.dart';
import 'package:jejaku/features/my_frames/states/my_frames_providers.dart';
import 'package:jejaku/features/my_frames/widgets/my_frame_tile.dart';
import 'package:material_ui/material_ui.dart';

/// Instagram-style grid of the viewer's own frames, viewable anywhere.
///
/// Other people's frames never appear here: they are seen only on site, inside
/// the physical radius (see the frame visibility policy).
class MyFramesScreen extends ConsumerStatefulWidget {
  const MyFramesScreen({super.key});

  @override
  ConsumerState<MyFramesScreen> createState() => _MyFramesScreenState();
}

class _MyFramesScreenState extends ConsumerState<MyFramesScreen> {
  MyFramesFilter _filter = MyFramesFilter.all;

  @override
  Widget build(BuildContext context) {
    final frames = ref.watch(ownFramesProvider);
    final shown = frames.where(_filter.matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My frames')),
      body: frames.isEmpty
          ? MemoryEmptyState(
              hasAnyMemories: false,
              onCapture: () => Navigator.pushNamed(context, AppRoutes.camera),
              onResetFilter: () {},
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _MyFramesHeader(
                    total: frames.length,
                    filter: _filter,
                    onFilterChanged: (value) =>
                        setState(() => _filter = value),
                  ),
                ),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: MemoryEmptyState(
                      hasAnyMemories: true,
                      onCapture: () =>
                          Navigator.pushNamed(context, AppRoutes.camera),
                      onResetFilter: () =>
                          setState(() => _filter = MyFramesFilter.all),
                    ),
                  )
                else
                  SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final frame = shown[index];
                      return MyFrameTile(
                        key: ValueKey('my_frame_tile_${frame.id}'),
                        frame: frame,
                        onTap: () => _open(context, frame),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  void _open(BuildContext context, AnchorMemory frame) {
    Navigator.pushNamed(context, AppRoutes.memoryDetails, arguments: frame.id);
  }
}

class _MyFramesHeader extends StatelessWidget {
  const _MyFramesHeader({
    required this.total,
    required this.filter,
    required this.onFilterChanged,
  });

  final int total;
  final MyFramesFilter filter;
  final ValueChanged<MyFramesFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('my_frames_count'),
            total == 1 ? '1 frame' : '$total frames',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Only you see this list. Friends see a frame only at the place '
            'where you put it.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in MyFramesFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('my_frames_filter_${option.name}'),
                      label: Text(option.label),
                      selected: option == filter,
                      onSelected: (_) => onFilterChanged(option),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
