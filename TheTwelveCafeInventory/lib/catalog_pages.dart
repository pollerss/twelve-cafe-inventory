import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';
import 'ui.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.items, required this.onOpenItem});
  final List<InventoryItem> items;
  final void Function(InventoryItem) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<InventoryItem>>{};
    for (final item in items) {
      final key = item.category?.trim().isNotEmpty == true ? item.category!.trim() : item.type;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final entries = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 38),
      children: [
        const PageHeader(
          title: 'Categories',
          subtitle: 'See how inventory is organized and which categories need attention.',
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          const SectionCard(
            child: EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              message: 'Add or edit an inventory item to assign a category.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
              const gap = 14.0;
              final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: width,
                      child: _CategoryCard(name: entry.key, items: entry.value, onOpenItem: onOpenItem),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.items, required this.onOpenItem});
  final String name;
  final List<InventoryItem> items;
  final void Function(InventoryItem) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final low = items.where((item) => item.status == 'LOW STOCK').length;
    final out = items.where((item) => item.status == 'OUT OF STOCK').length;
    final unknown = items.where((item) => item.status == 'UNRECORDED').length;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: CafeColors.creamDeep, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.category_outlined, color: CafeColors.espresso),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              Text('${items.length}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (low > 0) StatusPill(label: '$low Low', tone: StatusTone.warning),
              if (out > 0) StatusPill(label: '$out Out', tone: StatusTone.danger),
              if (unknown > 0) StatusPill(label: '$unknown Unrecorded', tone: StatusTone.neutral),
              if (low == 0 && out == 0 && unknown == 0) const StatusPill(label: 'Healthy', tone: StatusTone.success),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final item in items.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.stockText),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenItem(item),
            ),
          if (items.length > 5)
            Text('+ ${items.length - 5} more items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key, required this.items, required this.onOpenItem});
  final List<InventoryItem> items;
  final void Function(InventoryItem) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<InventoryItem>>{};
    for (final item in items) {
      final unit = item.unit?.trim().isNotEmpty == true ? item.unit!.trim() : 'Unit not set';
      groups.putIfAbsent(unit, () => []).add(item);
    }
    final entries = groups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final conversions = items.where((item) => item.packUnit?.trim().isNotEmpty == true && item.unitsPerPack != null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 38),
      children: [
        const PageHeader(
          title: 'Units',
          subtitle: 'Review stock measurement units and purchase-pack conversions.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;
            final overview = SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Base units in use', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  for (final entry in entries) ...[
                    Row(
                      children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: CafeColors.creamDeep, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.straighten_outlined, size: 18, color: CafeColors.espresso)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('${entry.value.length} item${entry.value.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            );

            final pack = SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pack conversions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (conversions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No purchase-pack conversions configured yet.'),
                    )
                  else
                    for (final item in conversions.take(12))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text('1 ${item.packUnit} = ${_number(item.unitsPerPack)} ${item.unit}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => onOpenItem(item),
                      ),
                ],
              ),
            );

            return compact
                ? Column(children: [overview, const SizedBox(height: 14), pack])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: overview), const SizedBox(width: 14), Expanded(child: pack)]);
          },
        ),
      ],
    );
  }

  String _number(double? value) {
    if (value == null) return '—';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key, required this.repo});
  final InventoryRepository repo;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.profiles();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 38),
      children: [
        const PageHeader(
          title: 'Employees',
          subtitle: 'Staff shown here are the people attached to inventory activity and accountability records.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) {
              return const SectionCard(
                child: EmptyState(icon: Icons.people_outline, title: 'Employees could not load', message: 'Check your connection and try again.'),
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return const SectionCard(
                child: EmptyState(icon: Icons.people_outline, title: 'No employee profiles found', message: 'Employee profiles appear after users are created in Supabase Authentication.'),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
                const gap = 14.0;
                final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final row in rows)
                      SizedBox(width: width, child: _EmployeeCard(row: row)),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = (row['display_name'] ?? '').toString().trim();
    final role = (row['role'] ?? 'staff').toString();
    final fallback = name.isEmpty ? 'Unnamed employee' : name;
    return SectionCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: CafeColors.creamDeep,
            foregroundColor: CafeColors.espresso,
            child: Text(fallback[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fallback, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(name.isEmpty ? 'Set a display name from the account settings.' : 'Inventory activity is recorded under this profile.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          StatusPill(label: role.toUpperCase(), tone: role == 'admin' ? StatusTone.success : StatusTone.neutral),
        ],
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.items, required this.repo});
  final List<InventoryItem> items;
  final InventoryRepository repo;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<_ReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportData> _load() async {
    final activity = await widget.repo.activity();
    final restocks = await widget.repo.restocks();
    return _ReportData(activity: activity, restocks: restocks);
  }

  @override
  Widget build(BuildContext context) {
    final low = widget.items.where((item) => item.status == 'LOW STOCK').length;
    final out = widget.items.where((item) => item.status == 'OUT OF STOCK').length;
    final unknown = widget.items.where((item) => item.status == 'UNRECORDED').length;
    final stale = widget.items.where((item) => item.isStale).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 38),
      children: [
        const PageHeader(
          title: 'Reports',
          subtitle: 'Operational summaries based on the inventory and audit records already in the system.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportMetric(label: 'Low Stock', value: low, tone: CafeColors.warning),
            _ReportMetric(label: 'Out of Stock', value: out, tone: CafeColors.danger),
            _ReportMetric(label: 'Unrecorded', value: unknown, tone: CafeColors.neutral),
            _ReportMetric(label: 'Not Updated 7d', value: stale, tone: CafeColors.espresso),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<_ReportData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            if (snapshot.hasError) return const SectionCard(child: Text('Could not load report activity.'));
            final data = snapshot.data ?? const _ReportData(activity: [], restocks: []);
            final now = DateTime.now();
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            final recent = data.activity.where((row) {
              final date = DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal();
              return date != null && date.isAfter(sevenDaysAgo);
            }).toList();
            final stockIn = recent.where((row) => ['STOCK_IN', 'RESTOCK_RECEIVED', 'PRODUCTION'].contains((row['kind'] ?? '').toString())).length;
            final stockOut = recent.where((row) => (row['kind'] ?? '').toString() == 'STOCK_OUT').length;
            final adjustments = recent.where((row) => (row['kind'] ?? '').toString().contains('ADJUST') || (row['kind'] ?? '').toString().contains('COUNT')).length;
            final pendingRestock = data.restocks.where((row) => !['RECEIVED', 'CANCELLED'].contains((row['status'] ?? '').toString())).length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;
                final movement = SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      _ReportLine(label: 'Stock In events', value: stockIn),
                      _ReportLine(label: 'Stock Out events', value: stockOut),
                      _ReportLine(label: 'Counts / adjustments', value: adjustments),
                      _ReportLine(label: 'Pending restock requests', value: pendingRestock),
                    ],
                  ),
                );
                final audit = SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent audit trail', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (data.activity.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No inventory transactions yet.'))
                      else
                        for (final row in data.activity.take(8))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${row['inventory_items']?['name'] ?? 'Item'} • ${titleCaseCode((row['kind'] ?? '').toString())}'),
                            subtitle: Text('${row['employee_name'] ?? 'Employee'} • ${prettyDateTime(row['created_at'])}'),
                          ),
                    ],
                  ),
                );
                return compact ? Column(children: [movement, const SizedBox(height: 14), audit]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: movement), const SizedBox(width: 14), Expanded(child: audit)]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value, required this.tone});
  final String label;
  final int value;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
        child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: tone.withAlpha(22), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.analytics_outlined, color: tone, size: 20)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]))]),
      );
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [Expanded(child: Text(label)), Text('$value', style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}

class _ReportData {
  const _ReportData({required this.activity, required this.restocks});
  final List<Map<String, dynamic>> activity;
  final List<Map<String, dynamic>> restocks;
}
