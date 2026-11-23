import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/frame_styles/widgets/frame_style_picker.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:material_ui/material_ui.dart';

/// The user's pick in the frame gallery. [colorValue] null means the look's
/// own colour.
class FrameStyleChoice {
  const FrameStyleChoice({required this.lookId, this.colorValue});

  final String lookId;
  final int? colorValue;
}

/// Opens the frame gallery as a bottom sheet and returns the choice, or null
/// when dismissed. Nothing is saved here; callers apply the result.
Future<FrameStyleChoice?> showFrameStyleSheet(
  BuildContext context, {
  required String title,
  required String initialLookId,
  int? initialColorValue,
}) {
  return showModalBottomSheet<FrameStyleChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FrameStyleSheet(
      title: title,
      initialLookId: initialLookId,
      initialColorValue: initialColorValue,
    ),
  );
}

class _FrameStyleSheet extends StatefulWidget {
  const _FrameStyleSheet({
    required this.title,
    required this.initialLookId,
    required this.initialColorValue,
  });

  final String title;
  final String initialLookId;
  final int? initialColorValue;

  @override
  State<_FrameStyleSheet> createState() => _FrameStyleSheetState();
}

class _FrameStyleSheetState extends State<_FrameStyleSheet> {
  late String _lookId = widget.initialLookId;
  late int? _colorValue = widget.initialColorValue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FrameStylePicker(
              lookId: _lookId,
              colorValue: _colorValue,
              onLookChanged: (id) => setState(() => _lookId = id),
              onColorChanged: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('frame_style_apply'),
                onPressed: () => Navigator.of(context).pop(
                  FrameStyleChoice(lookId: _lookId, colorValue: _colorValue),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the author restyle a frame they already published. The change is
/// stored with the frame and the AR scene picks it up on its next sync.
Future<void> changeFrameStyle(
  BuildContext context,
  WidgetRef ref,
  AnchorMemory memory,
) async {
  final choice = await showFrameStyleSheet(
    context,
    title: 'Change frame',
    initialLookId: memory.frameLookId,
    initialColorValue: memory.frameColorValue,
  );
  if (choice == null) {
    return;
  }
  ref.read(nearbyAnchorsProvider.notifier).updateFrameStyle(
        memoryId: memory.id,
        lookId: choice.lookId,
        colorValue: choice.colorValue,
      );
}

/// Lets the user pick the look new frames get. Existing frames keep theirs.
Future<void> changeDefaultFrameStyle(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(appSettingsProvider);
  final choice = await showFrameStyleSheet(
    context,
    title: 'Default frame',
    initialLookId: settings.defaultFrameLookId,
    initialColorValue: settings.defaultFrameColorValue,
  );
  if (choice == null) {
    return;
  }
  ref.read(appSettingsProvider.notifier).setDefaultFrame(
        lookId: choice.lookId,
        colorValue: choice.colorValue,
      );
}
