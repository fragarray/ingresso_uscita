#!/bin/bash

#######################################################################
# Script Rapido di Aggiornamento Server
# 
# Usa questo script se hai già installato il server e vuoi solo
# aggiornare il codice mantenendo la configurazione esistente
#
# Uso: bash update_server.sh
#######################################################################

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Aggiornamento Server Ingresso/Uscita               ║${NC}"
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
echo ""

# Backup della configurazione email
if [ -f "email_config.json" ]; then
    echo -e "${YELLOW}Backup configurazione email...${NC}"
    cp email_config.json email_config.json.backup
    echo -e "${GREEN}✓ Backup salvato in email_config.json.backup${NC}"
fi

# Backup del database
if [ -f "ingresso_uscita.db" ]; then
    echo -e "${YELLOW}Backup database...${NC}"
    BACKUP_NAME="backups/db_backup_$(date +%Y%m%d_%H%M%S).db"
    mkdir -p backups
    cp ingresso_uscita.db "$BACKUP_NAME"
    echo -e "${GREEN}✓ Backup salvato in ${BACKUP_NAME}${NC}"
fi

# Scarica aggiornamenti
echo ""
echo -e "${YELLOW}Scaricamento aggiornamenti dal repository...${NC}"
git fetch origin main
git pull origin main

# Aggiorna dipendenze
echo ""
echo -e "${YELLOW}Aggiornamento dipendenze npm...${NC}"
npm install

# Verifica nodemailer
echo ""
echo -e "${YELLOW}Verifica nodemailer...${NC}"
NODE_CHECK=$(node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);" 2>&1)
if [ "$NODE_CHECK" = "function" ]; then
    echo -e "${GREEN}✓ nodemailer OK${NC}"
else
    echo -e "${YELLOW}⚠ Reinstallazione nodemailer...${NC}"
    npm uninstall nodemailer
    npm install nodemailer@6.9.7
    echo -e "${GREEN}✓ nodemailer reinstallato${NC}"
fi

# Ripristina configurazione email se esisteva
if [ -f "email_config.json.backup" ]; then
    if [ ! -f "email_config.json" ]; then
        echo -e "${YELLOW}Ripristino configurazione email...${NC}"
        cp email_config.json.backup email_config.json
        echo -e "${GREEN}✓ Configurazione email ripristinata${NC}"
    fi
fi

# Rileva il sistema di gestione
echo ""
echo -e "${YELLOW}Rilevamento sistema di gestione server...${NC}"

USING_SYSTEMD=false
USING_PM2=false

# Check systemd
if systemctl is-active --quiet ingresso-uscita 2>/dev/null; then
    USING_SYSTEMD=true
    echo -e "${GREEN}✓ Rilevato: systemd${NC}"
fi

# Check PM2
if command -v pm2 &> /dev/null; then
    if pm2 list | grep -q "ingresso-uscita"; then
        USING_PM2=true
        echo -e "${GREEN}✓ Rilevato: PM2${NC}"
    fi
fi

# Riavvio del servizio
echo ""
if [ "$USING_SYSTEMD" = true ]; then
    read -p "$(echo -e ${YELLOW}Vuoi riavviare il servizio systemd ora? [S/n] ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo systemctl restart ingresso-uscita
        sleep 2
        echo ""
        sudo systemctl status ingresso-uscita --no-pager
        echo ""
        echo -e "${GREEN}✓ Servizio systemd riavviato${NC}"
    fi
elif [ "$USING_PM2" = true ]; then
    read -p "$(echo -e ${YELLOW}Vuoi riavviare il server con PM2 ora? [S/n] ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        pm2 restart ingresso-uscita
        echo ""
        pm2 list
        echo ""
        echo -e "${GREEN}✓ Server PM2 riavviato${NC}"
    fi
else
    echo -e "${YELLOW}Nessun sistema di gestione automatico rilevato${NC}"
    echo -e "${YELLOW}Riavvia manualmente il server con: ${GREEN}node server.js${NC}"
fi

# Riepilogo
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ Aggiornamento completato!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Riepilogo aggiornamenti:${NC}"
echo -e "   ${GREEN}✓${NC} Codice server aggiornato"
echo -e "   ${GREEN}✓${NC} Dipendenze npm aggiornate"
echo -e "   ${GREEN}✓${NC} nodemailer verificato"
if [ -f "email_config.json.backup" ]; then
    echo -e "   ${GREEN}✓${NC} Configurazione email preservata"
fi
if [ -f "$BACKUP_NAME" ]; then
    echo -e "   ${GREEN}✓${NC} Backup database creato"
fi
echo ""
echo -e "${YELLOW}🔍 Verifica funzionamento:${NC}"
if [ "$USING_SYSTEMD" = true ]; then
    echo -e "   ${GREEN}sudo systemctl status ingresso-uscita${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ingresso-uscita -f${NC}"
elif [ "$USING_PM2" = true ]; then
    echo -e "   ${GREEN}pm2 status${NC}"
    echo -e "   ${GREEN}pm2 logs ingresso-uscita${NC}"
fi
echo ""
echo -e "${GREEN}✨ Server aggiornato e pronto! ✨${NC}"
echo ""
