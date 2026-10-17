# THE TWELVE CAFE INVENTORY

An initial Flutter + Supabase implementation grounded in the uploaded café workbook. **This is a source-code development build, not a production-tested mobile app.** No APK or IPA has been built here because the Flutter SDK, simulator and signing credentials are unavailable.

## Source inventory audit

- Worksheet `INVENTORY (2)`: 89 General Inventory entries.
- Worksheet `Sheet1`: 48 Production Inventory entries.
- 137 spreadsheet entries total, all with NULL quantities and unspecified units/stock thresholds.
- General Inventory contains `GROUND PORK` twice. Both records are kept separate as source entries so a manager can resolve the duplication.
- All names, including source typos like `OYSTER SAUCCE`, are intentionally preserved.
- No stock, delivery, beginning, ending or production figures were populated in the source cells; values are **UNRECORDED**, not zero.
- The original Excel workbook was read without modification. The extracted entries live in `data/initial_inventory.json` and `.csv`.

## Start the backend

1. Create a Supabase project. Execute `supabase/schema.sql` in SQL Editor.
2. Configure email/password authentication in Supabase Auth. Create users there; profiles are created with the `staff` role by trigger.
3. To grant a trusted user manager/admin access, execute this from Supabase SQL Editor after creating their Auth user:
   `update public.profiles set role='admin' where id=(select id from auth.users where email='owner@example.com');`
4. Import source records from a trusted computer, **never in the mobile app**:

   ```bash
   export SUPABASE_URL='https://YOUR_PROJECT.supabase.co'
   export SUPABASE_SERVICE_ROLE_KEY='SERVER_ONLY_SECRET'
   python3 tool/import_inventory.py
   ```

5. Enable Supabase database backups, configure retention, set up monitoring and test restoration before accepting real inventory data.

## Start Flutter

Requires Flutter 3.24+ and Dart 3.5+, Android Studio for Android and a Mac with Xcode for iPhone/iPad. From this project directory:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

For Android testing: `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
For Google Play: `flutter build appbundle --release` with the same environment defines; configure signing/keystore according to Flutter documentation.
For iOS/iPadOS, use a Mac with Xcode, a valid Apple Developer account, bundle ID, provisioning/signing and App Store Connect; `flutter build ipa --release` with the same defines after configuring signing. This environment cannot produce an IPA.

**Do not put the Supabase service role key in app code or --dart-define.** Only the public/publishable key belongs in the Flutter app.

## Implemented in this starter

- Responsive phone navigation and tablet navigation rail.
- Supabase email/password sign-in, basic server-enforced staff/manager permissions.
- Workbook-derived General and Production inventories, live reads, name/category/code search, status filters.
- Dashboard counts respecting NULL unknown quantities.
- Item detail, manager/admin initial physical count, stock in/out RPCs with confirmation and transaction log.
- Optimistic version check and atomic database transactions for stock movements; no negative stock out.
- Restock requests, authorized partial/full receipt, activity history.
- Basic error and loading states, adaptive light/dark themes.

## Known limitations / must complete before production

This is a functioning *foundation* requiring a real Supabase project to run. It is **not a complete fulfillment** of every feature in the uploaded development specification. Missing or incomplete: daily-count sessions, approval workflow, add/edit/archive UI, unit and threshold edit UI, barcode scanning, favorites, push notifications, CSV/PDF export, robust analytics, supplier records, expiry batches, configurable settings, automated backup verification, production logging, robust offline caching, comprehensive pagination and end-to-end testing. Restock status transitions to ORDERED and CANCELLED require future secure RPCs. No inventory import has been sent to a live backend because no project credentials were provided.

Security review needed before launch: limit profile visibility to required details, keep direct inventory item UPDATE disabled (the current RLS policy does this) and implement a dedicated protected RPC for item metadata edits. Do not use the current schema with valuable real-world data until that loophole is closed. Add idempotency keys for retries and double taps, concurrency stress tests, email verification and permission tests.

## QA status

Excel sheet audit and extracted counts: completed. Flutter compilation, Android/iOS builds, login, RLS behavioral tests, multi-device synchronization, network-drop testing and physical-device layouts: **not executed in this environment**. Run `flutter analyze`, `flutter test` and device tests after installing the SDK.

## Upgrade an EXISTING live Twelve Cafe project to v2 (October 2026)

**IMPORTANT: Do not rerun `schema.sql`, do not rerun `import_inventory.py`, and do not replace your existing Supabase project.** Back up your database before upgrading. The migration in `supabase/upgrade_v2.sql` only adds columns and secure RPCs; it does not reset your 137 items, quantity values, profiles, or transaction history. Execute it once in Supabase SQL Editor with an authorized project administrator.

After the SQL succeeds, replace the local Flutter project source with these updated files and restart your old `flutter run` session. From the project folder:

```powershell
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

