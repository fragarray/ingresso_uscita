#!/bin/bash

#######################################################################
# Script Rapido di Aggiornamento Server v1.2.0
# 
# Usa questo script se hai già installato il server e vuoi solo
# aggiornare il codice mantenendo la configurazione esistente
#
# DOVE ESEGUIRLO:
#   - Esegui questo script da QUALSIASI CARTELLA (es. home del Raspberry)
#   - Lo script ti chiederà dove si trova la cartella del server
#   - Default: $HOME/ingresso_uscita_server
#
# COSA FA:
#   - Scarica gli ultimi aggiornamenti dal repository GitHub
#   - Aggiorna le dipendenze npm
#   - RILEVA se serve la migrazione del database (email → username)
#   - Esegue la migrazione in modo interattivo se necessario
#   - Preserva configurazioni (email_config.json, backup_settings.json)
#   - Mantiene il database esistente (con backup automatico)
#   - Riavvia il servizio automaticamente
#
# ESEMPIO D'USO:
#   cd ~
#   wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
#   bash update_server.sh
#
# NOTA: Funziona sia con repository git che con installazioni standalone
#######################################################################

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Aggiornamento Server Ingresso/Uscita v1.2.0        ║${NC}"
echo -e "${BLUE}║   Con Migrazione Username + Ruoli + Capocantiere     ║${NC}"
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
DB_EXISTS=false
if [ -f "ingresso_uscita.db" ]; then
    DB_EXISTS=true
    echo -e "${YELLOW}Backup database...${NC}"
    BACKUP_NAME="backups/db_backup_$(date +%Y%m%d_%H%M%S).db"
    mkdir -p backups
    cp ingresso_uscita.db "$BACKUP_NAME"
    echo -e "${GREEN}✓ Backup salvato in ${BACKUP_NAME}${NC}"
fi

# Scarica aggiornamenti
echo ""
echo -e "${YELLOW}Scaricamento aggiornamenti dal repository...${NC}"

# Verifica se è un repository git
if [ -d ".git" ]; then
    echo -e "${BLUE}Repository git rilevato, uso git pull...${NC}"
    git fetch origin main
    git pull origin main
