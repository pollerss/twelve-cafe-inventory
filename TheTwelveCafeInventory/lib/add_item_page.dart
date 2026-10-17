import 'package:flutter/material.dart';

import 'repository.dart';
import 'ui.dart';

const _unitOptions = <String>[
  'pcs',
  'g',
  'kg',
  'mL',
  'L',
  'bottle',
  'pack',
  'box',
  'bag',
  'sack',
  'tray',
  'dozen',
  'can',
  'jar',
  'roll',
  'OTHER',
];

const _categories = <String>[
  'Coffee & Tea',
  'Syrups & Sauces',
  'Milk & Dairy',
  'Pastries & Bakery',
  'Dry Goods',
  'Produce',
  'Meat & Poultry',
  'Packaging',
  'Cleaning Supplies',
  'Prepared / Production',
  'Other',
];

const _locations = <String>[
  'Dry Storage',
  'Chiller',
  'Freezer',
  'Kitchen',
  'Bar',
  'Front Counter',
  'Back Storage',
  'Other',
];

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key, required this.onCreated});
  final Future<void> Function() onCreated;

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final repo = InventoryRepository();
  final name = TextEditingController();
  final code = TextEditingController();
  final customUnit = TextEditingController();
  final customPackUnit = TextEditingController();
  final unitsPerPack = TextEditingController();
  final minimum = TextEditingController();
  final target = TextEditingController();
  final notes = TextEditingController();
  final customCategory = TextEditingController();
  final customLocation = TextEditingController();
  final supplier = TextEditingController();
  final barcode = TextEditingController();
  final initialQuantity = TextEditingController();

  String inventoryType = 'General Inventory';
  String unit = 'pcs';
  String packUnit = 'pack';
  String category = 'Dry Goods';
  String location = 'Dry Storage';
  bool usePack = false;
  bool setInitialQuantity = false;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    customUnit.dispose();
    customPackUnit.dispose();
    unitsPerPack.dispose();
    minimum.dispose();
    target.dispose();
    notes.dispose();
    customCategory.dispose();
    customLocation.dispose();
    supplier.dispose();
    barcode.dispose();
    initialQuantity.dispose();
    super.dispose();
  }

  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> save() async {
    final baseUnit = unit == 'OTHER' ? customUnit.text.trim() : unit;
    final chosenPackUnit = !usePack ? null : (packUnit == 'OTHER' ? customPackUnit.text.trim() : packUnit);
    final packSize = usePack ? double.tryParse(unitsPerPack.text) : null;
    final minValue = minimum.text.trim().isEmpty ? null : double.tryParse(minimum.text);
    final targetValue = target.text.trim().isEmpty ? null : double.tryParse(target.text);
    final initial = !setInitialQuantity ? null : double.tryParse(initialQuantity.text);
    final chosenCategory = category == 'Other' ? customCategory.text.trim() : category;
    final chosenLocation = location == 'Other' ? customLocation.text.trim() : location;

    if (name.text.trim().isEmpty || baseUnit.isEmpty) {
      notify('Enter an item name and base unit.');
      return;
    }
    if (usePack && (chosenPackUnit == null || chosenPackUnit.isEmpty || packSize == null || packSize <= 0)) {
      notify('Complete the purchase-unit conversion.');
      return;
    }
    if ((minimum.text.trim().isNotEmpty && minValue == null) ||
        (target.text.trim().isNotEmpty && targetValue == null) ||
        (minValue != null && minValue < 0) ||
        (targetValue != null && targetValue < 0) ||
        (minValue != null && targetValue != null && targetValue < minValue)) {
      notify('Check the minimum and target stock levels.');
      return;
    }
    if (setInitialQuantity && (initial == null || initial < 0)) {
      notify('Enter a valid initial physical count.');
      return;
    }

    try {
      final matches = await repo.findActiveItemsByName(name.text.trim());
      if (matches.isNotEmpty && mounted) {
        final existing = matches.first;
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Possible duplicate item'),
            content: Text(
              "An active item named ${existing['name']} already exists as ${existing['code']}.\n\n"
              'Create another item only if it is a genuinely different product or size.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create anyway')),
            ],
          ),
        );
        if (continueAnyway != true) return;
      }
    } catch (_) {
      // Duplicate checking is a convenience. Server-side validation still protects the save.
    }

    setState(() => busy = true);
    try {
      final generatedCode = await repo.createItem(
        name: name.text.trim(),
        inventoryType: inventoryType,
        baseUnit: baseUnit,
        customCode: code.text.trim().isEmpty ? null : code.text.trim(),
        packUnit: chosenPackUnit,
        packSize: packSize,
        minimum: minValue,
        target: targetValue,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        category: chosenCategory.isEmpty ? null : chosenCategory,
        storageLocation: chosenLocation.isEmpty ? null : chosenLocation,
        supplierName: supplier.text.trim().isEmpty ? null : supplier.text.trim(),
        barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
        initialQuantity: initial,
      );
      await widget.onCreated();
      if (!mounted) return;
      notify('Item $generatedCode added to inventory.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) notify('Could not add item: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add inventory item')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 28 : 16, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: 'New inventory item',
                      subtitle: 'Add the item once, then every count and stock movement stays traceable.',
                    ),
                    const SizedBox(height: 18),
                    if (busy) ...[const LinearProgressIndicator(), const SizedBox(height: 14)],
                    _FormSection(
                      title: 'Item information',
                      subtitle: 'Use the real product name. The item ID can be generated automatically.',
                      child: Column(
                        children: [
                          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Item name *', prefixIcon: Icon(Icons.inventory_2_outlined))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: inventoryType,
                                  decoration: const InputDecoration(labelText: 'Inventory type'),
                                  items: const [
                                    DropdownMenuItem(value: 'General Inventory', child: Text('General Inventory')),
                                    DropdownMenuItem(value: 'Production Inventory', child: Text('Production Inventory')),
                                  ],
                                  onChanged: (value) => setState(() => inventoryType = value!),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: code,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(labelText: 'Custom item ID (optional)', hintText: 'Leave blank for automatic ID'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                            items: _categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                            onChanged: (value) => setState(() => category = value!),
                          ),
                          if (category == 'Other') ...[
                            const SizedBox(height: 12),
                            TextField(controller: customCategory, decoration: const InputDecoration(labelText: 'Custom category')),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Measurement & stock rules',
                      subtitle: 'Choose the unit you physically count. Add a pack conversion only when it is consistent for this product.',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(labelText: 'Base stock unit *', prefixIcon: Icon(Icons.straighten_rounded)),
                            items: _unitOptions.map((value) => DropdownMenuItem(value: value, child: Text(value == 'OTHER' ? 'Other / custom unit' : value))).toList(),
                            onChanged: (value) => setState(() => unit = value!),
                          ),
                          if (unit == 'OTHER') ...[
                            const SizedBox(height: 12),
                            TextField(controller: customUnit, decoration: const InputDecoration(labelText: 'Custom base unit', hintText: 'Example: tub, pouch, bundle')),
                          ],
                          const SizedBox(height: 6),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: usePack,
                            title: const Text('Add purchase / pack conversion', style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text('Example: 1 box = 24 bottles'),
                            onChanged: (value) => setState(() => usePack = value),
                          ),
                          if (usePack) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: packUnit,
                                    decoration: const InputDecoration(labelText: 'Purchase unit'),
                                    items: _unitOptions.map((value) => DropdownMenuItem(value: value, child: Text(value == 'OTHER' ? 'Other / custom unit' : value))).toList(),
                                    onChanged: (value) => setState(() => packUnit = value!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: unitsPerPack,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'Base $baseUnitLabel per purchase unit'),
                                  ),
                                ),
                              ],
                            ),
                            if (packUnit == 'OTHER') ...[
                              const SizedBox(height: 12),
                              TextField(controller: customPackUnit, decoration: const InputDecoration(labelText: 'Custom purchase unit')),
                            ],
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum stock'))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target stock'))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: setInitialQuantity,
                            title: const Text('Record a verified initial physical count', style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text('Leave this off when the quantity is not yet physically counted.'),
                            onChanged: (value) => setState(() => setInitialQuantity = value),
                          ),
                          if (setInitialQuantity)
                            TextField(
                              controller: initialQuantity,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Initial physical count ($baseUnitLabel)'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Operations details',
                      subtitle: 'These fields make stock checks, restocking and locating items faster for staff.',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: location,
                            decoration: const InputDecoration(labelText: 'Storage location', prefixIcon: Icon(Icons.location_on_outlined)),
                            items: _locations.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                            onChanged: (value) => setState(() => location = value!),
                          ),
                          if (location == 'Other') ...[
                            const SizedBox(height: 12),
                            TextField(controller: customLocation, decoration: const InputDecoration(labelText: 'Custom storage location')),
                          ],
                          const SizedBox(height: 12),
                          TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Preferred supplier (optional)', prefixIcon: Icon(Icons.local_shipping_outlined))),
                          const SizedBox(height: 12),
                          TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode / QR value (optional)', prefixIcon: Icon(Icons.qr_code_2_rounded))),
                          const SizedBox(height: 12),
                          TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: scheme.primaryContainer.withAlpha(100), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.verified_user_outlined, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 10),
                          Expanded(child: Text('The signed-in manager/admin is automatically recorded as the person who created this item.', style: TextStyle(color: scheme.onPrimaryContainer, height: 1.4))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 10),
                        FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String get baseUnitLabel => unit == 'OTHER' ? (customUnit.text.trim().isEmpty ? 'units' : customUnit.text.trim()) : unit;
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
