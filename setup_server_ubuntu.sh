#!/bin/bash

#######################################################################
# Script di Setup Server Ingresso/Uscita - VERSIONE UBUNTU DEFINITIVA
# 
# Compatibile con:
# - Ubuntu Server/Desktop (x64, ARM64)
# - Raspberry Pi OS (Raspberry Pi 5/4/3)
# - Debian-based distributions
#
# Funzionalità:
# - Nome servizio personalizzato (multi-istanza)
# - Porta personalizzata (3000, 3001, 3002...)
# - Database separati per ogni istanza
# - Configurazioni indipendenti
# - Gestione con systemd
#
# Uso: bash setup_server_ubuntu.sh
#######################################################################

set -e  # Esce in caso di errore

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║   ${BOLD}🚀 Setup Server Ingresso/Uscita v2.0.0${NC}${CYAN}                   ║${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║   ${GREEN}✓${NC} Ubuntu Server/Desktop (x64, ARM64)${CYAN}                     ║${NC}"
echo -e "${CYAN}║   ${GREEN}✓${NC} Raspberry Pi OS (Pi 5/4/3)${CYAN}                            ║${NC}"
echo -e "${CYAN}║   ${GREEN}✓${NC} Multi-istanza (server multipli su stesso host)${CYAN}        ║${NC}"
echo -e "${CYAN}║   ${GREEN}✓${NC} Porta personalizzata${CYAN}                                  ║${NC}"
echo -e "${CYAN}║   ${GREEN}✓${NC} Database separati${CYAN}                                     ║${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

#######################################################################
# FASE 1: RACCOLTA CONFIGURAZIONE
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  CONFIGURAZIONE ISTANZA${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Input nome servizio
echo -e "${YELLOW}📝 Nome del servizio (identifica questa istanza)${NC}"
echo -e "${BLUE}   Esempi: ${GREEN}produzione${NC}, ${GREEN}test${NC}, ${GREEN}cliente1${NC}, ${GREEN}magazzino${NC}"
echo -e "${BLUE}   Il servizio sarà chiamato: ${MAGENTA}ingresso-uscita-<NOME>${NC}"
echo ""

while true; do
    read -p "$(echo -e ${CYAN}Nome servizio: ${NC})" SERVICE_SUFFIX
    SERVICE_SUFFIX=$(echo "$SERVICE_SUFFIX" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    if [[ -z "$SERVICE_SUFFIX" ]]; then
        echo -e "${RED}✗ Il nome non può essere vuoto${NC}"
        continue
    fi
    
    if [[ ! "$SERVICE_SUFFIX" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${RED}✗ Usa solo lettere minuscole, numeri e trattini${NC}"
        continue
    fi
    
    SERVICE_NAME="ingresso-uscita-${SERVICE_SUFFIX}"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # Verifica se il servizio esiste già
    if systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
        echo -e "${RED}✗ Il servizio ${SERVICE_NAME} esiste già!${NC}"
        echo -e "${YELLOW}  Scegli un nome diverso o rimuovi il servizio esistente con:${NC}"
        echo -e "${YELLOW}  sudo systemctl stop ${SERVICE_NAME}${NC}"
        echo -e "${YELLOW}  sudo systemctl disable ${SERVICE_NAME}${NC}"
        echo -e "${YELLOW}  sudo rm ${SERVICE_FILE}${NC}"
        echo -e "${YELLOW}  sudo systemctl daemon-reload${NC}"
        echo ""
        continue
    fi
    
    break
done

echo -e "${GREEN}✓ Nome servizio: ${BOLD}${SERVICE_NAME}${NC}"
echo ""

# Input porta
echo -e "${YELLOW}🔌 Porta di rete${NC}"
echo -e "${BLUE}   Esempi: ${GREEN}3000${NC} (default), ${GREEN}3001${NC}, ${GREEN}3002${NC}..."
echo -e "${BLUE}   Ogni istanza deve usare una porta diversa!${NC}"
echo ""

# Mostra servizi esistenti e le loro porte
EXISTING_SERVICES=$(systemctl list-unit-files | grep "^ingresso-uscita-" | cut -d'.' -f1 || true)
if [ -n "$EXISTING_SERVICES" ]; then
    echo -e "${CYAN}📋 Servizi esistenti:${NC}"
    while IFS= read -r svc; do
        if [ -f "/etc/systemd/system/${svc}.service" ]; then
            PORT=$(grep "Environment=PORT=" "/etc/systemd/system/${svc}.service" | cut -d'=' -f3 || echo "N/A")
            echo -e "   ${BLUE}•${NC} ${svc} ${YELLOW}→${NC} porta ${MAGENTA}${PORT}${NC}"
        fi
    done <<< "$EXISTING_SERVICES"
    echo ""
fi

while true; do
    read -p "$(echo -e ${CYAN}Porta \[default: 3000\]: ${NC})" SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-3000}
    
    if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}✗ La porta deve essere un numero${NC}"
        continue
    fi
    
    if [ "$SERVER_PORT" -lt 1024 ] || [ "$SERVER_PORT" -gt 65535 ]; then
        echo -e "${RED}✗ La porta deve essere tra 1024 e 65535${NC}"
        continue
    fi
    
    # Verifica se la porta è già in uso
    if ss -tuln | grep -q ":${SERVER_PORT} "; then
        echo -e "${RED}✗ La porta ${SERVER_PORT} è già in uso!${NC}"
        echo -e "${YELLOW}  Porte in uso:${NC}"
        ss -tuln | grep "LISTEN" | awk '{print "   " $5}' | sort -u
        echo ""
        continue
    fi
    
    break
done

echo -e "${GREEN}✓ Porta: ${BOLD}${SERVER_PORT}${NC}"
echo ""

# Riepilogo configurazione
echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${MAGENTA}  RIEPILOGO CONFIGURAZIONE${NC}"
echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Nome servizio:${NC}    ${GREEN}${SERVICE_NAME}${NC}"
echo -e "${CYAN}Porta:${NC}            ${GREEN}${SERVER_PORT}${NC}"
echo -e "${CYAN}Directory:${NC}        ${GREEN}$HOME/ingresso_uscita_${SERVICE_SUFFIX}${NC}"
echo -e "${CYAN}Database:${NC}        ${GREEN}ingresso_uscita_${SERVICE_SUFFIX}.db${NC}"
echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Confermi la configurazione? [S/n]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]?$ ]]; then
    echo -e "${RED}✗ Setup annullato${NC}"
    exit 1