**New functions:** Managers/admins can edit item names, unit of measure, optional alternate packaging with explicit conversion (e.g. 1 pack = 12 pcs), minimum and target levels, and notes. Anyone signed in can submit a manual restock request even when quantity is UNRECORDED. Stock movement forms store structured reason codes: expired, damaged, spoiled, spilled, lost, waste, used, sold and others, plus notes. Each movement's actor is **taken from Supabase auth.uid() server-side**, not a freeform staff name. Activity reads employee names from profiles, falling back to the actor ID when display names are blank. Managers can mark restock requests ordered, record partial/full receipts, or cancel unreceived requests.

**Unit conversion rules:** Current stock, minimum and target quantities are always stored in one **base unit** per item. Stock entries can use that base unit or a configured purchasing unit, with a manager-specified conversion. Do **not** reinterpret a recorded base quantity by renaming its unit; the database blocks changing an established base unit for stock already recorded. Stock measured in kg versus packs requires a verified fixed conversion for that exact product. If each pack has different net weight, record the actual weight in the base unit rather than claiming all packs are identical. The app does not automatically convert unrelated dimensions such as kilograms to liters.

**Expiry behavior:** A stock-out can be marked EXPIRED with a note. This records waste immediately but is **not yet** batch-level expiry-date tracking or an automated expiry alert. Detailed batch/lot and expiry notification features remain future work.

**Safety / limitations:** Run this in a staging project before a live deployment. Flutter compilation and end-to-end tests were not executed in this environment. Existing item initial-count RPC remains as implemented. The UI currently does not support unit changes once a stock count is recorded, unless you perform a separate validated migration. Review and tighten profile read access (currently available to authenticated users), backend policies and grants, and implement idempotency keys before using with high-value production stock. No fake quantities were introduced.


## v3 selectable reasons (October 2026)

Before opening this version, run `supabase/upgrade_v3.sql` once in the Supabase SQL Editor after `upgrade_v2.sql` (already applied in an existing v2 installation). **Do not** rerun the inventory seed script or initial schema.

Stock In and Stock Out use predefined reason dropdowns. Initial counts now also use a dropdown (First physical inventory, Verified physical recount, Spreadsheet verification, Other). Item-page and Restock-page restock requests both use selectable reasons (Low stock, Out of stock, Upcoming demand, Routine replenishment, Replacement, Other). Other requires an explanation. For all other options, notes are optional. The signed-in account still supplies the actor on stock movements; selecting a reason does not let someone impersonate another employee.

The restock reason is saved in `restock_requests.reason_code`. Existing historical requests remain with NULL reason codes. Automatic expiry tracking and full adjustment workflows are not implemented by this change.

## v4 visual redesign (October 2026)

v4 is a **UI/UX-focused update** built on top of v3. It does not require another Supabase migration and does not reset or re-import inventory. Keep the existing live Supabase project where `schema.sql`, `upgrade_v2.sql`, and `upgrade_v3.sql` have already been applied.

### What changed visually

- Reworked warm café theme with cream, espresso and caramel accents, clearer typography and softer surfaces.
- Redesigned sign-in screen with a responsive café-branded desktop/tablet layout.
- Cleaner dashboard metric cards, quick actions and a more readable Needs Attention list.
- Improved phone inventory cards plus a table-style inventory view on wider tablet/desktop layouts.
- Better search, category/status filters and sorting controls.
- Redesigned item detail screen with a stock summary, status badge, responsive information grid and separate action panel.
- Cleaner item editing with selectable common units plus an **Other / custom unit** option.
- Redesigned Stock In, Stock Out, initial count and confirmation dialogs with reason selection and responsible employee notice.
- Redesigned Restock screen with request progress, clearer status treatment and polished empty states.
- Activity history is now formatted as readable audit cards with employee, timestamp, reason and entered measurement.
- Improved responsive navigation rail on larger displays and bottom navigation on phones.
- Light and dark themes use the same café visual language.

### Upgrade from working v3

1. Back up your working v3 source folder. Your Supabase data does not need to be moved.
2. Extract v4 and open the inner `TheTwelveCafeInventory` folder in VS Code.
3. **Do not rerun** `schema.sql`, `upgrade_v2.sql`, `upgrade_v3.sql`, or `import_inventory.py` if your current live project is already working.
4. Run:

