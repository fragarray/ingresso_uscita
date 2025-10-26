# Script PowerShell per Sinergy Work Server Manager
# Facilita la compilazione e l'esecuzione dell'applicazione

param(
    [Parameter(Position=0)]
    [ValidateSet("run", "build", "clean", "help")]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Show-Help {
    Write-ColorOutput Cyan "=== Sinergy Work Server Manager - Build Script ==="
    Write-Output ""
    Write-Output "Comandi disponibili:"
    Write-Output ""
    Write-ColorOutput Green "  run"
    Write-Output "    Esegue l'applicazione in modalità debug"
    Write-Output ""
    Write-ColorOutput Green "  build"
    Write-Output "    Compila l'applicazione per Windows (release)"
    Write-Output ""
    Write-ColorOutput Green "  clean"
    Write-Output "    Pulisce i file di build e cache"
    Write-Output ""
    Write-ColorOutput Green "  help"
    Write-Output "    Mostra questo messaggio di aiuto"
    Write-Output ""
    Write-Output "Esempi:"
    Write-ColorOutput Yellow "  .\build.ps1 run       # Esegue in debug mode"
    Write-ColorOutput Yellow "  .\build.ps1 build     # Compila release"
    Write-ColorOutput Yellow "  .\build.ps1 clean     # Pulisce build"
    Write-Output ""
}

function Test-Prerequisites {
    Write-ColorOutput Cyan "Verifica prerequisiti..."
    
    # Verifica Flutter
    try {
        $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
        Write-ColorOutput Green "✓ Flutter trovato: $flutterVersion"
    } catch {
        Write-ColorOutput Red "✗ Flutter non trovato!"
        Write-Output "  Installa Flutter da: https://docs.flutter.dev/get-started/install/windows"
        exit 1
    }
    
    # Verifica Node.js
    try {
        $nodeVersion = node --version
        Write-ColorOutput Green "✓ Node.js trovato: $nodeVersion"
    } catch {
        Write-ColorOutput Yellow "⚠ Node.js non trovato (necessario per eseguire i server)"
        Write-Output "  Installa Node.js da: https://nodejs.org/"
    }
    
    Write-Output ""
}

function Run-App {
    Write-ColorOutput Cyan "=== Avvio applicazione in modalità debug ==="
    Test-Prerequisites
    
    Write-Output "Installazione dipendenze..."
    flutter pub get
    
    Write-Output ""
    Write-ColorOutput Green "Avvio applicazione..."
    flutter run -d windows
}

function Build-App {
    Write-ColorOutput Cyan "=== Compilazione applicazione per Windows ==="
    Test-Prerequisites
    
    Write-Output "Installazione dipendenze..."
    flutter pub get
    
    Write-Output ""
    Write-ColorOutput Green "Compilazione in corso (può richiedere alcuni minuti)..."
    flutter build windows --release
    
    $exePath = Join-Path $ProjectRoot "build\windows\x64\runner\Release\server_ui.exe"
    
    if (Test-Path $exePath) {
        Write-Output ""
        Write-ColorOutput Green "✓ Compilazione completata con successo!"
        Write-Output ""
        Write-Output "Eseguibile creato in:"
        Write-ColorOutput Yellow "  $exePath"
        Write-Output ""
        Write-Output "Per eseguire l'applicazione:"
        Write-ColorOutput Yellow "  cd build\windows\x64\runner\Release"
        Write-ColorOutput Yellow "  .\server_ui.exe"
    } else {
        Write-ColorOutput Red "✗ Errore durante la compilazione"
        exit 1
    }
}

function Clean-Build {
    Write-ColorOutput Cyan "=== Pulizia file di build ==="
    
    Write-Output "Rimozione build directory..."
    if (Test-Path "build") {
        Remove-Item -Recurse -Force "build"
        Write-ColorOutput Green "✓ Build directory rimossa"
    }
    
    Write-Output "Rimozione .dart_tool..."
    if (Test-Path ".dart_tool") {
        Remove-Item -Recurse -Force ".dart_tool"
        Write-ColorOutput Green "✓ .dart_tool rimosso"
    }
    
    Write-Output ""
    Write-ColorOutput Green "✓ Pulizia completata!"
    Write-Output ""
    Write-Output "Esegui 'flutter pub get' prima di compilare di nuovo."
}

# Main
Clear-Host

switch ($Command) {
    "run" {
        Run-App
    }
    "build" {
        Build-App
    }
    "clean" {
        Clean-Build
    }
    "help" {
        Show-Help
    }
    default {
        Show-Help
    }
}
