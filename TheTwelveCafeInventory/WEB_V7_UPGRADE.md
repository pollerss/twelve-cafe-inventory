# v7 Web / PWA Upgrade

No Supabase SQL migration is required when upgrading from a working v6 installation.

## Upgrade

1. Keep your working v6 project as a backup.
2. Open this v7 project folder in VS Code.
3. Do not rerun any existing database migration or the inventory import.
4. Run `flutter pub get` and `flutter analyze`.
5. Test locally using `tool/run_web.ps1`.
6. Build the production website using `tool/build_web.ps1`.
7. Deploy the contents of `build/web` to an HTTPS web host.

## v7 focus

This release changes distribution, not the live inventory database. It makes the existing system easier to access from any modern device through one URL and adds PWA/home-screen metadata and web deployment files.
