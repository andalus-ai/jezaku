import 'package:flutter/material.dart';
import 'package:jezaku_ds/jezaku_ds.dart';

enum AdminFeedbackKind { loading, empty, error, forbidden, unavailable }

class AdminFeedbackState extends StatelessWidget {
  const AdminFeedbackState({
    required this.kind,
    this.title,
    this.message,
    this.onRetry,
    this.action,
    super.key,
  });

  final AdminFeedbackKind kind;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, defaultTitle, defaultMessage) = switch (kind) {
      AdminFeedbackKind.loading => (null, 'Loading', 'Please wait while this information is retrieved.'),
      AdminFeedbackKind.empty => (Icons.inbox_outlined, 'Nothing here yet', 'There are no records to display.'),
      AdminFeedbackKind.error => (Icons.error_outline, 'Something went wrong', 'The information could not be loaded.'),
      AdminFeedbackKind.forbidden => (Icons.lock_outline, 'Access not permitted', 'Your current access does not allow you to view this information.'),
      AdminFeedbackKind.unavailable => (Icons.cloud_off_outlined, 'Service unavailable', 'This information is not available from a connected service.'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == AdminFeedbackKind.loading)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(icon, size: 38, color: colors.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(title ?? defaultTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message ?? defaultMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              if (onRetry != null || action != null) ...[
                const SizedBox(height: 18),
                if (action != null) action! else JzButton(
                  label: 'Try again',
                  variant: JzButtonVariant.outline,
                  leading: const Icon(Icons.refresh, size: 18),
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
