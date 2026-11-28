import 'package:flutter/material.dart';

enum AdminActivitySeverity { normal, warning, critical }

class AdminActivityEntry {
  const AdminActivityEntry({
    required this.title,
    required this.actor,
    required this.timestamp,
    this.description,
    this.severity = AdminActivitySeverity.normal,
    this.reference,
  });
  final String title;
  final String actor;
  final DateTime timestamp;
  final String? description;
  final AdminActivitySeverity severity;
  final String? reference;
}

class AdminActivityTimeline extends StatelessWidget {
  const AdminActivityTimeline({required this.entries, super.key});
  final List<AdminActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('No activity has been recorded for this item.'));
    final colors = Theme.of(context).colorScheme;
    return Column(children: [
      for (var i = 0; i < entries.length; i++)
        _TimelineRow(
          entry: entries[i],
          last: i == entries.length - 1,
          color: switch (entries[i].severity) {
            AdminActivitySeverity.normal => colors.primary,
            AdminActivitySeverity.warning => colors.tertiary,
            AdminActivitySeverity.critical => colors.error,
          },
        ),
    ]);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.last, required this.color});
  final AdminActivityEntry entry;
  final bool last;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatMediumDate(entry.timestamp);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.timestamp));
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 28, child: Column(children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (!last) Expanded(child: Container(width: 2, color: colors.outlineVariant)),
        ])),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('$date · $time · ${entry.actor}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            if (entry.description != null) ...[
              const SizedBox(height: 5),
              Text(entry.description!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (entry.reference != null) ...[
              const SizedBox(height: 4),
              SelectableText('Reference: ${entry.reference}', style: Theme.of(context).textTheme.labelSmall),
            ],
          ]),
        )),
      ]),
    );
  }
}
