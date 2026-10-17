# The Twelve Cafe Inventory v6 Upgrade

No Supabase migration is required when upgrading from a working v5 installation.

## Install

1. Keep v5 as a backup.
2. Open the v6 `TheTwelveCafeInventory` folder in VS Code.
3. Do not rerun `schema.sql`, `upgrade_v2.sql`, `upgrade_v3.sql`, `upgrade_v5.sql`, or the inventory import.
4. Run:

```powershell
flutter pub get
flutter analyze
```

5. Launch with the same Supabase URL and public anon/publishable key you already use.

## v6 highlights

- Removed the unnecessary Reason dropdown from the first physical count.
- First physical count is automatically audited as `First physical inventory` and the signed-in employee remains attached.
- Context-sensitive notes for expired/damaged/spoiled/lost/delivery/purchase transactions.
- Seven-day inventory freshness insight.
- Better Needs Setup detection.
- Search by barcode, storage location and supplier.
- Recently Updated sorting.
- Duplicate-name warning before creating an inventory item.

## Safe first test

Use a temporary item or an item whose count you can safely restore. Verify the initial-count dialog is now quantity + optional note only. Do not enter test quantities into live stock unless you plan to reverse them through an audited correction.
