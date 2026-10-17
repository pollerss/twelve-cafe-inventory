param(
  [Parameter(Mandatory=$true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory=$true)]
  [string]$SupabasePublicKey
)

$ErrorActionPreference = "Stop"

if ($SupabasePublicKey -match "service_role|sb_secret") {
  throw "Do not use a Supabase service-role/secret key in the website. Use only the public publishable/anon key."
}

flutter pub get
flutter run -d chrome `
  --dart-define="SUPABASE_URL=$SupabaseUrl" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublicKey"
