$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Configuration production Prospecto" -ForegroundColor Cyan
Write-Host "L'ID demandé est l'ID D'APPLICATION AdMob (il contient ~), pas l'ID d'un bloc d'annonces." -ForegroundColor Yellow
$admob = Read-Host "Collez l'ID d'application AdMob Prospecto (ca-app-pub-...~...)"
if ($admob -notmatch '^ca-app-pub-\d+~\d+$') {
    throw "Format AdMob invalide. Ouvrez AdMob > Prospecto > Paramètres de l'application."
}

$maps = Read-Host "Clé Android Google Maps restreinte (Entrée = conserver la clé actuelle)"
$gradleFile = Join-Path $PSScriptRoot "android\gradle.properties"
$content = Get-Content $gradleFile -Raw
$content = [regex]::Replace($content, '(?m)^PROSPECTO_ADMOB_APP_ID=.*$', "PROSPECTO_ADMOB_APP_ID=$admob")
if (-not [string]::IsNullOrWhiteSpace($maps)) {
    $content = [regex]::Replace($content, '(?m)^PROSPECTO_MAPS_ANDROID_KEY=.*$', "PROSPECTO_MAPS_ANDROID_KEY=$maps")
}
[System.IO.File]::WriteAllText($gradleFile, $content, (New-Object System.Text.UTF8Encoding($false)))

$prodFile = Join-Path $PSScriptRoot "config\prod.json"
$config = Get-Content $prodFile -Raw | ConvertFrom-Json
$config.ADMOB_PRODUCTION_ENABLED = $true
$json = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($prodFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`nConfiguration enregistrée. Les 3 blocs AdMob officiels Prospecto sont activés pour le build release." -ForegroundColor Green
