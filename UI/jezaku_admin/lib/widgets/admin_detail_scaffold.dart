import 'package:flutter/material.dart';

class AdminDetailScaffold extends StatelessWidget {
  const AdminDetailScaffold({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tabs,
    required this.tabViews,
    this.leading,
    this.actions = const [],
    this.metadata = const [],
    super.key,
  }) : assert(tabs.length == tabViews.length);

  final String title;
  final String subtitle;
  final Widget status;
  final List<Widget> tabs;
  final List<Widget> tabViews;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> metadata;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                status,
                ...actions.map((action) => Padding(padding: const EdgeInsets.only(left: 8), child: action)),
              ],
            ),
          ),
          if (metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Wrap(spacing: 22, runSpacing: 10, children: metadata),
            ),
          TabBar(isScrollable: true, tabAlignment: TabAlignment.start, padding: const EdgeInsets.symmetric(horizontal: 16), tabs: tabs),
          Expanded(
            child: TabBarView(
              children: [for (final view in tabViews) SingleChildScrollView(padding: const EdgeInsets.all(24), child: view)],
            ),
          ),
        ],
      ),
    );
  }
}
