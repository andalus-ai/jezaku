import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:material_ui/material_ui.dart';

class WallItemDraft {
  const WallItemDraft({
    required this.type,
    required this.content,
  });

  final WallItemType type;
  final String content;
}

class AddWallItemDialog extends StatefulWidget {
  const AddWallItemDialog({super.key});

  @override
  State<AddWallItemDialog> createState() => _AddWallItemDialogState();
}

class _AddWallItemDialogState extends State<AddWallItemDialog> {
  final _contentController = TextEditingController();
  var _selectedType = WallItemType.note;
  var _showContentError = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add wall item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WallItemType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in WallItemType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(wallItemTypeLabel(type)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('wall_item_content_field'),
            controller: _contentController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Content',
              errorText: _showContentError ? 'Content required' : null,
            ),
            onChanged: (_) {
              if (_showContentError) {
                setState(() => _showContentError = false);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _addItem,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _addItem() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _showContentError = true);
      return;
    }

    Navigator.pop(
      context,
      WallItemDraft(
        type: _selectedType,
        content: content,
      ),
    );
  }
}

String wallItemTypeLabel(WallItemType type) {
  return switch (type) {
    WallItemType.photo => 'Photo',
    WallItemType.note => 'Note',
    WallItemType.drawing => 'Drawing',
    WallItemType.audio => 'Audio',
    WallItemType.model3d => '3D item',
  };
}
