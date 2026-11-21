import 'package:material_ui/material_ui.dart';

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key});

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _inviteeController = TextEditingController();
  var _showInviteeError = false;

  @override
  void dispose() {
    _inviteeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite member'),
      content: TextField(
        key: const ValueKey('wall_invitee_field'),
        controller: _inviteeController,
        decoration: InputDecoration(
          labelText: 'Name or email',
          errorText: _showInviteeError ? 'Invitee required' : null,
        ),
        onChanged: (_) {
          if (_showInviteeError) {
            setState(() => _showInviteeError = false);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _invite,
          child: const Text('Invite'),
        ),
      ],
    );
  }

  void _invite() {
    final invitee = _inviteeController.text.trim();
    if (invitee.isEmpty) {
      setState(() => _showInviteeError = true);
      return;
    }

    Navigator.pop(context, invitee);
  }
}
