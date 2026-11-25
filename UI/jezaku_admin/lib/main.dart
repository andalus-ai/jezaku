import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF245B73),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Jezaku Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE3E8ED)),
          ),
        ),
      ),
      home: const AdminHomePage(),
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
  _AdminSection('Overview', Icons.space_dashboard_outlined, 'Platform status and activity'),
  _AdminSection('People & Access', Icons.manage_accounts_outlined, 'Operators, roles and permissions'),
  _AdminSection('Trust & Safety', Icons.shield_outlined, 'Reports, moderation and restrictions'),
  _AdminSection('Spatial Operations', Icons.public_outlined, 'Places, anchors and spatial content'),
  _AdminSection('Commerce', Icons.storefront_outlined, 'Merchants, campaigns and promotions'),
  _AdminSection('Extensions', Icons.extension_outlined, 'Publishers, packages and reviews'),
  _AdminSection('Operations', Icons.monitor_heart_outlined, 'Services, jobs and diagnostics'),
  _AdminSection('Configuration', Icons.tune_outlined, 'Deployment settings and feature flags'),
  _AdminSection('Audit', Icons.history_outlined, 'Administrative activity history'),
  _AdminSection('System', Icons.settings_outlined, 'Deployment and integrations'),
];

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  void _selectSection(int index) {
    setState(() => _selectedIndex = index);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final section = _sections[_selectedIndex];

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.layers_outlined, size: 24),
                SizedBox(width: 10),
                Text('Jezaku Admin'),
              ],
            ),
            actions: [
              const Tooltip(
                message: 'Authentication is not connected yet',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.account_circle_outlined),
                ),
              ),
            ],
          ),
          drawer: compact
              ? Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 20),
                          child: Text(
                            'MANAGEMENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        for (var i = 0; i < _sections.length; i++)
                          _NavigationItem(
                            section: _sections[i],
                            selected: i == _selectedIndex,
                            onTap: () => _selectSection(i),
                          ),
                      ],
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectSection,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final item in _sections)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _AdminSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: Icon(section.icon),
      title: Text(section.label),
      subtitle: Text(section.description),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform overview',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Operational visibility and management for your Jezaku deployment.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              const _ConnectionNotice(),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: const [
                  _StatusCard(
                    title: 'Services',
                    value: 'Not connected',
                    detail: 'Health data is not configured',
                    icon: Icons.hub_outlined,
                  ),
                  _StatusCard(
                    title: 'Pending reviews',
                    value: 'Not available',
                    detail: 'Moderation API is not connected',
                    icon: Icons.fact_check_outlined,
                  ),
                  _StatusCard(
                    title: 'Active operators',
                    value: 'Not available',
                    detail: 'Identity integration is not connected',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  _StatusCard(
                    title: 'Recent activity',
                    value: 'Not available',
                    detail: 'Audit feed is not connected',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Management areas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (var i = 1; i < _sections.length; i++) ...[
                      ListTile(
                        leading: Icon(_sections[i].icon),
                        title: Text(_sections[i].label),
                        subtitle: Text(_sections[i].description),
                        trailing: const Chip(label: Text('Planned')),
                      ),
                      if (i != _sections.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'This console is an initial UI foundation. No administrative '
                'backend actions are available yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend integrations are not connected'),
                SizedBox(height: 4),
                Text(
                  'Values are intentionally not simulated. Connect approved '
                  'service health, identity, moderation and audit APIs before '
                  'using this console for live operations.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.section});

  final _AdminSection section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 48,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(section.label,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(section.description, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Chip(label: Text('Not implemented')),
              const SizedBox(height: 8),
              const Text(
                'This area will be enabled when its owning Jezaku backend '
                'service exposes a documented, authorized management contract.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
