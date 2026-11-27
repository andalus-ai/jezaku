import 'package:alhambra_ui/alhambra_ui.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

const _brand = Color(0xFF245B73);
const _pageMaxWidth = 1440.0;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF78BBD0),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Jezaku Admin',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AlhambraTheme.light(primary: _brand).copyWith(
        colorScheme: lightScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F9),
          foregroundColor: Color(0xFF18252D),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5EAEE)),
          ),
        ),
        dividerColor: const Color(0xFFE8EDF0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF10171C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF10171C),
          foregroundColor: Color(0xFFE8F0F3),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF182229),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2A3942)),
          ),
        ),
        dividerColor: const Color(0xFF2A3942),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF182229),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: AdminHomePage(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class _AdminSection {
  const _AdminSection(this.label, this.icon, this.description);

  final String label;
  final IconData icon;
  final String description;
}

const _sections = <_AdminSection>[
  _AdminSection(
    'Overview',
    Icons.space_dashboard_outlined,
    'Platform status and activity',
  ),
  _AdminSection(
    'People & Access',
    Icons.manage_accounts_outlined,
    'Operators, roles and permissions',
  ),
  _AdminSection(
    'Trust & Safety',
    Icons.shield_outlined,
    'Reports, moderation and restrictions',
  ),
  _AdminSection(
    'Spatial Operations',
    Icons.public_outlined,
    'Places, anchors and spatial content',
  ),
  _AdminSection(
    'Commerce',
    Icons.storefront_outlined,
    'Merchants, campaigns and promotions',
  ),
  _AdminSection(
    'Extensions',
    Icons.extension_outlined,
    'Publishers, packages and reviews',
  ),
  _AdminSection(
    'Operations',
    Icons.monitor_heart_outlined,
    'Services, jobs and diagnostics',
  ),
  _AdminSection(
    'Configuration',
    Icons.tune_outlined,
    'Deployment settings and feature flags',
  ),
  _AdminSection(
    'Audit',
    Icons.history_outlined,
    'Administrative activity history',
  ),
  _AdminSection(
    'System',
    Icons.settings_outlined,
    'Deployment and integrations',
  ),
];

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({
    required this.onToggleTheme,
    required this.isDark,
    super.key,
  });

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  void _selectSection(int index) {
    setState(() => _selectedIndex = index);
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  void _showUnavailable(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final medium = constraints.maxWidth >= 760 &&
            constraints.maxWidth < 1120;
        final section = _sections[_selectedIndex];

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: compact,
            titleSpacing: compact ? 0 : 24,
            title: Row(
              children: [
                if (!compact) ...[
                  const _BrandMark(),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    compact ? 'Jezaku Admin' : section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            actions: [
              if (!compact)
                const _ContextPill(
                  icon: Icons.layers_outlined,
                  label: 'Workspace not selected',
                ),
              const SizedBox(width: 8),
              const _ContextPill(
                icon: Icons.cloud_outlined,
                label: 'Environment not configured',
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Search management areas',
                onPressed: () => showSearch<_AdminSection?>(
                  context: context,
                  delegate: _AdminSearchDelegate(
                    onSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                ),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: widget.isDark ? 'Switch to light theme' : 'Switch to dark theme',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Notifications unavailable',
                onPressed: () => _showUnavailable(
                  'Notifications unavailable',
                  'A notification service has not been connected to this console yet.',
                ),
                icon: const Icon(Icons.notifications_none_outlined),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Authentication not connected',
                onPressed: () => _showUnavailable(
                  'Authentication not connected',
                  'Operator identity and session management will be available after the approved identity integration is configured.',
                ),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              const SizedBox(width: 12),
            ],
          ),
          drawer: compact
              ? Drawer(
                  child: SafeArea(
                    child: _Sidebar(
                      selectedIndex: _selectedIndex,
                      expanded: true,
                      onSelect: (index) {
                        setState(() => _selectedIndex = index);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                SizedBox(
                  width: medium || !_sidebarExpanded ? 80 : 264,
                  child: _Sidebar(
                    selectedIndex: _selectedIndex,
                    expanded: !medium && _sidebarExpanded,
                    onSelect: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    onToggle: () {
                      setState(() => _sidebarExpanded = !_sidebarExpanded);
                    },
                  ),
                ),
              if (!compact) const VerticalDivider(width: 1),
              Expanded(
                child: _selectedIndex == 0
                    ? const _OverviewPage()
                    : _SectionPlaceholder(section: section),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.layers_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.expanded,
    required this.onSelect,
    this.onToggle,
  });

  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
              child: Row(
                children: [
                  const _BrandMark(),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JEZAKU',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                        ),
                        Text(
                          'ADMIN CONSOLE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (onToggle != null)
                    IconButton(
                      tooltip: 'Collapse sidebar',
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: IconButton(
                tooltip: 'Expand sidebar',
                onPressed: onToggle,
                icon: const Icon(Icons.menu_open_rounded),
              ),
            ),
          if (expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MANAGEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.25,
                    color: Color(0xFF82919A),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final item = _sections[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Tooltip(
                    message: expanded ? '' : item.label,
                    child: Material(
                      color: selected
                          ? colors.primaryContainer.withValues(alpha: 0.75)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelect(index),
                        child: SizedBox(
                          height: 46,
                          child: Row(
                            children: [
                              SizedBox(
                                width: expanded ? 44 : 62,
                                child: Icon(
                                  item.icon,
                                  size: 20,
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              if (expanded)
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurface,
                                        ),
                                  ),
                                ),
                              if (expanded && selected)
                                Container(
                                  width: 3,
                                  height: 22,
                                  margin: const EdgeInsets.only(right: 9),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Backend integrations pending',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform overview',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w750,
                                letterSpacing: -0.7,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Operational visibility for your Jezaku deployment.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _ConnectionNotice(),
              const SizedBox(height: 26),
              _SectionHeading(
                title: 'Platform signals',
                subtitle: 'Live metrics will appear when service integrations are configured.',
              ),
              const SizedBox(height: 13),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                  const gap = 14.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: const [
                      _MetricCard(
                        title: 'Service health',
                        value: 'Unavailable',
                        detail: 'Health endpoint not connected',
                        icon: Icons.monitor_heart_outlined,
                        state: _MetricState.unavailable,
                      ),
                      _MetricCard(
                        title: 'Pending reviews',
                        value: 'Unavailable',
                        detail: 'Moderation data not connected',
                        icon: Icons.fact_check_outlined,
                        state: _MetricState.unavailable,
                      ),
                      _MetricCard(
                        title: 'Active operators',
                        value: 'Unavailable',
                        detail: 'Identity data not connected',
                        icon: Icons.admin_panel_settings_outlined,
                        state: _MetricState.unavailable,
                      ),
                      _MetricCard(
                        title: 'Recent activity',
                        value: 'Unavailable',
                        detail: 'Audit feed not connected',
                        icon: Icons.receipt_long_outlined,
                        state: _MetricState.unavailable,
                      ),
                    ].map((card) => SizedBox(width: width, child: card)).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final primary = _ManagementAreas(
                    onSelect: (index) {
                      final state = context.findAncestorStateOfType<_AdminHomePageState>();
                      state?._selectSection(index);
                    },
                  );
                  final secondary = const _ActivityPanel();
                  if (!wide) {
                    return Column(
                      children: [
                        primary,
                        const SizedBox(height: 16),
                        secondary,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: primary),
                      const SizedBox(width: 16),
                      const Expanded(flex: 4, child: secondary),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              const _FooterNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onSecondaryContainer),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend integrations are not connected',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSecondaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard values are intentionally not simulated. Connect approved service health, identity, moderation and audit APIs before using this console for live operations.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _MetricState { unavailable }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.state,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final _MetricState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: colors.primary),
                ),
                const Spacer(),
                const _StateLabel(
                  label: 'Not connected',
                  icon: Icons.remove_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 19),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ManagementAreas extends StatelessWidget {
  const _ManagementAreas({required this.onSelect});

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Management areas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Explore the administrative capabilities of Jezaku.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            for (var i = 1; i < _sections.length; i++) ...[
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _sections[i].icon,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sections[i].label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _sections[i].description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const _StateLabel(
                        label: 'Planned',
                        icon: Icons.schedule_outlined,
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (i != _sections.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Administrative events from connected services.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 34,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Activity feed unavailable',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Connect the audit service to view recent events.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Administrative actions will be enabled only after authentication, authorization and audit integrations are verified.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.section});

  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(section.icon, size: 30, color: colors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                section.label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                section.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              const _StateLabel(
                label: 'Not implemented',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 12),
              Text(
                'This area will be enabled when its owning Jezaku backend service exposes a documented, authorized management contract.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSearchDelegate extends SearchDelegate<_AdminSection?> {
  _AdminSearchDelegate({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  String get searchFieldLabel => 'Search management areas';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          tooltip: 'Clear search',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Close search',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final matches = <int>[
      for (var i = 0; i < _sections.length; i++)
        if (_sections[i].label.toLowerCase().contains(query.toLowerCase()) ||
            _sections[i].description.toLowerCase().contains(query.toLowerCase()))
          i,
    ];
    if (matches.isEmpty) {
      return const Center(child: Text('No matching management areas'));
    }
    return ListView(
      children: [
        for (final index in matches)
          ListTile(
            leading: Icon(_sections[index].icon),
            title: Text(_sections[index].label),
            subtitle: Text(_sections[index].description),
            onTap: () {
              onSelected(index);
              close(context, _sections[index]);
            },
          ),
      ],
    );
  }
}
