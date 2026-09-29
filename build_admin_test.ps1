$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$config = Get-Content "config\admin_test.json" -Raw | ConvertFrom-Json
if ($config.ADMIN_TEST_MODE -ne $true) {
    throw "ADMIN_TEST_MODE doit être true dans config/admin_test.json."
}

Write-Host "BUILD ADMIN TEST - NE PAS PUBLIER SUR LE PLAY STORE" -ForegroundColor Yellow
flutter clean
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get a échoué." }

flutter build apk --release --dart-define-from-file=config/admin_test.json
if ($LASTEXITCODE -ne 0) { throw "Le build APK admin a échoué." }

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    Write-Host "`nAPK ADMIN TEST créé :" -ForegroundColor Green
    Write-Host $apk -ForegroundColor Green
    Write-Host "Premium local actif + pubs désactivées + console développeur visible." -ForegroundColor Green
    Write-Host "Les actions entreprise sensibles restent protégées côté serveur." -ForegroundColor Yellow
} else {
    throw "APK admin introuvable."
}
