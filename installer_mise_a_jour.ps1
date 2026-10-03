param([string]$Destination = "C:\dev\prospecto")
$ErrorActionPreference = "Stop"
$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$targetRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if ($sourceRoot -eq $targetRoot) { throw "Extrayez le ZIP dans un autre dossier, puis lancez ce script vers votre projet existant." }
if (-not (Test-Path (Join-Path $targetRoot 'pubspec.yaml'))) { throw "Projet existant introuvable : $targetRoot" }
$backup = $targetRoot + '_sauvegarde_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Path $backup | Out-Null
$preserved = @('.firebaserc', 'android/google-services.json', 'android/app/google-services.json', 'android/gradle.properties', 'android/local.properties', 'android/key.properties', 'ios/Runner/GoogleService-Info.plist', 'ios/Flutter/AdMob.local.xcconfig', 'config/prod.json', 'config/admin_test.json', 'config/stripe_enterprise.json')
$files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force | Where-Object { $_.FullName -notmatch '[\\/](\.git|\.dart_tool|\.tooling|\.verification|node_modules|build)[\\/]' }
foreach ($file in $files) {
    $relative = $file.FullName.Substring($sourceRoot.Length + 1)
    $normalized = $relative.Replace('\', '/')
    $target = Join-Path $targetRoot $relative
    if (($preserved -contains $normalized) -and (Test-Path -LiteralPath $target)) { continue }
    if ($normalized -match '(\.jks$|\.keystore$|(^|/)\.env($|\.)|service.account|firebase-adminsdk)') { continue }
    if (Test-Path -LiteralPath $target) {
        $saved = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $saved) | Out-Null
        Copy-Item -LiteralPath $target -Destination $saved -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}
Write-Host "Sources mises à jour dans $targetRoot" -ForegroundColor Green
Write-Host "Fichiers remplacés sauvegardés dans $backup"
Write-Host 'Étapes suivantes : flutter pub get, .\verifier_prospecto.ps1 puis flutter run. Déployer le backend 1.6.0 avec deployer_cloud_shell.sh avant de tester les réglages et suppressions.'