```powershell
flutter pub get
flutter analyze
```

5. Launch with either a modern Supabase publishable key:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

or your existing public anon key command remains supported:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Never put the `service_role` secret in Flutter.

### v4 QA note

The source package was assembled and archive-checked in this environment, but Flutter is not installed here, so `flutter analyze`, browser compilation and device tests could not be executed here. Run `flutter analyze` locally before replacing your current working v3 session. If your local Flutter SDK reports an API/version warning, keep your working v3 folder until the issue is corrected.

## v5 business workflow update (October 2026)

v5 builds on the working v4 UI and adds day-to-day inventory administration features that are useful for a real café. **Existing 137 inventory records and their transaction history are preserved.**

### Before opening v5

On your existing Supabase project, run `supabase/upgrade_v5.sql` **once** after the earlier v2/v3 migrations. Do not rerun `schema.sql` and do not rerun the original inventory import.

The v5 migration adds metadata columns and secure role-checked RPCs. It does not reset quantities.

### New v5 features

- **Add Item** for managers/admins from Home or Inventory.
  - Automatic next item ID such as `TC-0138`, or an optional custom unique ID.
  - General or Production Inventory selection.
  - Base measurement unit plus optional purchase/pack conversion.
  - Minimum and target stock.
  - Optional verified initial physical count; leaving it blank keeps the item `UNRECORDED`.
  - Category, storage location, preferred supplier, barcode/QR value and notes.
  - Item creation and optional initial count are written to the audit trail with the signed-in employee.
- **Physical Count Adjustment** for manager/admin corrections.
  - Records the previous quantity, verified physical quantity, difference, reason, employee and timestamp.
  - Does not silently overwrite inventory.
- **Archive / Restore Items** instead of deletion.
  - Archived items disappear from active inventory but retain complete transaction history.
  - Managers/admins can restore them from More → Archived inventory.
  - Items with open restock requests must have those requests completed/cancelled before archiving.
- **Employee Display Name** setting.
  - Each signed-in employee can set a readable display name under More.
  - Activity continues to use server-side `auth.uid()` for accountability; the display name is only the readable label.
- **Richer item information**: category, storage location, supplier and barcode/QR value appear on the item detail page and are included in inventory search.
- **Suggested Restock** is shown when both current stock and target stock are known.
- **Needs Setup** is included on the dashboard for recorded items that still do not have a minimum threshold.
- **Safer item writes**: direct authenticated inserts/updates/deletes to `inventory_items` are revoked by the v5 migration; item creation/editing/archiving use audited server-side functions instead.

### Upgrade from v4

1. Keep your current v4 folder as a backup.
2. In Supabase SQL Editor, copy the contents of `supabase/upgrade_v5.sql` and run it once.
3. Extract/open the v5 `TheTwelveCafeInventory` project folder.
4. Run:

```powershell
flutter pub get
flutter analyze
```

5. If analysis is clean, launch using the same live Supabase project:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

or use `SUPABASE_PUBLISHABLE_KEY` with a current Supabase publishable key.

### Recommended first v5 test

Create one temporary item as a manager with **no initial quantity** and confirm it appears as `UNRECORDED`. Then archive that test item and restore it from More → Archived inventory. This checks item creation, audit logging, archive/restore and permissions without changing the quantities of your real café items.

### Still recommended for later releases

Full daily-count sessions with save/resume, batch/lot expiry dates and expiry alerts, barcode-camera scanning, PDF/CSV reports, supplier directory with contact details, push notifications, offline cache/sync, user-management UI, favorites, and production-specific recipes/ingredient consumption remain larger follow-up features.

### v5 QA note

The source was assembled and checked structurally in this environment, but Flutter is not installed here, so local `flutter analyze`, browser compilation and device testing must still be run on your computer before replacing the working version in café operations.

## v6 workflow simplification & business safeguards (October 2026)

v6 is a **Flutter-only update** on top of v5. It does not change the Supabase schema, so an existing working v5 database needs **no new SQL migration** and no inventory re-import.

### What changed

