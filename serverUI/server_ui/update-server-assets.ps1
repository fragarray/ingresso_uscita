# Script per aggiornare gli asset del server template
# Usa questo script quando modifichi i file del server Node.js
# e vuoi aggiornarli nell'applicazione Flutter

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Aggiornamento Server Template Asset" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$serverUIRoot = $PSScriptRoot
$serverSource = Join-Path (Split-Path $serverUIRoot) "server"
$assetsDir = Join-Path $serverUIRoot "assets\server_template"

# Verifica che la cartella server esista
if (-not (Test-Path $serverSource)) {
    Write-Host "[X] Errore: Cartella server non trovata:" -ForegroundColor Red
    Write-Host "    $serverSource" -ForegroundColor Red
    exit 1
}

Write-Host "[i] Sorgente: $serverSource" -ForegroundColor Gray
Write-Host "[i] Destinazione: $assetsDir" -ForegroundColor Gray
Write-Host ""

# Crea la cartella assets se non esiste
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    Write-Host "[+] Creata cartella: assets\server_template" -ForegroundColor Green
}

# Crea la sottocartella routes
$routesDir = Join-Path $assetsDir "routes"
if (-not (Test-Path $routesDir)) {
    New-Item -ItemType Directory -Path $routesDir -Force | Out-Null
    Write-Host "[+] Creata cartella: assets\server_template\routes" -ForegroundColor Green
}

Write-Host ""
Write-Host "[*] Copia file template..." -ForegroundColor Cyan

# File principali da copiare
$mainFiles = @(
    "server.js",
    "db.js",
    "config.js",
    "package.json"
)

$copiedCount = 0
$errorCount = 0

foreach ($file in $mainFiles) {
    $sourcePath = Join-Path $serverSource $file
    $destPath = Join-Path $assetsDir $file
    
    if (Test-Path $sourcePath) {
        try {
            Copy-Item $sourcePath $destPath -Force
            Write-Host "    [OK] $file" -ForegroundColor Green
            $copiedCount++
        } catch {
            Write-Host "    [X] $file - Errore: $_" -ForegroundColor Red
            $errorCount++
        }
    } else {
        Write-Host "    [!] $file - File non trovato" -ForegroundColor Yellow
        $errorCount++
    }
}

# Copia file routes
Write-Host ""
Write-Host "[*] Copia file routes..." -ForegroundColor Cyan

$routesSource = Join-Path $serverSource "routes"
if (Test-Path $routesSource) {
    $routeFiles = Get-ChildItem "$routesSource\*.js"
    
    foreach ($file in $routeFiles) {
        try {
            Copy-Item $file.FullName (Join-Path $routesDir $file.Name) -Force
            Write-Host "    [OK] routes\$($file.Name)" -ForegroundColor Green
            $copiedCount++
        } catch {
            Write-Host "    [X] routes\$($file.Name) - Errore: $_" -ForegroundColor Red
            $errorCount++
        }
    }
} else {
    Write-Host "    [!] Cartella routes non trovata" -ForegroundColor Yellow
}

Write-Host ""

# Riepilogo
if ($errorCount -eq 0) {
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host "  Aggiornamento completato!" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "File copiati: $copiedCount" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Prossimi passi:" -ForegroundColor Yellow
    Write-Host "  1. Esegui: flutter pub get" -ForegroundColor White
    Write-Host "  2. Ricompila: flutter build windows --release" -ForegroundColor White
    Write-Host "  3. Testa creando un nuovo server" -ForegroundColor White
} else {
    Write-Host "=======================================" -ForegroundColor Yellow
    Write-Host "  Attenzione: Alcuni errori" -ForegroundColor Yellow
    Write-Host "=======================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "File copiati: $copiedCount" -ForegroundColor Cyan
    Write-Host "Errori: $errorCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica i file mancanti o gli errori sopra." -ForegroundColor Yellow
}

Write-Host ""
