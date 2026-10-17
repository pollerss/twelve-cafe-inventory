import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';
import 'ui.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.items,
    required this.repo,
    required this.role,
    required this.revision,
    required this.onOpenItem,
    required this.onAddItem,
    required this.onInventory,
    required this.onRestock,
    required this.onActivity,
    required this.onInitialCount,
    required this.onStockIn,
    required this.onStockOut,
  });

  final List<InventoryItem> items;
  final InventoryRepository repo;
  final String role;
  final int revision;
  final void Function(InventoryItem) onOpenItem;
  final Future<void> Function() onAddItem;
  final VoidCallback onInventory;
  final VoidCallback onRestock;
  final VoidCallback onActivity;
  final VoidCallback onInitialCount;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _future = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.repo.activity(),
      widget.repo.restocks(),
    ]);
    return _DashboardData(
      activity: (results[0] as List).cast<Map<String, dynamic>>(),
      restocks: (results[1] as List).cast<Map<String, dynamic>>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorded = widget.items.where((item) => item.quantity != null).length;
    final low = widget.items.where((item) => item.status == 'LOW STOCK').toList();
    final out = widget.items.where((item) => item.status == 'OUT OF STOCK').toList();
    final unknown = widget.items.where((item) => item.status == 'UNRECORDED').toList();
    final needsSetup = widget.items
        .where((item) => item.unit?.trim().isNotEmpty != true || item.minimum == null || item.target == null)
        .toList();

    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _DashboardData(activity: [], restocks: []);
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1080;
            final tablet = constraints.maxWidth >= 760;
            final horizontalPadding = desktop ? 26.0 : 18.0;

            return RefreshIndicator(
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontalPadding, 22, horizontalPadding, 38),
                children: [
                  PageHeader(
                    title: 'Dashboard',
                    subtitle: 'Overview of your café inventory at a glance.',
                    trailing: tablet
                        ? OutlinedButton.icon(
                            onPressed: widget.onInventory,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('View inventory'),
                          )
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _MetricGrid(
                    desktop: desktop,
                    items: [
                      _MetricData('Total Items', widget.items.length, Icons.inventory_2_outlined, CafeColors.espresso),
                      _MetricData('Recorded', recorded, Icons.storage_outlined, CafeColors.success),
                      _MetricData('Low Stock', low.length, Icons.warning_amber_rounded, CafeColors.warning),
                      _MetricData('Out of Stock', out.length, Icons.cancel_outlined, CafeColors.danger),
                      _MetricData('Unrecorded', unknown.length, Icons.description_outlined, CafeColors.neutral),
                    ],
                    onTap: widget.onInventory,
                  ),
                  const SizedBox(height: 16),
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: _StockByCategory(items: widget.items)),
                        const SizedBox(width: 16),
                        Expanded(flex: 12, child: _MovementCard(activity: data.activity)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 300,
                          child: _QuickActions(
                            role: widget.role,
                            onAdd: widget.onAddItem,
                            onCount: widget.onInitialCount,
                            onStockIn: widget.onStockIn,
                            onStockOut: widget.onStockOut,
                            onRestock: widget.onRestock,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _StockByCategory(items: widget.items),
                    const SizedBox(height: 14),
                    _MovementCard(activity: data.activity),
                    const SizedBox(height: 14),
                    _QuickActions(
                      role: widget.role,
                      onAdd: widget.onAddItem,
                      onCount: widget.onInitialCount,
                      onStockIn: widget.onStockIn,
                      onStockOut: widget.onStockOut,
                      onRestock: widget.onRestock,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 10,
                          child: _UpcomingRestock(
                            requests: data.restocks,
                            items: widget.items,
                            onViewAll: widget.onRestock,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 10,
                          child: _NeedsAttention(
                            low: low,
                            out: out,
                            unknown: unknown,
                            needsSetup: needsSetup,
                            onOpen: widget.onOpenItem,
                            onViewAll: widget.onInventory,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _RecentActivity(activity: data.activity, onViewAll: widget.onActivity),
                        ),
                      ],
                    )
                  else ...[
                    _UpcomingRestock(requests: data.restocks, items: widget.items, onViewAll: widget.onRestock),
                    const SizedBox(height: 14),
                    _NeedsAttention(
                      low: low,
                      out: out,
                      unknown: unknown,
                      needsSetup: needsSetup,
                      onOpen: widget.onOpenItem,
                      onViewAll: widget.onInventory,
                    ),
                    const SizedBox(height: 14),
                    _RecentActivity(activity: data.activity, onViewAll: widget.onActivity),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData({required this.activity, required this.restocks});
  final List<Map<String, dynamic>> activity;
  final List<Map<String, dynamic>> restocks;
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.desktop, required this.items, required this.onTap});
  final bool desktop;
  final List<_MetricData> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = desktop ? 5 : constraints.maxWidth >= 720 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _CompactMetricCard(data: item, onTap: onTap),
              ),
          ],
        );
      },
    );
  }
}

