import 'package:flutter/material.dart';

class AdminFilterOption {
  const AdminFilterOption({required this.value, required this.label});
  final String value;
  final String label;
}

class AdminFilterGroup {
  const AdminFilterGroup({required this.label, required this.options});
  final String label;
  final List<AdminFilterOption> options;
}

class AdminFilterPanel extends StatefulWidget {
  const AdminFilterPanel({required this.groups, required this.selectedValues, required this.onApply, this.onClear, super.key});
  final List<AdminFilterGroup> groups;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback? onClear;

  @override
  State<AdminFilterPanel> createState() => _AdminFilterPanelState();
}

class _AdminFilterPanelState extends State<AdminFilterPanel> {
  late Set<String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = {...widget.selectedValues};
  }

  @override
  void didUpdateWidget(covariant AdminFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValues != widget.selectedValues) _draft = {...widget.selectedValues};
  }

  @override
  Widget build(BuildContext context) {
    final count = _draft.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleMedium)),
            if (count > 0) Chip(label: Text('$count selected')),
          ]),
          const SizedBox(height: 8),
          for (final group in widget.groups) ...[
            Text(group.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final option in group.options)
                FilterChip(
                  label: Text(option.label),
                  selected: _draft.contains(option.value),
                  onSelected: (selected) => setState(() {
                    if (selected) { _draft.add(option.value); } else { _draft.remove(option.value); }
                  }),
                ),
            ]),
            const SizedBox(height: 12),
          ],
          Row(children: [
            TextButton(onPressed: count == 0 ? null : () => setState(() => _draft.clear()), child: const Text('Clear draft')),
            const Spacer(),
            OutlinedButton(onPressed: () => setState(() => _draft = {...widget.selectedValues}), child: const Text('Reset')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => widget.onApply(Set.unmodifiable(_draft)), child: const Text('Apply filters')),
          ]),
        ]),
      ),
    );
  }
}
