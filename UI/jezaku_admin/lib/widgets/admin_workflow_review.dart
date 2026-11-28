import 'package:flutter/material.dart';

class AdminReviewItem {
  const AdminReviewItem({required this.label, required this.value});
  final String label;
  final String value;
}

Future<String?> showAdminWorkflowReview(
  BuildContext context, {
  required String title,
  required String consequence,
  required String scope,
  required List<AdminReviewItem> items,
  bool requireReason = true,
}) {
  final reasonController = TextEditingController();
  var reasonValid = !requireReason;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Review $title'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(consequence),
              const SizedBox(height: 14),
              Text('Scope', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(scope),
              const Divider(height: 24),
              for (final item in items) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 112, child: Text(item.label, style: Theme.of(context).textTheme.labelMedium)),
                  Expanded(child: Text(item.value)),
                ]),
              ),
              const SizedBox(height: 8),
              TextFormField(
                autofocus: requireReason,
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                onChanged: (value) => setDialogState(() => reasonValid = !requireReason || value.trim().isNotEmpty),
                decoration: InputDecoration(labelText: requireReason ? 'Reason *' : 'Reason (optional)', hintText: 'Explain why this operation is required'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Back to edit')),
          FilledButton(
            onPressed: reasonValid ? () => Navigator.of(dialogContext).pop(reasonController.text.trim()) : null,
            child: const Text('Confirm review'),
          ),
        ],
      ),
    ),
  ).whenComplete(reasonController.dispose);
}