class _CompactMetricCard extends StatelessWidget {
  const _CompactMetricCard({required this.data, required this.onTap});
  final _MetricData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withAlpha(150)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: data.color.withAlpha(22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(data.icon, color: data.color, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text('${data.value}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockByCategory extends StatelessWidget {
  const _StockByCategory({required this.items});
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final groups = <String, int>{};
    for (final item in items) {
      final key = item.category?.trim().isNotEmpty == true ? item.category!.trim() : item.type;
      groups[key] = (groups[key] ?? 0) + 1;
    }
    final entries = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final total = math.max(1, items.length);
    final colors = [
      CafeColors.espressoDeep,
      CafeColors.caramel,
      const Color(0xFFD7C5AE),
      const Color(0xFF8E9D66),
      const Color(0xFFB2A07C),
      const Color(0xFFCED7A3),
    ];

    return _DashboardCard(
      title: 'Stock by Category',
      child: SizedBox(
        height: 250,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 178,
                  height: 178,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(178),
                        painter: _DonutPainter(
                          values: top.map((entry) => entry.value.toDouble()).toList(),
                          colors: colors,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${items.length}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                          Text('Items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (top.isEmpty)
                    const Text('No categories yet')
                  else
                    for (var index = 0; index < top.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[index % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(top[index].key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${top[index].value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 5),
                            Text('(${((top[index].value / total) * 100).round()}%)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xFFE9E5DE);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = (values[index] / total) * math.pi * 2;
      paint.color = colors[index % colors.length];
      canvas.drawArc(rect, start + .018, math.max(0.0, sweep - .036), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values || oldDelegate.colors != colors;
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.activity});
  final List<Map<String, dynamic>> activity;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index));
      return _DayMovement(date: date);
    });

    for (final row in activity) {
      final parsed = DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal();
      if (parsed == null) continue;
      for (final day in days) {
        if (parsed.year == day.date.year && parsed.month == day.date.month && parsed.day == day.date.day) {
          final kind = (row['kind'] ?? '').toString();
          if (kind == 'STOCK_OUT') {
            day.outCount++;
          } else if (kind == 'STOCK_IN' || kind == 'RESTOCK_RECEIVED' || kind == 'PRODUCTION') {
            day.inCount++;
          }
        }
      }
    }

    final maxValue = math.max(1, days.fold<int>(0, (best, day) => math.max(best, math.max(day.inCount, day.outCount))));

    return _DashboardCard(
      title: 'Weekly Inventory Movement',
      trailing: const _Legend(),
      child: SizedBox(
        height: 250,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Bar(value: day.inCount, maxValue: maxValue, color: CafeColors.success),
                            const SizedBox(width: 4),
                            _Bar(value: day.outCount, maxValue: maxValue, color: const Color(0xFFD3AA79)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(_weekday(day.date.weekday), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${day.date.month}/${day.date.day}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _weekday(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

class _DayMovement {
  _DayMovement({required this.date});
  final DateTime date;
  int inCount = 0;
  int outCount = 0;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.maxValue, required this.color});
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = value == 0 ? .04 : math.max(.12, value / maxValue).toDouble();
    return Tooltip(
      message: '$value transaction${value == 1 ? '' : 's'}',
      child: FractionallySizedBox(
        heightFactor: fraction,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 18,
          decoration: BoxDecoration(color: color.withAlpha(value == 0 ? 40 : 220), borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: const [
        _LegendItem(color: CafeColors.success, label: 'Stock In'),
        _LegendItem(color: Color(0xFFD3AA79), label: 'Stock Out'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.role,
    required this.onAdd,
    required this.onCount,
    required this.onStockIn,
    required this.onStockOut,
    required this.onRestock,
  });

  final String role;
  final Future<void> Function() onAdd;
  final VoidCallback onCount;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    final manager = role != 'staff';
    return _DashboardCard(
      title: 'Quick Actions',
      child: Column(
        children: [
          if (manager) _QuickActionButton(icon: Icons.add_rounded, label: 'Add Item', primary: true, onTap: onAdd),
          if (manager) const SizedBox(height: 8),
          if (manager) _QuickActionButton(icon: Icons.fact_check_outlined, label: 'Record Count', onTap: onCount),
          if (manager) const SizedBox(height: 8),
          _QuickActionButton(icon: Icons.south_rounded, label: 'Stock In', onTap: onStockIn),
          const SizedBox(height: 8),
          _QuickActionButton(icon: Icons.north_rounded, label: 'Stock Out', onTap: onStockOut),
          const SizedBox(height: 8),
          _QuickActionButton(icon: Icons.shopping_cart_checkout_rounded, label: 'Create Restock Request', onTap: onRestock),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: primary ? CafeColors.espressoDeep : scheme.surfaceContainerHighest.withAlpha(130),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: primary ? Colors.white : scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: primary ? Colors.white : scheme.onSurface))),
              Icon(Icons.chevron_right_rounded, color: primary ? Colors.white70 : scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingRestock extends StatelessWidget {
  const _UpcomingRestock({required this.requests, required this.items, required this.onViewAll});
  final List<Map<String, dynamic>> requests;
  final List<InventoryItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final active = requests.where((row) => !['RECEIVED', 'CANCELLED'].contains((row['status'] ?? '').toString())).take(6).toList();
    return _DashboardCard(
      title: 'Upcoming Restock',
      trailing: TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: active.isEmpty
          ? const _MiniEmpty(icon: Icons.local_shipping_outlined, text: 'No active restock requests.')
          : Column(
              children: [
                for (var index = 0; index < active.length; index++) ...[
                  _RestockRow(row: active[index], items: items),
                  if (index < active.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _RestockRow extends StatelessWidget {
  const _RestockRow({required this.row, required this.items});
  final Map<String, dynamic> row;
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final itemName = (row['inventory_items']?['name'] ?? 'Inventory item').toString();
    final itemId = (row['item_id'] ?? '').toString();
    InventoryItem? item;
    for (final candidate in items) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    final requested = (row['requested_qty'] as num?)?.toDouble();
    final received = (row['received_qty'] as num?)?.toDouble() ?? 0;
    final status = (row['status'] ?? 'REQUESTED').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _ItemGlyph(name: itemName),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item?.stockText ?? 'Stock not loaded', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(requested)} requested', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(received > 0 ? '${_fmt(received)} received • ${titleCaseCode(status)}' : titleCaseCode(status), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeedsAttention extends StatefulWidget {
  const _NeedsAttention({required this.low, required this.out, required this.unknown, required this.needsSetup, required this.onOpen, required this.onViewAll});
  final List<InventoryItem> low;
  final List<InventoryItem> out;
  final List<InventoryItem> unknown;
  final List<InventoryItem> needsSetup;
  final void Function(InventoryItem) onOpen;
  final VoidCallback onViewAll;

  @override
  State<_NeedsAttention> createState() => _NeedsAttentionState();
}

class _NeedsAttentionState extends State<_NeedsAttention> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final groups = [widget.low, widget.out, widget.unknown, widget.needsSetup];
    final labels = ['Low Stock', 'Out of Stock', 'Unrecorded', 'Needs Setup'];
    final data = groups[selected];
    return _DashboardCard(
      title: 'Needs Attention',
      trailing: TextButton(onPressed: widget.onViewAll, child: const Text('View all')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++) ...[
                  ChoiceChip(
                    selected: selected == index,
                    label: Text('${labels[index]} ${groups[index].length}'),
                    onSelected: (_) => setState(() => selected = index),
                  ),
                  if (index < labels.length - 1) const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (data.isEmpty)
            const _MiniEmpty(icon: Icons.check_circle_outline_rounded, text: 'Nothing in this group needs attention.')
          else
            for (var index = 0; index < math.min(6, data.length); index++) ...[
              _AttentionItem(item: data[index], onTap: () => widget.onOpen(data[index])),
              if (index < math.min(6, data.length) - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _ItemGlyph(name: item.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(item.category?.trim().isNotEmpty == true ? item.category! : item.type, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(item.stockText, style: TextStyle(fontWeight: FontWeight.w800, color: item.status == 'OUT OF STOCK' ? CafeColors.danger : Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 8),
            StatusPill(label: item.status, tone: _toneForStatus(item.status)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.activity, required this.onViewAll});
  final List<Map<String, dynamic>> activity;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final data = activity.take(6).toList();
    return _DashboardCard(
      title: 'Recent Activity',
      trailing: TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: data.isEmpty
          ? const _MiniEmpty(icon: Icons.history_rounded, text: 'No inventory activity yet.')
          : Column(
              children: [
                for (var index = 0; index < data.length; index++) ...[
                  _ActivityRow(row: data[index]),
                  if (index < data.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final employee = (row['employee_name'] ?? 'Employee').toString();
    final kind = (row['kind'] ?? 'ACTIVITY').toString();
    final item = (row['inventory_items']?['name'] ?? 'Inventory item').toString();
    final reason = ((row['detail'] ?? row['reason_code'] ?? row['reason']) ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _activityColor(kind).withAlpha(28),
            foregroundColor: _activityColor(kind),
            child: Text(employee.trim().isNotEmpty ? employee.trim()[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(employee, style: const TextStyle(fontWeight: FontWeight.w800)),
                    StatusPill(label: titleCaseCode(kind), tone: _toneForKind(kind)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$item${reason.trim().isEmpty ? '' : ' • $reason'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_timeOnly(row['created_at']), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(145)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Flexible(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _ItemGlyph extends StatelessWidget {
  const _ItemGlyph({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: CafeColors.creamDeep, borderRadius: BorderRadius.circular(11)),
      child: Icon(_iconForName(name), size: 19, color: CafeColors.espresso),
    );
  }

  IconData _iconForName(String value) {
    final name = value.toLowerCase();
    if (name.contains('milk') || name.contains('cream')) return Icons.local_drink_outlined;
    if (name.contains('coffee') || name.contains('matcha')) return Icons.coffee_outlined;
    if (name.contains('bread') || name.contains('croissant')) return Icons.bakery_dining_outlined;
    if (name.contains('cup') || name.contains('lid')) return Icons.local_cafe_outlined;
    if (name.contains('syrup') || name.contains('sauce')) return Icons.local_bar_outlined;
    return Icons.inventory_2_outlined;
  }
}

String _fmt(double? value) {
  if (value == null) return '—';
  if (value % 1 == 0) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

String _timeOnly(dynamic value) {
  final parsed = DateTime.tryParse((value ?? '').toString())?.toLocal();
  if (parsed == null) return '';
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

Color _activityColor(String kind) {
  if (kind.contains('OUT')) return CafeColors.warning;
  if (kind.contains('IN') || kind.contains('RECEIVED') || kind.contains('PRODUCTION')) return CafeColors.success;
  if (kind.contains('COUNT') || kind.contains('ADJUST')) return CafeColors.espresso;
  return CafeColors.neutral;
}

StatusTone _toneForKind(String kind) {
  if (kind.contains('OUT')) return StatusTone.warning;
  if (kind.contains('IN') || kind.contains('RECEIVED') || kind.contains('PRODUCTION')) return StatusTone.success;
  return StatusTone.neutral;
}

StatusTone _toneForStatus(String status) {
  return switch (status) {
    'AVAILABLE' => StatusTone.success,
    'LOW STOCK' => StatusTone.warning,
    'OUT OF STOCK' => StatusTone.danger,
    _ => StatusTone.neutral,
  };
}
