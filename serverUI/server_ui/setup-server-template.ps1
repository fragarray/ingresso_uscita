# Script per copiare la cartella server template nella posizione corretta
# Autore: GitHub Copilot
# Data: 26 Ottobre 2025

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Setup Server Template - Windows" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$projectRoot = $PSScriptRoot
$serverSource = Join-Path (Split-Path $projectRoot) "server"
$buildDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$serverDest = Join-Path $buildDir "server"

# Verifica che la cartella sorgente esista
if (-not (Test-Path $serverSource)) {
    Write-Host "[X] Errore: Cartella server non trovata in:" -ForegroundColor Red
    Write-Host "    $serverSource" -ForegroundColor Red
    Write-Host ""
    Write-Host "Assicurati di essere nella cartella server_ui" -ForegroundColor Yellow
    exit 1
}

Write-Host "[i] Percorso sorgente: $serverSource" -ForegroundColor Gray
Write-Host "[i] Percorso destinazione: $serverDest" -ForegroundColor Gray
Write-Host ""

# Verifica che la cartella build esista
if (-not (Test-Path $buildDir)) {
    Write-Host "[!] La cartella Release non esiste ancora." -ForegroundColor Yellow
    Write-Host "    Compila prima l'applicazione:" -ForegroundColor Yellow
    Write-Host "    flutter build windows --release" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Premi INVIO per compilare ora (o CTRL+C per annullare)"
    
    Write-Host ""
    Write-Host "[*] Compilazione in corso..." -ForegroundColor Cyan
    Set-Location $projectRoot
    flutter build windows --release
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Errore durante la compilazione" -ForegroundColor Red
        exit 1
    }
}

# Rimuovi la cartella esistente se presente
if (Test-Path $serverDest) {
    Write-Host "[*] Rimozione cartella server esistente..." -ForegroundColor Yellow
    Remove-Item $serverDest -Recurse -Force
}

# Copia la cartella server
Write-Host "[*] Copia cartella server template..." -ForegroundColor Cyan
Copy-Item -Path $serverSource -Destination $serverDest -Recurse

# Verifica che i file essenziali siano stati copiati
$essentialFiles = @("server.js", "package.json", "db.js", "config.js")
$allCopied = $true

Write-Host ""
Write-Host "[v] Verifica file copiati:" -ForegroundColor Cyan
foreach ($file in $essentialFiles) {
    $filePath = Join-Path $serverDest $file
    if (Test-Path $filePath) {
        Write-Host "    [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "    [X] $file - NON TROVATO" -ForegroundColor Red
        $allCopied = $false
    }
}

# Verifica cartella routes
$routesDir = Join-Path $serverDest "routes"
if (Test-Path $routesDir) {
    $routesCount = (Get-ChildItem $routesDir -File).Count
    Write-Host "    [OK] routes\ ($routesCount file)" -ForegroundColor Green
} else {
    Write-Host "    [X] routes\ - NON TROVATA" -ForegroundColor Red
    $allCopied = $false
}

Write-Host ""

if ($allCopied) {
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host "  Setup completato con successo!" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ora puoi avviare l'applicazione:" -ForegroundColor Cyan
    Write-Host "  $buildDir\server_ui.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "Quando crei un nuovo server, i file template" -ForegroundColor Gray
    Write-Host "verranno copiati da questa cartella." -ForegroundColor Gray
} else {
    Write-Host "=======================================" -ForegroundColor Red
    Write-Host "  Attenzione: Setup incompleto" -ForegroundColor Red
    Write-Host "=======================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alcuni file non sono stati copiati correttamente." -ForegroundColor Yellow
    Write-Host "Verifica manualmente la cartella sorgente." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
