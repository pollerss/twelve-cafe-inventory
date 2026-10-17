# v8 Branded Dashboard UI Upgrade

No database migration is required from a working v7/v6 installation.

## What changed

The web app now uses the supplied Twelve Cafe logo and a dashboard structure inspired by the approved admin-dashboard reference while removing ecommerce-only sections that do not belong in a café inventory system.

Useful sections included:

- Dashboard
- Inventory
- Categories
- Units
- Restock
- Activity
- Employees
- Reports
- Settings

Dashboard data is derived from live Supabase inventory, transactions and restock requests. The design does not fabricate profit, sales, marketplace traffic, delivery dates or expiry information that the current database cannot support.

## Update the existing website

1. Keep the current source/deployment as a backup.
2. Open this project folder and run:

```powershell
flutter pub get
flutter analyze
```

3. Test locally with your existing Supabase public key.
4. Build:

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

5. Redeploy the resulting `build/web` folder to the **same** Netlify project.

Do not rerun inventory import or SQL migrations for this UI-only release.
