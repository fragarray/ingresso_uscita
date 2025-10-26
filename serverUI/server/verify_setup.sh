#!/bin/bash

# Script di verifica setup - controlla che tutti i file necessari siano presenti

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Verifica Integrità Installazione Server    ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

ERRORS=0
WARNINGS=0

# File obbligatori
echo -e "${YELLOW}File Obbligatori:${NC}"
REQUIRED=(
    "server.js"
    "db.js"
    "config.js"
    "package.json"
    "package-lock.json"
)

for file in "${REQUIRED[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file ${RED}MANCANTE${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${YELLOW}File Opzionali (per migrazione/debug):${NC}"
OPTIONAL=(
    "migrate_username_auth.js"
    "check_users.js"
    "fix_timestamps.js"
    "check_forced_records.js"
)

for file in "${OPTIONAL[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${YELLOW}⚠${NC} $file ${YELLOW}opzionale mancante${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""
echo -e "${YELLOW}Cartelle Obbligatorie:${NC}"
REQUIRED_DIRS=(
    "routes"
    "node_modules"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓${NC} $dir/ (${COUNT} file)"
    else
        echo -e "  ${RED}✗${NC} $dir/ ${RED}MANCANTE${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${YELLOW}Cartelle Opzionali:${NC}"
OPTIONAL_DIRS=(
    "backups"
    "reports"
    "temp"
)

for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✓${NC} $dir/ (${COUNT} file)"
    else
        echo -e "  ${YELLOW}⚠${NC} $dir/ ${YELLOW}opzionale mancante${NC}"
    fi
done

echo ""
echo -e "${YELLOW}File di Configurazione:${NC}"
CONFIG_FILES=(
    "email_config.json"
    "backup_settings.json"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo -e "  ${GREEN}✓${NC} $file (${SIZE})"
    else
        echo -e "  ${YELLOW}⚠${NC} $file ${YELLOW}non configurato (verrà creato al primo avvio)${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Database:${NC}"
if [ -f "ingresso_uscita.db" ]; then
    SIZE=$(du -h "ingresso_uscita.db" | cut -f1)
    echo -e "  ${GREEN}✓${NC} ingresso_uscita.db (${SIZE})"
    
    # Controlla struttura database
    if command -v sqlite3 &> /dev/null; then
        TABLES=$(sqlite3 ingresso_uscita.db ".tables" 2>/dev/null)
        if echo "$TABLES" | grep -q "employees"; then
            echo -e "    ${GREEN}✓${NC} Tabella employees presente"
            
            # Controlla se ha colonna username (nuovo schema)
            if sqlite3 ingresso_uscita.db "PRAGMA table_info(employees);" 2>/dev/null | grep -q "username"; then
                echo -e "    ${GREEN}✓${NC} Schema aggiornato (con username)"
            else
                echo -e "    ${YELLOW}⚠${NC} Schema vecchio (senza username) - ${YELLOW}serve migrazione${NC}"
            fi
        fi
    fi
else
    echo -e "  ${BLUE}ℹ${NC} ingresso_uscita.db non presente (verrà creato al primo avvio)"
fi

echo ""
echo -e "${YELLOW}Dipendenze Node.js Critiche:${NC}"
CRITICAL_DEPS=(
    "express"
    "sqlite3"
    "nodemailer"
    "exceljs"
    "cors"
    "body-parser"
)

for dep in "${CRITICAL_DEPS[@]}"; do
    if npm list "$dep" &> /dev/null; then
        VERSION=$(npm list "$dep" --depth=0 2>/dev/null | grep "$dep" | awk '{print $2}' | tr -d '@')
        echo -e "  ${GREEN}✓${NC} $dep ${BLUE}($VERSION)${NC}"
    else
        echo -e "  ${RED}✗${NC} $dep ${RED}NON INSTALLATO${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Riepilogo
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Setup completo e funzionante!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} file opzionali mancanti (non bloccanti)${NC}"
    fi
    echo ""
    echo -e "${GREEN}Il server è pronto per essere avviato.${NC}"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} errori critici rilevati!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} file opzionali mancanti${NC}"
    fi
    echo ""
    echo -e "${RED}Il server NON può essere avviato.${NC}"
    echo -e "${YELLOW}Esegui nuovamente setup_server_fixed.sh${NC}"
    exit 1
fi
