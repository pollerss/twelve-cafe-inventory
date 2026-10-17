class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.quantity,
    this.unit,
    this.packUnit,
    this.unitsPerPack,
    this.notes,
    this.minimum,
    this.target,
    required this.version,
    this.updatedAt,
    this.category,
    this.storageLocation,
    this.supplierName,
    this.barcode,
    this.archived = false,
  });

  final String id, code, name, type;
  final double? quantity, minimum, target;
  final String? unit, packUnit, updatedAt, notes;
  final double? unitsPerPack;
  final int version;
  final String? category, storageLocation, supplierName, barcode;
  final bool archived;

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        type: j['inventory_type'] as String,
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: (j['stock_unit'] ?? j['unit']) as String?,
        packUnit: j['pack_unit'] as String?,
        unitsPerPack: (j['units_per_pack'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
        minimum: (j['min_stock'] as num?)?.toDouble(),
        target: (j['target_stock'] as num?)?.toDouble(),
        version: (j['version'] as num).toInt(),
        updatedAt: j['updated_at'] as String?,
        category: j['item_category'] as String?,
        storageLocation: j['storage_location'] as String?,
        supplierName: j['supplier_name'] as String?,
        barcode: j['barcode'] as String?,
        archived: (j['archived'] as bool?) ?? false,
      );

  String get status {
    if (quantity == null) return 'UNRECORDED';
    if (quantity == 0) return 'OUT OF STOCK';
    if (minimum == null) return 'THRESHOLD NOT SET';
    return quantity! <= minimum! ? 'LOW STOCK' : 'AVAILABLE';
  }

  String get stockText => quantity == null
      ? 'Unrecorded'
      : '${quantity!.toStringAsFixed(quantity! % 1 == 0 ? 0 : 2)} ${unit ?? 'units not set'}';

  bool get isStale {
    final parsed = DateTime.tryParse(updatedAt ?? '');
    if (parsed == null) return false;
    return DateTime.now().toUtc().difference(parsed.toUtc()).inDays >= 7;
  }

  String get setupSummary {
    final values = <String>[];
    if (category?.trim().isNotEmpty == true) values.add(category!.trim());
    if (storageLocation?.trim().isNotEmpty == true) values.add(storageLocation!.trim());
    return values.join(' • ');
  }
}
