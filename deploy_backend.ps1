$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI absent. Installez-le avec : npm install -g firebase-tools"
}

Write-Host "Déploiement des règles Firebase uniquement (mode solo)." -ForegroundColor Cyan
Write-Host "Pour le mode Entreprise, utilisez .\deploy_entreprise.ps1" -ForegroundColor Yellow

firebase use quiz-commercial
if ($LASTEXITCODE -ne 0) { throw "Impossible de sélectionner quiz-commercial." }

firebase deploy --only firestore:rules,firestore:indexes,storage
if ($LASTEXITCODE -ne 0) { throw "Le déploiement des règles Firebase a échoué." }

Write-Host "`nRègles Firebase déployées." -ForegroundColor Green
