#!/bin/bash
# Server Manager - Avvio Applicazione
# Versione: 1.0.0

echo "🚀 Avvio Server Manager..."

# Controlla dipendenze sistema
check_dependencies() {
    echo "🔍 Controllo dipendenze sistema..."
    
    # Node.js
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js non trovato. Installazione richiesta:"
        echo "   sudo apt-get install nodejs npm"
        exit 1
    fi
    
    # npm
    if ! command -v npm &> /dev/null; then
        echo "❌ npm non trovato. Installazione richiesta:"
        echo "   sudo apt-get install npm"
        exit 1
    fi
    
    # System tray support
    if ! ldconfig -p | grep -q libayatana-appindicator; then
        echo "⚠️  System tray support mancante. Installazione consigliata:"
        echo "   sudo apt-get install libayatana-appindicator3-dev"
        echo "   (L'applicazione funzionerà comunque)"
    fi
    
    echo "✅ Dipendenze sistema verificate"
    echo "   Node.js: $(node --version)"
    echo "   npm: $(npm --version)"
}

# Controlla se l'applicazione è già compilata
check_build() {
    local app_path="./build/linux/arm64/release/bundle/server_ui"
    
    if [ ! -f "$app_path" ]; then
        echo "📦 Applicazione non compilata. Compilazione in corso..."
        flutter build linux --release
        
        if [ $? -ne 0 ]; then
            echo "❌ Errore durante la compilazione"
            exit 1
        fi
    else
        echo "✅ Applicazione già compilata"
    fi
}

# Avvia applicazione
start_app() {
    local app_path="./build/linux/arm64/release/bundle/server_ui"
    
    echo "🎯 Avvio Server Manager..."
    echo "   Eseguibile: $app_path"
    echo ""
    
    # Avvia l'applicazione
    cd build/linux/arm64/release/bundle/
    ./server_ui
}

# Main
main() {
    # Banner
    echo "=================================="
    echo "      🖥️  SERVER MANAGER v1.0"
    echo "    Gestione Server Ingresso/Uscita"
    echo "=================================="
    echo ""
    
    # Vai alla directory dell'applicazione
    cd "$(dirname "$0")"
    
    # Controlla dipendenze
    check_dependencies
    echo ""
    
    # Controlla build
    check_build
    echo ""
    
    # Avvia app
    start_app
}

# Esegui main se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi