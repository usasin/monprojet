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
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install a échoué." }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "La compilation TypeScript a échoué." }
} finally {
    Pop-Location
}

Write-Host "Déploiement des règles, index, stockage et fonctions..." -ForegroundColor Cyan
firebase use quiz-commercial
if ($LASTEXITCODE -ne 0) { throw "Impossible de sélectionner quiz-commercial." }

firebase deploy --only firestore:rules,firestore:indexes,storage,functions
if ($LASTEXITCODE -ne 0) { throw "Le déploiement Firebase a échoué." }

Write-Host "`nBackend Entreprise déployé." -ForegroundColor Green