- **Initial physical count is now simpler.** Staff/managers enter the physical quantity and an optional note. The redundant Reason dropdown was removed. The backend still records the audit reason as `First physical inventory` automatically and attaches the signed-in employee.
- Stock In / Stock Out keep reason selection because those transactions can genuinely happen for different business reasons.
- Stock-movement note prompts now adapt to the selected reason. Expired, damaged, spoiled, spilled, lost, supplier delivery and purchase entries show more useful prompts for the information staff may want to record.
- **Data freshness insight** appears on Home when active inventory records have not been updated in 7 days.
- **Needs Setup** now detects missing base units, minimum stock, or target stock even when an item is still UNRECORDED. Attention lists avoid duplicate entries.
- Inventory search explicitly supports item name, ID, barcode, storage location and supplier.
- Added **Recently Updated** as an inventory sort option.
- **Duplicate-name safeguard when adding items.** If an active item with the same name already exists, the app warns the manager/admin before creating another record. Legitimately different sizes/variants can still be created after confirmation.

### Upgrade from v5

1. Keep the working v5 folder as a backup.
2. Extract/open the v6 `TheTwelveCafeInventory` folder.
3. Do **not** rerun any SQL migration or `import_inventory.py` if v5 is already working.
4. Run:

```powershell
flutter pub get
flutter analyze
```

5. Launch using the same Supabase project and public key as v5.

### Recommended v6 checks

- Open an UNRECORDED item and select **Record initial count**. Confirm there is no Reason dropdown and that the confirmation still shows the responsible employee.
- Start Stock Out and switch between Expired, Damaged and Used to verify the optional-note prompt changes appropriately.
- Inventory → Add item → enter the exact name of an existing active item and verify the duplicate warning appears.
- Check Inventory sorting for **Recently Updated**.

### QA note

This source package was edited and structurally checked in the build environment, but Flutter is not installed here. Run `flutter analyze` and a browser/device test locally before replacing the working café build.

## v7 website / PWA distribution (October 2026)

The recommended distribution for The Twelve Cafe is now a responsive website/PWA rather than separate Android and iOS installations. This keeps one shared Supabase database while letting Windows, Mac, Android, iPhone and iPad users open the same HTTPS URL.

No new Supabase migration is required when moving from a working v6 database. See `WEBSITE_SETUP.md` and `WEB_V7_UPGRADE.md`.

Build on Windows with `tool/build_web.ps1`. The finished static website is created under `build/web`. The website includes PWA metadata, home-screen icons, static-host SPA redirects, no-index guidance for search engines and an internal quick-access guide in More.

The included PWA icon is a temporary neutral placeholder, not an official café logo.

## v8 branded dashboard UI (October 2026)

v8 redesigns the web/PWA around the approved Twelve Cafe dashboard direction and the supplied official café logo. **No new Supabase migration is required** when upgrading from a working v7/v6 database.

### New web UI

- Dark espresso branded sidebar with the official Twelve Cafe logo.
- Desktop top bar with global inventory search, refresh, attention notifications and the signed-in employee profile.
- Dashboard cards for Total Items, Recorded, Low Stock, Out of Stock and Unrecorded.
- Stock-by-category visual using actual inventory categories; items without a category fall back to General/Production Inventory.
- Weekly Inventory Movement visualization counts Stock In and Stock Out transaction events. It intentionally does not add kg, liters, pieces and packs into a misleading combined quantity.
- Upcoming Restock uses live restock requests and shows requested/received/status information. No fake expected-delivery date is invented because the current database has no expected-date field.
- Needs Attention uses Low Stock, Out of Stock, Unrecorded and Needs Setup. Expiry widgets are not shown until true batch/expiry-date tracking is implemented.
- Recent Activity shows real inventory audit records and employee display names.
- Quick Actions for Add Item, Record Count, Stock In, Stock Out and Restock.
- Added useful web views for Categories, Units, Employees and Reports. These use existing live inventory/profile/audit data and do not add unrelated ecommerce features.
- Mobile/tablet layouts keep Dashboard, Inventory, Restock, Activity and More readily accessible, with full navigation in the drawer.
- The supplied official logo is used on sign-in, desktop navigation, PWA icons and the web loading screen.

### Upgrade from v7

1. Keep the currently deployed v7 folder as a backup.
2. Replace the local Flutter source with v8.
3. Do **not** rerun `schema.sql`, any upgrade SQL, or `import_inventory.py` if your current database is already working.
4. Run `flutter pub get` and `flutter analyze` locally.
5. Test the website locally, then rebuild with `flutter build web --release` using the same Supabase URL and public/publishable key.
6. Upload the new `build/web` output to the same Netlify site to update the existing website without changing Supabase data.

The v8 source was assembled in an environment without the Flutter SDK. Run local analysis and browser testing before replacing the live deployment.
