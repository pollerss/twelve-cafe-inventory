import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class InventoryRepository {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<InventoryItem>> fetch() async {
    final rows = await client.from('inventory_items').select().eq('archived', false).order('name');
    return (rows as List).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<InventoryItem>> fetchArchived() async {
    final rows = await client.from('inventory_items').select().eq('archived', true).order('name');
    return (rows as List).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> myRole() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return 'staff';
    final r = await client.from('profiles').select('role').eq('id', uid).maybeSingle();
    return (r?['role'] as String?) ?? 'staff';
  }

  Future<List<Map<String, dynamic>>> profiles() async {
    final rows = await client.from('profiles').select('id,display_name,role').order('display_name');
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> myProfile() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return {'role': 'staff', 'display_name': ''};
    final row = await client.from('profiles').select('role,display_name').eq('id', uid).maybeSingle();
    return Map<String, dynamic>.from(row ?? {'role': 'staff', 'display_name': ''});
  }

  Future<void> updateMyDisplayName(String name) async {
    await client.rpc('update_my_profile_v5', params: {'p_display_name': name});
  }

  Future<List<Map<String, dynamic>>> findActiveItemsByName(String name) async {
    final rows = await client
        .from('inventory_items')
        .select('id,code,name')
        .eq('archived', false)
        .ilike('name', name.trim());
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> createItem({
    required String name,
    required String inventoryType,
    required String baseUnit,
    String? customCode,
    String? packUnit,
    double? packSize,
    double? minimum,
    double? target,
    String? notes,
    String? category,
    String? storageLocation,
    String? supplierName,
    String? barcode,
    double? initialQuantity,
  }) async {
    final result = await client.rpc('add_inventory_item_v5', params: {
      'p_name': name,
      'p_inventory_type': inventoryType,
      'p_stock_unit': baseUnit,
      'p_code': customCode,
      'p_pack_unit': packUnit,
      'p_units_per_pack': packSize,
      'p_min': minimum,
      'p_target': target,
      'p_notes': notes,
      'p_category': category,
      'p_storage_location': storageLocation,
      'p_supplier_name': supplierName,
      'p_barcode': barcode,
      'p_initial_qty': initialQuantity,
    });
    return result.toString();
  }

  Future<void> move({required InventoryItem item, required String kind, required double amount, required String reason}) async {
    await client.rpc('apply_inventory_movement', params: {
      'p_item_id': item.id,
      'p_kind': kind,
      'p_amount': amount,
      'p_expected_version': item.version,
      'p_reason': reason,
    });
  }

  Future<void> editItem({
    required InventoryItem item,
    required String name,
    required String baseUnit,
    String? packUnit,
    double? packSize,
    double? minimum,
    double? target,
    String? notes,
    String? category,
    String? storageLocation,
    String? supplierName,
    String? barcode,
  }) async =>
      client.rpc('edit_inventory_item_v5', params: {
        'p_item_id': item.id,
        'p_expected_version': item.version,
        'p_name': name,
        'p_stock_unit': baseUnit,
        'p_pack_unit': packUnit,
        'p_units_per_pack': packSize,
        'p_min': minimum,
        'p_target': target,
        'p_notes': notes,
        'p_category': category,
        'p_storage_location': storageLocation,
        'p_supplier_name': supplierName,
        'p_barcode': barcode,
      });

  Future<void> stockV2({
    required InventoryItem item,
    required String direction,
    required double amount,
    required String unit,
    required String reason,
    required String detail,
  }) async =>
      client.rpc('move_stock_v2', params: {
        'p_item_id': item.id,
        'p_expected_version': item.version,
        'p_direction': direction,
        'p_amount': amount,
        'p_entry_unit': unit,
        'p_reason_code': reason,
        'p_detail': detail,
      });

  Future<void> adjustPhysicalCount({
    required InventoryItem item,
    required double physicalCount,
    required String reason,
    required String detail,
  }) async =>
      client.rpc('adjust_inventory_count_v5', params: {
        'p_item_id': item.id,
        'p_expected_version': item.version,
        'p_physical_count': physicalCount,
        'p_reason_code': reason,
        'p_detail': detail,
      });

  Future<void> archiveItem(InventoryItem item, String reason) async =>
      client.rpc('archive_inventory_item_v5', params: {
        'p_item_id': item.id,
        'p_expected_version': item.version,
        'p_reason': reason,
      });

  Future<void> restoreItem(InventoryItem item) async =>
      client.rpc('restore_inventory_item_v5', params: {'p_item_id': item.id});

  Future<void> setRestockStatus(String id, String status) async =>
      client.rpc('set_restock_status_v2', params: {'p_request_id': id, 'p_status': status});


  Future<void> requestRestock(InventoryItem item, double amount, {required String reason, String details = ''}) async =>
      client.from('restock_requests').insert({
        'item_id': item.id,
        'requested_qty': amount,
        'requested_by': client.auth.currentUser!.id,
        'reason_code': reason,
        'notes': details.isEmpty ? null : details,
      });

  Future<List<Map<String, dynamic>>> activity() async {
    final rows = (await client
            .from('inventory_transactions')
            .select('id,kind,delta,before_qty,after_qty,created_at,reason,reason_code,detail,entered_unit,entered_quantity,actor,inventory_items(name)')
            .order('created_at', ascending: false)
            .limit(100) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final users = (await client.from('profiles').select('id,display_name') as List);
    final names = <String, String>{for (final p in users) (p['id'] as String): (p['display_name'] as String? ?? '')};
    for (final row in rows) {
      row['employee_name'] = names[row['actor']]?.trim().isNotEmpty == true ? names[row['actor']] : row['actor'];
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> restocks() async =>
      (await client
              .from('restock_requests')
              .select('id,item_id,requested_qty,received_qty,status,created_at,reason_code,notes,inventory_items(name),requested_by')
              .order('created_at', ascending: false) as List)
          .cast<Map<String, dynamic>>();

  Future<void> receive(String id, double quantity) async =>
      client.rpc('receive_restock', params: {'p_request_id': id, 'p_amount': quantity});
}
