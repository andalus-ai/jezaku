import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:material_ui/material_ui.dart';

class EmptyWallFilterState extends StatelessWidget {
  const EmptyWallFilterState({
    required this.filter,
    required this.query,
    super.key,
  });

  final ARWallFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view, color: colorScheme.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No ${filter.label.toLowerCase()} walls'
                  : 'No matching walls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Create or join a wall to see it in this view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
