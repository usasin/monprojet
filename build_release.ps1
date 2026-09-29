$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$gradleProperties = Get-Content "android\gradle.properties" -Raw
$productionConfig = Get-Content "config\prod.json" -Raw | ConvertFrom-Json
$expectedAdmobAppId = 'ca-app-pub-1360261396564293~6577474458'
$hasExpectedAdmobAppId = $gradleProperties -match [regex]::Escape("PROSPECTO_ADMOB_APP_ID=$expectedAdmobAppId")
if ($productionConfig.ADMOB_PRODUCTION_ENABLED -ne $true) {
    throw "ADMOB_PRODUCTION_ENABLED doit être true pour un build Play Store."
}
if ($productionConfig.ADMIN_TEST_MODE -eq $true) {
    throw "SECURITE : ADMIN_TEST_MODE doit être false pour un build Play Store."
}
if (-not $hasExpectedAdmobAppId) {
    throw "ID d'application AdMob incorrect pour Prospecto. Attendu : $expectedAdmobAppId"
}

Write-Host "Nettoyage de Prospecto..." -ForegroundColor Cyan
flutter clean
Remove-Item ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Téléchargement des dépendances..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get a échoué." }

Write-Host "Création de l'AAB signé..." -ForegroundColor Cyan
flutter build appbundle --release --dart-define-from-file=config/prod.json
if ($LASTEXITCODE -ne 0) { throw "La création de l'AAB a échoué." }

$aab = Join-Path $PSScriptRoot "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aab) {
    Write-Host "`nAAB créé avec succès :" -ForegroundColor Green
    Write-Host $aab -ForegroundColor Green
} else {
    throw "Le build s'est terminé, mais l'AAB est introuvable."
}
