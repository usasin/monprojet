param(
  [switch]$Production
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$expectedVersion = "1.6.0+51"
$expectedPackage = "com.ainego.ai_prospect_gps"
$expectedProject = (Get-Content "android\app\google-services.json" -Raw | ConvertFrom-Json).project_info.project_id
$expectedAdmobAppId = "ca-app-pub-1360261396564293~6577474458"

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

Write-Host "Prospecto - verification avant build" -ForegroundColor Cyan

$legacyMapsFile = "android\app\src\main\res\values\google_maps_api.xml"
if (Test-Path $legacyMapsFile) {
  Remove-Item $legacyMapsFile -Force
  Write-Host "Ancien fichier Maps local supprimé (la clé est injectée par Gradle)." -ForegroundColor DarkYellow
}

$pubspec = Get-Content "pubspec.yaml" -Raw
Assert-True ($pubspec -match "(?m)^version:\s*$([regex]::Escape($expectedVersion))\s*$") "Version attendue : $expectedVersion"

$gradle = Get-Content "android\app\build.gradle" -Raw
Assert-True ($gradle -match [regex]::Escape("applicationId = `"$expectedPackage`"")) "Package Android incorrect."
Assert-True ($gradle -match "targetSdk\s*=\s*36") "targetSdk 36 attendu."

$firebase = Get-Content ".firebaserc" -Raw | ConvertFrom-Json
Assert-True ($firebase.projects.default -eq $expectedProject) "Projet Firebase incorrect : attendu $expectedProject."

$prod = Get-Content "config\prod.json" -Raw | ConvertFrom-Json
Assert-True ($prod.ADMOB_PRODUCTION_ENABLED -eq $true) "ADMOB_PRODUCTION_ENABLED doit être true en production."
Assert-True ($prod.ADMIN_TEST_MODE -ne $true) "SECURITE : ADMIN_TEST_MODE doit être false en production."

$admin = Get-Content "config\admin_test.json" -Raw | ConvertFrom-Json
Assert-True ($admin.ADMIN_TEST_MODE -eq $true) "Le profil admin de test doit garder ADMIN_TEST_MODE=true."

$gradleProps = Get-Content "android\gradle.properties" -Raw
$hasProdAdmob = $gradleProps -match [regex]::Escape("PROSPECTO_ADMOB_APP_ID=$expectedAdmobAppId")
Assert-True $hasProdAdmob "ID application AdMob Prospecto manquant ou incorrect."

$mapsProperty = [regex]::Match($gradleProps, '(?m)^PROSPECTO_MAPS_ANDROID_KEY=(.+)$')
$mapsKey = if ($env:PROSPECTO_MAPS_ANDROID_KEY) { $env:PROSPECTO_MAPS_ANDROID_KEY.Trim() } elseif ($mapsProperty.Success) { $mapsProperty.Groups[1].Value.Trim() } else { "" }
Assert-True (-not [string]::IsNullOrWhiteSpace($mapsKey)) "Clé Google Maps manquante. Définissez PROSPECTO_MAPS_ANDROID_KEY."

if ($Production) {
  $keyPropsPath = "android\key.properties"
  Assert-True (Test-Path $keyPropsPath) "android/key.properties est requis pour signer la version Play Store."
  $keyProps = Get-Content $keyPropsPath -Raw
  $storeMatch = [regex]::Match($keyProps, '(?m)^storeFile=(.+)$')
  Assert-True $storeMatch.Success "storeFile manque dans android/key.properties."
  $storeFile = $storeMatch.Groups[1].Value.Trim()
  $storePath = Join-Path "android\app" $storeFile
  Assert-True (Test-Path $storePath) "Keystore de signature introuvable à l'emplacement configuré."
}

Write-Host "Configuration : OK" -ForegroundColor Green
Write-Host "flutter pub get..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get a échoué." }

Write-Host "flutter analyze..." -ForegroundColor Cyan
flutter analyze --no-fatal-warnings --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw "flutter analyze a détecté une erreur bloquante." }

Write-Host "flutter test..." -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { throw "Au moins un test Flutter a échoué." }

Write-Host "`nVERIFICATION PROSPECTO OK - $expectedVersion" -ForegroundColor Green
