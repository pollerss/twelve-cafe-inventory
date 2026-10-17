# The Twelve Cafe Inventory v5 Upgrade

## Run this once in Supabase

For an existing working v4 installation, open `supabase/upgrade_v5.sql`, copy all of it into Supabase SQL Editor, and run it once.

Do **not** rerun `schema.sql`, `upgrade_v2.sql`, `upgrade_v3.sql`, or `import_inventory.py` if they were already applied to the live project.

## Then run the Flutter project

```powershell
flutter pub get
flutter analyze
```

If analysis succeeds:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

## First safe test

1. Sign in as manager/admin.
2. Inventory → **Add item**.
3. Create a temporary test item with quantity left blank.
4. Confirm it shows `UNRECORDED`.
5. Open the item → Archive item.
6. More → Archived inventory → Restore.
7. Check Activity for ITEM_CREATED / ITEM_ARCHIVED / ITEM_RESTORED.

This test does not require changing quantities on your real café items.
