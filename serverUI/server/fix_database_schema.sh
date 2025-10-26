#!/bin/bash

#######################################################################
# Script di Fix Rapido - Aggiunge colonne mancanti al database
# 
# Usa questo script se ricevi errore: "no such column: username"
# al momento del login
#
# Uso: bash fix_database_schema.sh
#######################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Fix Database Schema - Aggiungi Colonne Mancanti    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Percorso di default
PROJECT_DIR="$HOME/ingresso_uscita_server"

# Chiedi percorso personalizzato
read -p "$(echo -e ${YELLOW}Directory del server [${PROJECT_DIR}]: ${NC})" CUSTOM_DIR
if [ ! -z "$CUSTOM_DIR" ]; then
    PROJECT_DIR="$CUSTOM_DIR"
fi

# Verifica che la directory esista
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}✗ Directory non trovata: ${PROJECT_DIR}${NC}"
    exit 1
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}✓ Directory: ${PROJECT_DIR}${NC}"

# Verifica che il database esista
if [ ! -f "database.db" ]; then
    echo -e "${RED}✗ Database non trovato: database.db${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Database trovato${NC}"
echo ""

# Backup del database
echo -e "${YELLOW}Creazione backup del database...${NC}"
BACKUP_NAME="database_backup_$(date +%Y%m%d_%H%M%S).db"
cp database.db "$BACKUP_NAME"
echo -e "${GREEN}✓ Backup creato: ${BACKUP_NAME}${NC}"
echo ""

# Verifica se sqlite3 è installato
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${YELLOW}sqlite3 non trovato, installazione in corso...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y sqlite3
    echo -e "${GREEN}✓ sqlite3 installato${NC}"
fi

# Applica le modifiche al database
echo -e "${YELLOW}Applicazione modifiche allo schema del database...${NC}"
echo ""

sqlite3 database.db << 'EOF'
-- Aggiungi colonna username (se non esiste)
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;

-- Aggiungi colonna role (se non esiste)
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';

-- Aggiungi colonna isActive (se non esiste)
ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1;

-- Aggiungi colonna allowNightShift (se non esiste)
ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0;

-- Aggiungi colonna deleted (se non esiste)
ALTER TABLE employees ADD COLUMN deleted INTEGER DEFAULT 0;

-- Aggiungi colonna deletedAt (se non esiste)
ALTER TABLE employees ADD COLUMN deletedAt DATETIME;

-- Aggiungi colonna deletedByAdminId (se non esiste)
ALTER TABLE employees ADD COLUMN deletedByAdminId INTEGER;

-- Mostra struttura finale
.schema employees
EOF

RESULT=$?

echo ""

if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Schema database aggiornato con successo!${NC}"
else
    echo -e "${YELLOW}⚠ Alcune colonne potrebbero già esistere (normale)${NC}"
fi

echo ""

# Verifica se esiste almeno un utente con username
echo -e "${YELLOW}Verifica utenti nel database...${NC}"
USER_COUNT=$(sqlite3 database.db "SELECT COUNT(*) FROM employees WHERE username IS NOT NULL;")

if [ "$USER_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Nessun utente con username trovato${NC}"
    echo -e "${BLUE}Creazione utente amministratore di default...${NC}"
    
    # Crea admin di default
    sqlite3 database.db << 'EOF'
INSERT INTO employees (name, username, email, password, isAdmin, role, isActive) 
VALUES ('Admin', 'admin', 'admin@example.com', 'admin123', 1, 'admin', 1);
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Utente amministratore creato!${NC}"
        echo ""
        echo -e "${BLUE}📋 Credenziali di default:${NC}"
        echo -e "   ${GREEN}Username: admin${NC}"
        echo -e "   ${GREEN}Password: admin123${NC}"
        echo -e "   ${RED}⚠️  IMPORTANTE: Cambia la password al primo accesso!${NC}"
    else
        echo -e "${YELLOW}⚠ Errore creazione admin (forse esiste già)${NC}"
    fi
else
    echo -e "${GREEN}✓ Trovati ${USER_COUNT} utenti con username${NC}"
fi

echo ""
echo -e "${YELLOW}Elenco utenti:${NC}"
sqlite3 database.db "SELECT id, name, username, email, role FROM employees;" -header -column

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Fix completato!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Riavvia il server:${NC}"
echo -e "   ${GREEN}sudo systemctl restart ingresso-uscita${NC}"
echo ""
echo -e "${YELLOW}Verifica il log:${NC}"
echo -e "   ${GREEN}sudo journalctl -u ingresso-uscita -f${NC}"
echo ""
echo -e "${YELLOW}Se il backup è disponibile in:${NC}"
echo -e "   ${BLUE}${PROJECT_DIR}/${BACKUP_NAME}${NC}"
echo ""
