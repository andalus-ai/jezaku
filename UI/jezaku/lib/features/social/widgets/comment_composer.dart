import 'package:material_ui/material_ui.dart';

/// Text field plus send button pinned to the bottom of a comment thread.
///
/// Owns its text controller, trims the text, ignores empty submissions and
/// clears itself after [onSubmit].
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.onSubmit,
    this.hintText = 'Add a comment',
  });

  final ValueChanged<String> onSubmit;
  final String hintText;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('comment_field'),
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Post comment',
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
