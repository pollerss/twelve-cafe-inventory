import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';
import 'ui.dart';

class ArchivedItemsPage extends StatefulWidget {
  const ArchivedItemsPage({super.key, required this.onChanged});
  final Future<void> Function() onChanged;

  @override
  State<ArchivedItemsPage> createState() => _ArchivedItemsPageState();
}

class _ArchivedItemsPageState extends State<ArchivedItemsPage> {
  final repo = InventoryRepository();
  late Future<List<InventoryItem>> items;

  @override
  void initState() {
    super.initState();
    items = repo.fetchArchived();
  }

  void reload() => setState(() => items = repo.fetchArchived());

  Future<void> restore(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore inventory item?'),
        content: Text('${item.name} will return to the active inventory. Its previous transaction history stays attached.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.restoreItem(item);
      await widget.onChanged();
      reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} restored.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not restore item: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived items')),
      body: FutureBuilder<List<InventoryItem>>(
        future: items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load archived items', message: 'Check your connection and try again.');
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) {
            return const EmptyState(icon: Icons.archive_outlined, title: 'No archived items', message: 'Items archived by managers will appear here and can be restored later.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.archive_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${item.code} • ${item.type}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    FilledButton.tonal(onPressed: () => restore(item), child: const Text('Restore')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
