import 'package:flutter/material.dart';

class AdminConfirmation {
  const AdminConfirmation({
    required this.title,
    required this.description,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.scopeLabel,
    this.requireTypedConfirmation,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? scopeLabel;
  final String? requireTypedConfirmation;
}

Future<bool> showAdminConfirmDialog(BuildContext context, {required AdminConfirmation confirmation}) async {
  final requiredText = confirmation.requireTypedConfirmation;
  var typedMatches = requiredText == null;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !confirmation.destructive,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        icon: Icon(
          confirmation.destructive ? Icons.warning_amber_rounded : Icons.help_outline,
          color: confirmation.destructive ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(confirmation.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(confirmation.description),
              if (confirmation.scopeLabel != null) ...[
                const SizedBox(height: 14),
                Text('Scope: \${confirmation.scopeLabel}', style: Theme.of(context).textTheme.labelLarge),
              ],
              if (requiredText != null) ...[
                const SizedBox(height: 18),
                Text('Type "$requiredText" to continue.'),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setDialogState(() => typedMatches = value.trim() == requiredText),
                  decoration: const InputDecoration(labelText: 'Confirmation text'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(confirmation.cancelLabel)),
          FilledButton(
            style: confirmation.destructive ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ) : null,
            onPressed: typedMatches ? () => Navigator.of(dialogContext).pop(true) : null,
            child: Text(confirmation.confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
