$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI absent. Installez-le avec : npm install -g firebase-tools"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "Node.js/npm est requis."
}

Write-Host "Configuration Stripe pour Prospecto" -ForegroundColor Cyan
Write-Host "Projet Firebase : quiz-commercial" -ForegroundColor Gray
Write-Host "Aucune clé ne sera enregistrée dans les fichiers du projet." -ForegroundColor Yellow

firebase use quiz-commercial
if ($LASTEXITCODE -ne 0) { throw "Impossible de sélectionner quiz-commercial." }

Write-Host "`n1/2 - Clé secrète Stripe (sk_live_... ou sk_test_...)" -ForegroundColor Cyan
firebase functions:secrets:set STRIPE_SECRET_KEY
if ($LASTEXITCODE -ne 0) { throw "Enregistrement de STRIPE_SECRET_KEY impossible." }

Write-Host "`n2/2 - Secret de signature du webhook Stripe (whsec_...)" -ForegroundColor Cyan
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
if ($LASTEXITCODE -ne 0) { throw "Enregistrement de STRIPE_WEBHOOK_SECRET impossible." }

Write-Host "`nCompilation des fonctions..." -ForegroundColor Cyan
Push-Location functions
try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install a échoué." }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "La compilation TypeScript a échoué." }
} finally {
    Pop-Location
}

Write-Host "Déploiement Firebase..." -ForegroundColor Cyan
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
if ($LASTEXITCODE -ne 0) { throw "Le déploiement Firebase a échoué." }

Write-Host "`nStripe et le mode Entreprise sont déployés." -ForegroundColor Green
Write-Host "Testez ensuite un paiement Stripe en mode TEST avant la mise en production." -ForegroundColor Yellow
