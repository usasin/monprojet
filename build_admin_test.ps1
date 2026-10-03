$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$config = Get-Content "config\admin_test.json" -Raw | ConvertFrom-Json
if ($config.ADMIN_TEST_MODE -ne $true) {
    throw "ADMIN_TEST_MODE doit être true dans config/admin_test.json."
}

Write-Host "BUILD ADMIN TEST - NE PAS PUBLIER SUR LE PLAY STORE" -ForegroundColor Yellow
& "$PSScriptRoot\verifier_prospecto.ps1"
if ($LASTEXITCODE -ne 0) { throw "La vérification pré-build a échoué." }

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
    Write-Host "NOTE : cet APK garde le package Play Store. Google Play peut utiliser une signature différente ; dans ce cas Android refusera l'installation par-dessus l'app Play Store." -ForegroundColor Yellow
    Write-Host "Pour tester OWNER/MANAGER/REP côté serveur sans paiement, utilisez le compte autorisé prospectoDeveloper." -ForegroundColor Yellow
} else {
    throw "APK admin introuvable."
}
