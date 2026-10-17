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

Write-Host "Getting packages..."
flutter pub get

Write-Host "Analyzing project..."
flutter analyze

Write-Host "Building production website..."
flutter build web --release `
  --dart-define="SUPABASE_URL=$SupabaseUrl" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublicKey"

Write-Host ""
Write-Host "Website ready in: build\web"
Write-Host "Upload the CONTENTS of build\web to your web host."
