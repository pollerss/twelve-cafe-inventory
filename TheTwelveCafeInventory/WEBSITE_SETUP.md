# The Twelve Cafe Inventory — Website / PWA Setup

This edition is optimized to be used from one web address on Windows, Mac, Android, iPhone and iPad. It uses the same live Supabase project and does **not** require a new inventory import or database migration when upgrading from a working v6 installation.

## What is different

- Responsive web-first shell with a maximum desktop content width so wide monitors remain easy to scan.
- Progressive Web App metadata for Add to Home Screen / Install App behavior.
- iPhone/iPad home-screen metadata using the supplied Twelve Cafe logo.
- Android/desktop install metadata.
- Search-engine indexing is discouraged through `robots.txt` because this is an internal business system.
- SPA routing fallback files for static hosts such as Netlify.
- Safer default web response headers for supported static hosts.
- The More page explains how staff can add the website to their device home screen.
- A Windows PowerShell build script is included at `tool/build_web.ps1`.

## Important: your database stays the same

If v6 is already working with your existing Supabase project:

- Do not rerun `schema.sql`.
- Do not rerun `upgrade_v2.sql`, `upgrade_v3.sql`, or `upgrade_v5.sql`.
- Do not rerun the spreadsheet import.
- Do not use the Supabase service-role key in this website.

Only a public Supabase publishable/anon key belongs in the browser build. Database security must continue to be enforced by Supabase authentication, RLS, grants and protected RPCs.

## Test locally on Windows

From the project folder:

```powershell
flutter pub get
flutter analyze
.\tool\run_web.ps1 `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabasePublicKey "YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY"
```

This opens the website in Chrome through Flutter's development server.

## Build the production website

```powershell
.\tool\build_web.ps1 `
  -SupabaseUrl "https://YOUR_PROJECT.supabase.co" `
  -SupabasePublicKey "YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY"
```

The production files will be written to:

```text
build\web
```

Upload the **contents** of `build\web` to your web host.

## Easiest first deployment: Netlify drag-and-drop

1. Build the production website using the command above.
2. Sign in to Netlify.
3. Create a manual/drag-and-drop site deployment.
4. Drag the `build\web` folder contents into the deployment area.
5. Netlify will provide an HTTPS address.
6. Open the address from a computer and a phone and sign in with a test account.
7. After testing, connect a custom domain such as `inventory.thetwelvecafe.com` if you own the domain.

The included `web/_redirects` file makes Flutter's single-page website route back to `index.html` on static hosting that supports Netlify-style redirects.

## Supabase settings after you have a real website URL

In Supabase Authentication URL settings, set the Site URL to your final HTTPS website address. If you later add password-recovery links, email confirmation links or OAuth, also allow the exact production redirect URLs required by those flows.

Your normal email/password login does not require a new database.

## Add to Home Screen

### iPhone / iPad

1. Open the HTTPS website in Safari.
2. Tap Share.
3. Tap **Add to Home Screen**.
4. Staff can then open The Twelve Cafe Inventory from its home-screen icon.

### Android

1. Open the HTTPS website in Chrome.
2. Open the browser menu.
3. Choose **Install app** or **Add to Home screen** when available.

### Windows / macOS

Chrome or Edge may show an Install icon in the address bar or an Install App option in the browser menu.

## Offline behavior

Inventory correctness is more important than pretending an offline write succeeded. Treat the website as online-first. If the network is unavailable, staff should not assume a Stock In/Out action was saved unless the server confirms it. A later release can add a deliberate read-only cache or carefully designed synchronization queue.

## Brand icon note

The supplied official Twelve Cafe logo is now used for the website/PWA icons and favicon in v8.

## Before café rollout

Test at minimum:

- admin, manager and staff permissions
- Add Item
- initial physical count
- Stock In / Stock Out
- expired / damaged / spoiled reasons
- physical-count adjustment
- restock request, ordered and partial/full receive
- archive and restore
- Activity employee attribution
- desktop, iPhone/iPad Safari, Android Chrome and tablet layouts
- sign out / sign in
- temporary network loss
- duplicate clicks and stale-record conflict handling

Keep a backup/export strategy for Supabase before using the system as the café's authoritative inventory record.