fi

echo ""

#######################################################################
# FASE 2: VERIFICA SISTEMA
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  VERIFICA SISTEMA${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Verifica sistema operativo
echo -e "${YELLOW}[1/10] Verifica sistema operativo...${NC}"
ARCH=$(uname -m)
OS=$(uname -s)

echo -e "${BLUE}Sistema:${NC} ${OS} (${ARCH})"

if [[ "$OS" != "Linux" ]]; then
    echo -e "${RED}✗ Questo script richiede Linux${NC}"
    exit 1
fi

# Identifica tipo di sistema
if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
    echo -e "${GREEN}✓ Architettura ARM64 rilevata (Raspberry Pi 5/4)${NC}"
    IS_ARM=true
elif [[ "$ARCH" == "armv7l" ]]; then
    echo -e "${GREEN}✓ Architettura ARM32 rilevata (Raspberry Pi 3/2)${NC}"
    IS_ARM=true
elif [[ "$ARCH" == "x86_64" ]]; then
    echo -e "${GREEN}✓ Architettura x86_64 rilevata${NC}"
    IS_ARM=false
else
    echo -e "${YELLOW}⚠ Architettura non standard: ${ARCH}${NC}"
    IS_ARM=false
fi

# Identifica distribuzione
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${BLUE}Distribuzione:${NC} ${NAME} ${VERSION}"
fi

echo ""

#######################################################################
# FASE 3: INSTALLAZIONE DIPENDENZE SISTEMA
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  INSTALLAZIONE DIPENDENZE SISTEMA${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[2/10] Aggiornamento repository e installazione build tools...${NC}"
echo -e "${BLUE}Questo passaggio può richiedere qualche minuto...${NC}"

sudo apt-get update -qq
sudo apt-get install -y \
    build-essential \
    python3 \
    git \
    sqlite3 \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

echo -e "${GREEN}✓ Build tools installati${NC}"
echo ""

#######################################################################
# FASE 4: INSTALLAZIONE NODE.JS
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  INSTALLAZIONE NODE.JS${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[3/10] Verifica/Installazione Node.js LTS...${NC}"

NODE_INSTALLED=false

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    NODE_MAJOR=$(node -v | cut -d'.' -f1 | sed 's/v//')
    
    if [ "$NODE_MAJOR" -ge 18 ]; then
        echo -e "${GREEN}✓ Node.js ${NODE_VERSION} già installato (compatibile)${NC}"
        NODE_INSTALLED=true
    else
        echo -e "${YELLOW}⚠ Node.js ${NODE_VERSION} è obsoleto (richiesto v18+)${NC}"
        echo -e "${YELLOW}  Aggiornamento in corso...${NC}"
    fi
fi

if [ "$NODE_INSTALLED" = false ]; then
    echo -e "${YELLOW}Installazione Node.js 20 LTS...${NC}"
    
    # Rimuovi vecchie configurazioni NodeSource
    sudo rm -f /etc/apt/sources.list.d/nodesource.list
    sudo rm -f /usr/share/keyrings/nodesource.gpg
    
    # Installa Node.js 20 LTS
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js ${NODE_VERSION} installato con successo${NC}"
fi

NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm versione: ${NPM_VERSION}${NC}"
echo ""

#######################################################################
# FASE 5: CREAZIONE DIRECTORY PROGETTO
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  CREAZIONE DIRECTORY PROGETTO${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[4/10] Creazione directory del progetto...${NC}"
PROJECT_DIR="$HOME/ingresso_uscita_${SERVICE_SUFFIX}"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ La directory ${PROJECT_DIR} esiste già${NC}"
    read -p "$(echo -e ${YELLOW}Sovrascrivere? [s/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        BACKUP_DIR="${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Backup della directory esistente...${NC}"
        mv "$PROJECT_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}✓ Backup creato in: ${BACKUP_DIR}${NC}"
    else
        echo -e "${RED}✗ Installazione annullata${NC}"
        exit 1
    fi
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
echo -e "${GREEN}✓ Directory creata: ${PROJECT_DIR}${NC}"
echo ""

#######################################################################
# FASE 6: DOWNLOAD FILES DA REPOSITORY
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  DOWNLOAD FILES DA GITHUB${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[5/10] Download dei file dal repository...${NC}"
echo -e "${BLUE}Repository: https://github.com/fragarray/ingresso_uscita${NC}"

# Inizializza repository Git
git init
git remote add origin https://github.com/fragarray/ingresso_uscita.git
git config core.sparseCheckout true

# Configura sparse checkout per scaricare TUTTA la cartella server
echo "server/**" > .git/info/sparse-checkout

# Scarica i file
echo -e "${YELLOW}Download in corso...${NC}"
if ! git pull origin main; then
    echo -e "${RED}✗ Errore durante il download dal repository${NC}"
    echo -e "${YELLOW}Verifica la connessione internet e riprova${NC}"
    exit 1
fi

# Verifica che la cartella server sia stata scaricata
if [ ! -d "server" ]; then
    echo -e "${RED}✗ Errore: la cartella server non è stata scaricata${NC}"
    exit 1
fi

# Conta i file nella cartella server
FILE_COUNT=$(find server -type f | wc -l)
echo -e "${BLUE}File scaricati: ${FILE_COUNT}${NC}"

# Sposta tutti i file preservando la struttura
shopt -s dotglob
mv server/* . 2>/dev/null || true
shopt -u dotglob

# Verifica che i file siano stati spostati
if [ ! -f "server.js" ]; then
    echo -e "${RED}✗ Errore: file non spostati correttamente${NC}"
    exit 1
fi

# Rimuovi cartella server vuota e .git
rm -rf server .git

echo -e "${GREEN}✓ File scaricati e organizzati con successo${NC}"
echo ""

#######################################################################
# FASE 7: CONFIGURAZIONE PORTA NEL CODICE
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  CONFIGURAZIONE PORTA${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[6/10] Configurazione porta nel server...${NC}"

# Modifica config.js per usare la porta personalizzata
if [ -f "config.js" ]; then
    # Backup del file originale
    cp config.js config.js.bak
    
    # Sostituisci la porta nel file config.js
    sed -i "s/const PORT = process.env.PORT || [0-9]\+/const PORT = process.env.PORT || ${SERVER_PORT}/" config.js
    
    echo -e "${GREEN}✓ Porta ${SERVER_PORT} configurata in config.js${NC}"
else
    echo -e "${YELLOW}⚠ config.js non trovato, verrà usata variabile d'ambiente${NC}"
fi

# Rinomina il database per l'istanza specifica
DB_NAME="ingresso_uscita_${SERVICE_SUFFIX}.db"
echo -e "${GREEN}✓ Nome database: ${DB_NAME}${NC}"

# Modifica db.js per usare il database specifico
if [ -f "db.js" ]; then
    cp db.js db.js.bak
    sed -i "s/ingresso_uscita\.db/${DB_NAME}/" db.js
    echo -e "${GREEN}✓ Database configurato in db.js${NC}"
fi

echo ""

#######################################################################
# FASE 8: INSTALLAZIONE DIPENDENZE NPM
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  INSTALLAZIONE DIPENDENZE NPM${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[7/10] Installazione dipendenze npm...${NC}"
echo -e "${BLUE}Questo passaggio può richiedere 5-10 minuti su Raspberry Pi...${NC}"

if [ "$IS_ARM" = true ]; then
    echo -e "${YELLOW}⚠ Sistema ARM: alcune dipendenze verranno compilate${NC}"
fi

echo ""
npm install --production

echo ""
echo -e "${GREEN}✓ Installazione npm completata${NC}"

# Verifica dipendenze critiche
echo -e "${YELLOW}Verifica dipendenze critiche...${NC}"

MISSING_DEPS=0

if npm list sqlite3 &> /dev/null; then
    echo -e "${GREEN}✓ sqlite3${NC}"
else
    echo -e "${RED}✗ sqlite3 - tentativo rebuild...${NC}"
    npm rebuild sqlite3 --build-from-source
    MISSING_DEPS=$((MISSING_DEPS + 1))
fi

if npm list express &> /dev/null; then
    echo -e "${GREEN}✓ express${NC}"
else
    echo -e "${RED}✗ express mancante${NC}"
    MISSING_DEPS=$((MISSING_DEPS + 1))
fi

if npm list nodemailer &> /dev/null; then
    echo -e "${GREEN}✓ nodemailer${NC}"
else
    echo -e "${YELLOW}⚠ nodemailer - reinstallazione...${NC}"
    npm install nodemailer@6.9.7
fi

if npm list exceljs &> /dev/null; then
    echo -e "${GREEN}✓ exceljs${NC}"
else
    echo -e "${YELLOW}⚠ exceljs - reinstallazione...${NC}"
    npm install exceljs@4.4.0
fi

if npm list pdfkit &> /dev/null; then
    echo -e "${GREEN}✓ pdfkit${NC}"
else
    echo -e "${YELLOW}⚠ pdfkit - reinstallazione...${NC}"
    npm install pdfkit@0.15.0
fi

if [ $MISSING_DEPS -gt 0 ]; then
    echo -e "${RED}✗ Alcune dipendenze critiche mancano. Verifica i log sopra.${NC}"
    exit 1
fi

echo ""

#######################################################################
# FASE 9: CONFIGURAZIONE FILE DI SISTEMA
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  CONFIGURAZIONE FILE DI SISTEMA${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[8/10] Configurazione file di sistema...${NC}"

# Crea directory necessarie
mkdir -p reports
mkdir -p backups
mkdir -p temp
mkdir -p routes

echo -e "${GREEN}✓ Directory create${NC}"

# Crea email_config.json se non esiste
if [ ! -f "email_config.json" ]; then
    cat > email_config.json <<EOF
{
  "emailEnabled": false,
  "smtpHost": "smtp.gmail.com",
  "smtpPort": 587,
  "smtpSecure": false,
  "smtpUser": "your-email@gmail.com",
  "smtpPassword": "your-app-password",
  "fromEmail": "your-email@gmail.com",
  "fromName": "Sistema Timbrature - ${SERVICE_SUFFIX}",
  "dailyReportEnabled": false,
  "dailyReportTime": "00:05"
}
EOF
    echo -e "${GREEN}✓ email_config.json creato${NC}"
    echo -e "${MAGENTA}  ⚠ Modifica email_config.json per abilitare notifiche email${NC}"
else
    echo -e "${GREEN}✓ email_config.json già presente${NC}"
fi

# Crea backup_settings.json
if [ ! -f "backup_settings.json" ]; then
    cat > backup_settings.json <<EOF
{
  "enabled": true,
  "schedule": "0 2 * * *",
  "maxBackups": 30,
  "backupPath": "./backups"
}
EOF
    echo -e "${GREEN}✓ backup_settings.json creato${NC}"
fi

# Crea .gitignore
cat > .gitignore <<EOF
# Configurazione email con credenziali
email_config.json

# Database
*.db
*.db-journal
*.db-shm
*.db-wal

# Node modules
node_modules/

# Log files
*.log
npm-debug.log*

# Backup
backups/*.db

# Temporary files
temp/
*.tmp

# Reports
reports/*.xlsx
reports/*.pdf

# Sistema operativo
.DS_Store
Thumbs.db

# Backup originali
*.bak
EOF
echo -e "${GREEN}✓ .gitignore creato${NC}"

echo ""

#######################################################################
# FASE 10: CREAZIONE SERVIZIO SYSTEMD
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  CREAZIONE SERVIZIO SYSTEMD${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[9/10] Creazione servizio systemd...${NC}"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Server Ingresso/Uscita - ${SERVICE_SUFFIX}
Documentation=https://github.com/fragarray/ingresso_uscita
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which node) $PROJECT_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Variabili d'ambiente
Environment=NODE_ENV=production
Environment=PORT=${SERVER_PORT}

# Limiti di sicurezza
LimitNOFILE=4096
LimitNPROC=512

[Install]
WantedBy=multi-user.target
EOF

# Ricarica systemd
sudo systemctl daemon-reload

echo -e "${GREEN}✓ Servizio systemd creato${NC}"
echo -e "${BLUE}  Nome servizio: ${BOLD}${SERVICE_NAME}${NC}"
echo -e "${BLUE}  File: ${SERVICE_FILE}${NC}"
echo ""

#######################################################################
# FASE 11: TEST AVVIO
#######################################################################

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  TEST AVVIO SERVER${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}[10/10] Test avvio server...${NC}"

# Test sintassi
if node -c server.js; then
    echo -e "${GREEN}✓ server.js sintatticamente corretto${NC}"
else
    echo -e "${RED}✗ Errore di sintassi in server.js${NC}"
    exit 1
fi

# Test avvio rapido
echo -e "${YELLOW}Test avvio rapido (5 secondi)...${NC}"
PORT=$SERVER_PORT timeout 5 node server.js > /tmp/server_test_${SERVICE_SUFFIX}.log 2>&1 &
SERVER_PID=$!
sleep 3

# Test connessione
if curl -s http://localhost:${SERVER_PORT}/api/ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server funzionante (ping superato)${NC}"
else
    echo -e "${YELLOW}⚠ Test ping non riuscito (normale se endpoint non esiste ancora)${NC}"
fi

# Ferma il test
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo -e "${GREEN}✓ Test completato${NC}"
echo ""

#######################################################################
# FASE 12: CONFIGURAZIONE FINALE
#######################################################################

# Ottieni indirizzo IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                                                               ║${NC}"
echo -e "${BOLD}${GREEN}║   ✓ SETUP COMPLETATO CON SUCCESSO!                           ║${NC}"
echo -e "${BOLD}${GREEN}║                                                               ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  INFORMAZIONI ISTANZA${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Nome servizio:${NC}     ${GREEN}${BOLD}${SERVICE_NAME}${NC}"
echo -e "${YELLOW}Porta:${NC}             ${GREEN}${BOLD}${SERVER_PORT}${NC}"
echo -e "${YELLOW}Directory:${NC}         ${GREEN}${PROJECT_DIR}${NC}"
echo -e "${YELLOW}Database:${NC}          ${GREEN}${DB_NAME}${NC}"
echo -e "${YELLOW}Indirizzo IP:${NC}      ${GREEN}${BOLD}${IP_ADDRESS}${NC}"
echo -e "${YELLOW}URL completo:${NC}      ${GREEN}${BOLD}http://${IP_ADDRESS}:${SERVER_PORT}${NC}"
echo ""

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  COMANDI GESTIONE SERVIZIO${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Avvia server:${NC}"
echo -e "  ${GREEN}sudo systemctl start ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Ferma server:${NC}"
echo -e "  ${GREEN}sudo systemctl stop ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Riavvia server:${NC}"
echo -e "  ${GREEN}sudo systemctl restart ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Stato server:${NC}"
echo -e "  ${GREEN}sudo systemctl status ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Abilita avvio automatico:${NC}"
echo -e "  ${GREEN}sudo systemctl enable ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Disabilita avvio automatico:${NC}"
echo -e "  ${GREEN}sudo systemctl disable ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}Log in tempo reale:${NC}"
echo -e "  ${GREEN}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
echo ""
echo -e "${YELLOW}Ultimi 100 log:${NC}"
echo -e "  ${GREEN}sudo journalctl -u ${SERVICE_NAME} -n 100${NC}"
echo ""

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  CONFIGURAZIONE APP FLUTTER${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}1. Apri l'app sul dispositivo mobile${NC}"
echo -e "${YELLOW}2. Al primo avvio, configura:${NC}"
echo -e "   ${CYAN}Indirizzo IP:${NC}  ${GREEN}${BOLD}${IP_ADDRESS}${NC}"
echo -e "   ${CYAN}Porta:${NC}         ${GREEN}${BOLD}${SERVER_PORT}${NC}"
echo ""
echo -e "${YELLOW}3. Credenziali admin di default (CAMBIARE SUBITO!):${NC}"
echo -e "   ${CYAN}Username:${NC}  ${GREEN}admin${NC}"
echo -e "   ${CYAN}Password:${NC}  ${GREEN}admin123${NC}"
echo ""

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  PROSSIMI PASSI${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Chiedi se abilitare avvio automatico
read -p "$(echo -e ${YELLOW}Vuoi abilitare l\'avvio automatico del server? [S/n]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]?$ ]]; then
    sudo systemctl enable "$SERVICE_NAME"
    echo -e "${GREEN}✓ Avvio automatico abilitato${NC}"
fi
echo ""

# Chiedi se avviare ora
read -p "$(echo -e ${YELLOW}Vuoi avviare il server ORA? [S/n]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]?$ ]]; then
    echo -e "${YELLOW}Avvio del server in corso...${NC}"
    sudo systemctl start "$SERVICE_NAME"
    sleep 3
    
    # Verifica stato
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Server avviato con successo!${NC}"
        echo ""
        echo -e "${YELLOW}Verifica stato:${NC}"
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
        echo ""
        echo -e "${BOLD}${MAGENTA}🎉 Il server è ATTIVO e in ascolto su porta ${SERVER_PORT}!${NC}"
        echo -e "${MAGENTA}📱 Configura l'app Flutter con: ${GREEN}${IP_ADDRESS}:${SERVER_PORT}${NC}"
    else
        echo -e "${RED}✗ Errore durante l'avvio${NC}"
        echo -e "${YELLOW}Verifica i log con:${NC}"
        echo -e "  ${GREEN}sudo journalctl -u ${SERVICE_NAME} -n 50${NC}"
    fi
else
    echo -e "${YELLOW}Server non avviato. Avvia manualmente quando sei pronto:${NC}"
    echo -e "  ${GREEN}sudo systemctl start ${SERVICE_NAME}${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  INFORMAZIONI AGGIUNTIVE${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📧 Configurazione email:${NC}"
echo -e "   ${GREEN}nano ${PROJECT_DIR}/email_config.json${NC}"
echo ""
echo -e "${YELLOW}🔥 Configurazione firewall (se necessario):${NC}"
echo -e "   ${GREEN}sudo ufw allow ${SERVER_PORT}/tcp${NC}"
echo -e "   ${GREEN}sudo ufw enable${NC}"
echo ""
echo -e "${YELLOW}📚 Documentazione completa:${NC}"
echo -e "   ${GREEN}${PROJECT_DIR}/README.md${NC}"
echo ""
echo -e "${YELLOW}🔍 File di log:${NC}"
echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
echo ""

echo -e "${BOLD}${GREEN}✨ Setup completato! Buon lavoro! ✨${NC}"
echo ""
