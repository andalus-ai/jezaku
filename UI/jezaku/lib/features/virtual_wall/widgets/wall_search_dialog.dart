import 'package:material_ui/material_ui.dart';

class WallSearchDialog extends StatefulWidget {
  const WallSearchDialog({required this.initialQuery, super.key});

  final String initialQuery;

  @override
  State<WallSearchDialog> createState() => _WallSearchDialogState();
}

class _WallSearchDialogState extends State<WallSearchDialog> {
  late final _queryController = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search walls'),
      content: TextField(
        key: const ValueKey('wall_search_field'),
        controller: _queryController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          labelText: 'Title or description',
        ),
        onSubmitted: (_) => _applySearch(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: _applySearch,
          child: const Text('Search'),
        ),
      ],
    );
  }

  void _applySearch() {
    Navigator.pop(context, _queryController.text);
  }
}