else
    echo -e "${YELLOW}⚠ Repository git non trovato${NC}"
    echo -e "${BLUE}Scaricamento file tramite sparse checkout...${NC}"
    
    # Backup dei file importanti
    if [ -f "email_config.json" ]; then
        cp email_config.json email_config.json.update_backup
    fi
    if [ -f "backup_settings.json" ]; then
        cp backup_settings.json backup_settings.json.update_backup
    fi
    
    # Inizializza repository temporaneo
    git init
    git remote add origin https://github.com/fragarray/ingresso_uscita.git || git remote set-url origin https://github.com/fragarray/ingresso_uscita.git
    git config core.sparseCheckout true
    
    # Configura sparse checkout per scaricare solo la cartella server
    echo "server/**" > .git/info/sparse-checkout
    
    # Scarica i file
    if ! git pull origin main; then
        echo -e "${RED}✗ Errore durante il download dal repository${NC}"
        echo -e "${YELLOW}Verifica la connessione internet e riprova${NC}"
        exit 1
    fi
    
    # Sposta i file dalla sottocartella alla root
    if [ -d "server" ]; then
        echo -e "${YELLOW}Organizzazione file...${NC}"
        shopt -s dotglob
        cp -r server/* . 2>/dev/null || true
        shopt -u dotglob
        rm -rf server
    fi
    
    # Ripristina configurazioni
    if [ -f "email_config.json.update_backup" ]; then
        mv email_config.json.update_backup email_config.json
        echo -e "${GREEN}✓ Configurazione email ripristinata${NC}"
    fi
    if [ -f "backup_settings.json.update_backup" ]; then
        mv backup_settings.json.update_backup backup_settings.json
        echo -e "${GREEN}✓ Configurazione backup ripristinata${NC}"
    fi
    
    # Rimuovi .git per risparmiare spazio
    rm -rf .git
    
    echo -e "${GREEN}✓ File aggiornati con successo${NC}"
fi

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

# ==================== MIGRAZIONE DATABASE ====================
# Controlla se serve la migrazione da email a username
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}[IMPORTANTE] Migrazione Sistema di Autenticazione${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

NEEDS_MIGRATION=false

if [ "$DB_EXISTS" = true ]; then
    # Controlla se la colonna username esiste già
    if sqlite3 ingresso_uscita.db "PRAGMA table_info(employees);" | grep -q "username"; then
        echo -e "${GREEN}✓ Database già migrato (colonna username presente)${NC}"
    else
        echo -e "${YELLOW}⚠ Database vecchio rilevato (senza colonna username)${NC}"
        NEEDS_MIGRATION=true
    fi
else
    echo -e "${BLUE}ℹ Nessun database esistente (verrà creato al primo avvio)${NC}"
fi

if [ "$NEEDS_MIGRATION" = true ]; then
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  MIGRAZIONE RICHIESTA: Email → Username Authentication  ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Cosa farà la migrazione:${NC}"
    echo -e "   ${BLUE}•${NC} Crea backup automatico del database"
    echo -e "   ${BLUE}•${NC} Genera username da email esistenti (parte prima della @)"
    echo -e "   ${BLUE}•${NC} Gestisce duplicati con suffisso numerico (_1, _2, ecc.)"
    echo -e "   ${BLUE}•${NC} Assegna ruoli: admin (da isAdmin=1) o employee"
    echo -e "   ${BLUE}•${NC} Rende email opzionale (obbligatoria solo per admin)"
    echo -e "   ${BLUE}•${NC} Password rimangono invariate"
    echo ""
    echo -e "${YELLOW}Esempio conversioni:${NC}"
    echo -e "   ${GREEN}admin@example.com${NC} → username: ${GREEN}admin${NC}, ruolo: ${GREEN}admin${NC}"
    echo -e "   ${GREEN}mario.rossi@gmail.com${NC} → username: ${GREEN}mario.rossi${NC}, ruolo: ${GREEN}employee${NC}"
    echo -e "   ${GREEN}giovanni@site.it${NC} → username: ${GREEN}giovanni${NC}, ruolo: ${GREEN}employee${NC}"
    echo ""
    echo -e "${RED}ATTENZIONE: Questa operazione modifica il database!${NC}"
    echo -e "${GREEN}Un backup automatico verrà creato prima della migrazione.${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Vuoi eseguire la migrazione ora? [s/N] ${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo ""
        echo -e "${YELLOW}Esecuzione migrazione...${NC}"
        echo ""
        
        if [ -f "migrate_username_auth.js" ]; then
            # Esegui la migrazione
            node migrate_username_auth.js
            
            MIGRATION_EXIT=$?
            
            if [ $MIGRATION_EXIT -eq 0 ]; then
                echo ""
                echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║   ✓ Migrazione completata con successo!              ║${NC}"
                echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${MAGENTA}📋 IMPORTANTE - Credenziali aggiornate:${NC}"
                echo -e "   ${YELLOW}Gli utenti ora devono effettuare login con USERNAME (non più email)${NC}"
                echo ""
                echo -e "${YELLOW}Controlla il log della migrazione sopra per vedere:${NC}"
                echo -e "   ${BLUE}•${NC} Username generati per ogni utente"
                echo -e "   ${BLUE}•${NC} Ruoli assegnati (admin/employee)"
                echo -e "   ${BLUE}•${NC} Password invariate"
                echo ""
                echo -e "${YELLOW}Esempio: se l'email era ${GREEN}pippo@example.com${NC}${YELLOW}:${NC}"
                echo -e "   ${GREEN}Username:${NC} pippo"
                echo -e "   ${GREEN}Password:${NC} (stessa di prima)"
                echo ""
                echo -e "${MAGENTA}📝 Suggerimento:${NC}"
                echo -e "   Crea un file ${GREEN}CREDENZIALI_MIGRAZIONE.md${NC} con gli username generati"
                echo -e "   e comunicalo agli utenti per facilitare il primo accesso."
                echo ""
            else
                echo ""
                echo -e "${RED}✗ Errore durante la migrazione!${NC}"
                echo -e "${YELLOW}Il backup del database è disponibile in: ${BACKUP_NAME}${NC}"
                echo -e "${YELLOW}Controlla i messaggi di errore sopra e riprova.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}✗ File migrate_username_auth.js non trovato!${NC}"
            echo -e "${YELLOW}Assicurati di aver scaricato l'ultima versione del repository.${NC}"
            exit 1
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠ Migrazione rimandata${NC}"
        echo -e "${RED}ATTENZIONE: Il server NON funzionerà correttamente senza la migrazione!${NC}"
        echo -e "${YELLOW}Il nuovo codice si aspetta un database con colonne username e role.${NC}"
        echo ""
        echo -e "${YELLOW}Per eseguire la migrazione in seguito:${NC}"
        echo -e "   ${GREEN}cd ${PROJECT_DIR}${NC}"
        echo -e "   ${GREEN}node migrate_username_auth.js${NC}"
        echo ""
        read -p "$(echo -e ${YELLOW}Vuoi continuare comunque? [s/N] ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo -e "${RED}Aggiornamento annullato${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

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
echo -e "   ${GREEN}✓${NC} Codice server aggiornato alla v1.2.0"
echo -e "   ${GREEN}✓${NC} Dipendenze npm aggiornate"
echo -e "   ${GREEN}✓${NC} nodemailer verificato"
if [ -f "email_config.json.backup" ]; then
    echo -e "   ${GREEN}✓${NC} Configurazione email preservata"
fi
if [ -f "$BACKUP_NAME" ]; then
    echo -e "   ${GREEN}✓${NC} Backup database creato"
fi
if [ "$NEEDS_MIGRATION" = true ] && [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "   ${GREEN}✓${NC} Database migrato (username auth + ruoli)"
fi
echo ""
echo -e "${YELLOW}🆕 Nuove Funzionalità v1.2.0:${NC}"
echo -e "   ${GREEN}✓${NC} Autenticazione con username (non più email)"
echo -e "   ${GREEN}✓${NC} Sistema ruoli: Amministratore, Dipendente, Capocantiere"
echo -e "   ${GREEN}✓${NC} Pagina dedicata Capocantiere con report cantieri"
echo -e "   ${GREEN}✓${NC} Email opzionale per dipendenti (obbligatoria per admin)"
echo -e "   ${GREEN}✓${NC} Selezione data singola migliorata nei report"
echo -e "   ${GREEN}✓${NC} Messaggi UX migliorati per periodi vuoti"
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
echo -e "${YELLOW}📱 Aggiornamento App Flutter:${NC}"
echo -e "   ${RED}⚠${NC} ${YELLOW}Necessario aggiornare anche l'app Flutter!${NC}"
echo -e "   ${BLUE}•${NC} Scarica nuova versione dal repository"
echo -e "   ${BLUE}•${NC} Login ora richiede USERNAME (non email)"
echo -e "   ${BLUE}•${NC} Routing automatico in base al ruolo utente"
echo ""
if [ "$NEEDS_MIGRATION" = true ]; then
    echo -e "${YELLOW}👥 Comunicazione agli utenti:${NC}"
    echo -e "   ${MAGENTA}Gli utenti devono ora usare USERNAME per il login${NC}"
    echo -e "   ${BLUE}•${NC} Consulta il log della migrazione per gli username generati"
    echo -e "   ${BLUE}•${NC} Password rimangono invariate"
    echo -e "   ${BLUE}•${NC} Comunica gli username agli utenti"
    echo ""
fi
echo -e "${YELLOW}🧪 Test Consigliati:${NC}"
echo -e "   ${BLUE}1.${NC} Login con username di un amministratore"
echo -e "   ${BLUE}2.${NC} Creazione dipendente con ruolo Capocantiere"
echo -e "   ${BLUE}3.${NC} Login come Capocantiere e verifica report cantieri"
echo -e "   ${BLUE}4.${NC} Test selezione data singola nei report"
echo -e "   ${BLUE}5.${NC} Verifica ricerca dipendenti con email null"
echo ""
echo -e "${YELLOW}📚 Documentazione:${NC}"
echo -e "   ${GREEN}CHANGELOG_USERNAME_AUTH.md${NC} - Dettagli migrazione"
echo -e "   ${GREEN}CREDENZIALI_MIGRAZIONE.md${NC} - Template credenziali utenti"
echo -e "   ${GREEN}FIX_DATE_RANGE_SELECTION.md${NC} - Fix selezione date"
echo ""
echo -e "${GREEN}✨ Server aggiornato e pronto! ✨${NC}"
echo ""
