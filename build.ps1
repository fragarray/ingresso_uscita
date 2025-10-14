# Script Build Rapido - Ingresso Uscita
# Esegui con: .\build.ps1 [windows|android|all]

param(
    [Parameter(Position=0)]
    [ValidateSet("windows","android","all")]
    [string]$Platform = "all"
)

Write-Host "🚀 Build Ingresso Uscita - Release" -ForegroundColor Cyan
Write-Host ""

function Build-Windows {
    Write-Host "🪟 Building Windows..." -ForegroundColor Yellow
    
    # Clean
    Write-Host "  Cleaning..." -ForegroundColor Gray
    flutter clean | Out-Null
    
    # Get dependencies
    Write-Host "  Getting dependencies..." -ForegroundColor Gray
    flutter pub get | Out-Null
    
    # Build release
    Write-Host "  Building Windows release..." -ForegroundColor Gray
    flutter build windows --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build Windows completato!" -ForegroundColor Green
        Write-Host "  📁 Output: build\windows\x64\runner\Release\" -ForegroundColor Cyan
        
        # Crea MSIX
        Write-Host ""
        Write-Host "  📦 Creando installer MSIX..." -ForegroundColor Gray
        flutter pub run msix:create
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ MSIX creato!" -ForegroundColor Green
            Write-Host "  📁 Output: build\windows\x64\runner\Release\ingresso_uscita.msix" -ForegroundColor Cyan
        } else {
            Write-Host "  ⚠️  MSIX fallito (verifica configurazione in pubspec.yaml)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Build Windows fallito!" -ForegroundColor Red
    }
}

function Build-Android {
    Write-Host "🤖 Building Android..." -ForegroundColor Yellow
    
    # Verifica keystore
    $keystoreFile = "android\key.properties"
    if (-Not (Test-Path $keystoreFile)) {
        Write-Host "  ⚠️  File $keystoreFile non trovato!" -ForegroundColor Yellow
        Write-Host "  📝 L'APK sarà firmato con chiavi debug (solo per test)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Per creare keystore di produzione:" -ForegroundColor Cyan
        Write-Host "  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Clean
    Write-Host "  Cleaning..." -ForegroundColor Gray
    flutter clean | Out-Null
    
    # Get dependencies
    Write-Host "  Getting dependencies..." -ForegroundColor Gray
    flutter pub get | Out-Null
    
    # Build APK split
    Write-Host "  Building Android APK (split per ABI)..." -ForegroundColor Gray
    flutter build apk --release --split-per-abi
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build Android completato!" -ForegroundColor Green
        Write-Host "  📁 Output: build\app\outputs\flutter-apk\" -ForegroundColor Cyan
        Write-Host ""
        
        # Mostra dimensioni APK
        Write-Host "  📦 APK generati:" -ForegroundColor Cyan
        Get-ChildItem "build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
            $size = [math]::Round($_.Length / 1MB, 2)
            Write-Host "    - $($_.Name) ($size MB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ❌ Build Android fallito!" -ForegroundColor Red
    }
}

# Esegui build
switch ($Platform) {
    "windows" {
        Build-Windows
    }
    "android" {
        Build-Android
    }
    "all" {
        Build-Windows
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
        Build-Android
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "✅ Build completato!" -ForegroundColor Green
Write-Host ""
