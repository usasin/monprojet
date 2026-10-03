$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI absent. Installez-le avec : npm install -g firebase-tools"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "Node.js/npm est requis pour compiler les Cloud Functions."
}

Write-Host "Compilation des fonctions Prospecto Entreprise..." -ForegroundColor Cyan
Push-Location functions
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci a échoué." }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "La compilation TypeScript a échoué." }
} finally {
    Pop-Location
}

Write-Host "Déploiement des règles, index, stockage et fonctions..." -ForegroundColor Cyan
$projectId = (Get-Content "android\app\google-services.json" -Raw | ConvertFrom-Json).project_info.project_id
if ([string]::IsNullOrWhiteSpace($projectId)) { throw "Projet Firebase absent de google-services.json." }
$configuredProject = (Get-Content ".firebaserc" -Raw | ConvertFrom-Json).projects.default
if ($configuredProject -ne $projectId) { throw "Les configurations Firebase divergent : .firebaserc=$configuredProject ; Android=$projectId. Corrigez-les avant de déployer." }
Write-Host "Projet Firebase : $projectId" -ForegroundColor Cyan

firebase deploy --project $projectId --only firestore:rules,firestore:indexes,storage,functions
if ($LASTEXITCODE -ne 0) { throw "Le déploiement Firebase a échoué." }

Write-Host "`nBackend Entreprise déployé." -ForegroundColor Green
