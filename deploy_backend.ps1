$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI absent. Installez-le avec : npm install -g firebase-tools"
}

Write-Host "Déploiement des règles Firebase uniquement (mode solo)." -ForegroundColor Cyan
Write-Host "Pour le mode Entreprise, utilisez .\deploy_entreprise.ps1" -ForegroundColor Yellow

$projectId = (Get-Content "android\app\google-services.json" -Raw | ConvertFrom-Json).project_info.project_id
if ([string]::IsNullOrWhiteSpace($projectId)) { throw "Projet Firebase absent de google-services.json." }
$configuredProject = (Get-Content ".firebaserc" -Raw | ConvertFrom-Json).projects.default
if ($configuredProject -ne $projectId) { throw "Les configurations Firebase divergent : .firebaserc=$configuredProject ; Android=$projectId. Corrigez-les avant de déployer." }
Write-Host "Projet Firebase : $projectId" -ForegroundColor Cyan

firebase deploy --project $projectId --only firestore:rules,firestore:indexes,storage
if ($LASTEXITCODE -ne 0) { throw "Le déploiement des règles Firebase a échoué." }

Write-Host "`nRègles Firebase déployées." -ForegroundColor Green
