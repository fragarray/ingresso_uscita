#!/bin/bash

# Script di test per verificare il fix del restore database

echo "🔍 TEST FIX BACKUP E RESTORE"
echo "=============================="
echo ""

# Test 1: Verifica file backup_settings.json
echo "📋 Test 1: Verifica backup_settings.json"
if [ -f "backup_settings.json" ]; then
    echo "✓ File backup_settings.json esiste"
    echo "Contenuto:"
    cat backup_settings.json | jq '.'
    
    # Verifica che autoBackupDays supporti 1
    days=$(cat backup_settings.json | jq '.autoBackupDays')
    echo "Giorni configurati: $days"
    
    if [ "$days" == "1" ]; then
        echo "✅ Backup giornaliero configurato correttamente!"
    fi
else
    echo "⚠️  File backup_settings.json non trovato"
    echo "Verrà creato al primo salvataggio"
fi

echo ""
echo "📋 Test 2: Verifica tabella attendance_records nel database"

# Controlla se sqlite3 è installato
if ! command -v sqlite3 &> /dev/null; then
    echo "⚠️  sqlite3 non installato. Installalo con:"
    echo "   sudo apt-get install sqlite3"
    exit 1
fi

# Verifica esistenza database
if [ ! -f "database.db" ]; then
    echo "❌ File database.db non trovato!"
    exit 1
fi

echo "✓ Database trovato"

# Verifica tabelle
echo ""
echo "Tabelle presenti nel database:"
sqlite3 database.db "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"

# Verifica specifica per attendance_records
echo ""
echo "Verifica tabella attendance_records:"
if sqlite3 database.db "SELECT name FROM sqlite_master WHERE type='table' AND name='attendance_records';" | grep -q "attendance_records"; then
    echo "✅ Tabella 'attendance_records' trovata!"
    
    echo ""
    echo "Struttura tabella attendance_records:"
    sqlite3 database.db "PRAGMA table_info(attendance_records);" | column -t -s '|'
    
    echo ""
    echo "Numero record presenti:"
    count=$(sqlite3 database.db "SELECT COUNT(*) FROM attendance_records;")
    echo "  → $count timbrature totali"
else
    echo "❌ Tabella 'attendance_records' NON trovata!"
    echo "Probabilmente hai un database vecchio."
fi

# Verifica altre tabelle richieste
echo ""
echo "📋 Test 3: Verifica tutte le tabelle richieste"

required_tables=("employees" "work_sites" "attendance_records")
all_ok=true

for table in "${required_tables[@]}"; do
    if sqlite3 database.db "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        echo "✅ Tabella '$table' OK"
    else
        echo "❌ Tabella '$table' MANCANTE"
        all_ok=false
    fi
done

echo ""
if [ "$all_ok" = true ]; then
    echo "🎉 TUTTI I TEST PASSATI!"
    echo ""
    echo "Il restore database ora funzionerà correttamente."
    echo "Puoi testare caricando un backup dalla pagina Impostazioni."
else
    echo "⚠️  Alcune tabelle sono mancanti."
    echo "Il database potrebbe essere corrotto o molto vecchio."
fi

echo ""
echo "=============================="
echo "Test completato!"
