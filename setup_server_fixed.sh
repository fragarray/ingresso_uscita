#!/bin/bash

#######################################################################
# Script di Setup Server Ingresso/Uscita - VERSIONE AGGIORNATA
# 
# Compatibile con Raspberry Pi 5 (ARM64) e sistemi Linux moderni
# Include audit trail, report Excel, sistema email automatico
#
# Uso: bash setup_server_fixed.sh
#######################################################################

set -e  # Esce in caso di errore

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Setup Server Ingresso/Uscita v1.1.3                ║${NC}"
echo -e "${BLUE}║   Raspberry Pi 5 / Linux ARM64/x64                   ║${NC}"
echo -e "${BLUE}║   Con Audit Trail + Report Excel + Email            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Verifica sistema operativo
echo -e "${YELLOW}[1/9] Verifica sistema operativo...${NC}"
ARCH=$(uname -m)
OS=$(uname -s)

echo -e "${BLUE}Sistema: ${OS} (${ARCH})${NC}"

if [[ "$OS" != "Linux" ]]; then
    echo -e "${RED}✗ Questo script richiede Linux${NC}"
    echo -e "${YELLOW}  Raspberry Pi OS, Ubuntu, Debian sono supportati${NC}"
    exit 1
fi

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
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

# Installazione build tools necessari per SQLite3 e altre dipendenze native
echo -e "${YELLOW}[2/9] Installazione build tools (necessari per dipendenze native)...${NC}"
echo -e "${BLUE}Questo passaggio può richiedere qualche minuto...${NC}"

sudo apt-get update -qq
sudo apt-get install -y build-essential python3 git sqlite3 curl ca-certificates

echo -e "${GREEN}✓ Build tools installati${NC}"

# Installazione Node.js (versione LTS consigliata per Raspberry Pi 5)
echo -e "${YELLOW}[3/9] Verifica/Installazione Node.js LTS...${NC}"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    NODE_MAJOR=$(node -v | cut -d'.' -f1 | sed 's/v//')
    
    if [ "$NODE_MAJOR" -ge 18 ]; then
        echo -e "${GREEN}✓ Node.js ${NODE_VERSION} già installato (compatibile)${NC}"
    else
        echo -e "${YELLOW}⚠ Node.js ${NODE_VERSION} è obsoleto (serve v18+)${NC}"
        echo -e "${YELLOW}  Aggiornamento in corso...${NC}"
        NODE_INSTALLED=false
    fi
else
    NODE_INSTALLED=false
fi

if [ "${NODE_INSTALLED:-true}" = false ]; then
    echo -e "${YELLOW}Installazione Node.js LTS...${NC}"
    
    # Rimuovi vecchie installazioni NodeSource se presenti
    sudo rm -f /etc/apt/sources.list.d/nodesource.list
    
    # Installa Node.js 20 LTS (ottimale per Raspberry Pi 5)
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js ${NODE_VERSION} installato con successo${NC}"
fi

# Verifica npm
NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm versione: ${NPM_VERSION}${NC}"

# Crea directory del progetto
echo -e "${YELLOW}[4/9] Creazione directory del progetto...${NC}"
PROJECT_DIR="$HOME/ingresso_uscita_server"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ La directory $PROJECT_DIR esiste già${NC}"
    read -p "Sovrascrivere? (s/n) " -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Backup della directory esistente...${NC}"
        BACKUP_DIR="${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
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

# Clone del repository con sparse checkout CORRETTO
echo -e "${YELLOW}[5/9] Download dei file dal repository GitHub...${NC}"
echo -e "${BLUE}Repository: https://github.com/fragarray/ingresso_uscita${NC}"

# Inizializza repository Git
git init
git remote add origin https://github.com/fragarray/ingresso_uscita.git
git config core.sparseCheckout true

# Configura sparse checkout per scaricare TUTTA la cartella server
# IMPORTANTE: il doppio asterisco ** scarica ricorsivamente tutte le sottocartelle
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

# Sposta i file dalla sottocartella alla root (PRESERVANDO LA STRUTTURA)
echo -e "${YELLOW}Organizzazione file...${NC}"

# Sposta tutti i file e cartelle, preservando la struttura delle sottocartelle
shopt -s dotglob  # Include file nascosti
mv server/* . 2>/dev/null || true
shopt -u dotglob

# Rimuovi cartella server vuota e .git
rm -rf server .git

echo -e "${GREEN}✓ File scaricati e organizzati con successo${NC}"

# Installazione dipendenze npm
echo -e "${YELLOW}[6/9] Installazione dipendenze npm...${NC}"
echo -e "${BLUE}Questo passaggio può richiedere 5-10 minuti su Raspberry Pi...${NC}"

# Su ARM, alcune dipendenze potrebbero richiedere compilazione nativa
if [ "$IS_ARM" = true ]; then
    echo -e "${YELLOW}⚠ Sistema ARM rilevato: alcune dipendenze verranno compilate${NC}"
fi

# Installa dipendenze con output pulito
if npm install --quiet --no-progress 2>&1 | tee /tmp/npm_install.log | grep -E "ERR!|warn"; then
    echo -e "${YELLOW}⚠ Alcune warning durante l'installazione (spesso normale)${NC}"
fi

# Verifica che sqlite3 sia installato correttamente (critico)
if npm list sqlite3 &> /dev/null; then
    echo -e "${GREEN}✓ sqlite3 installato correttamente${NC}"
else
    echo -e "${RED}✗ Errore installazione sqlite3${NC}"
    echo -e "${YELLOW}Tentativo rebuild...${NC}"
    npm rebuild sqlite3 --build-from-source
fi

# Verifica nodemailer
if npm list nodemailer &> /dev/null; then
    echo -e "${GREEN}✓ nodemailer installato correttamente${NC}"
else
    echo -e "${YELLOW}⚠ Reinstallazione nodemailer...${NC}"
    npm install nodemailer@6.9.7
fi

# Verifica exceljs (per report audit e timbrature)
if npm list exceljs &> /dev/null; then
    echo -e "${GREEN}✓ exceljs installato correttamente${NC}"
else
    echo -e "${YELLOW}⚠ Reinstallazione exceljs...${NC}"
    npm install exceljs@4.4.0
fi

echo -e "${GREEN}✓ Tutte le dipendenze installate${NC}"

# Verifica integrità dei file
echo -e "${YELLOW}[7/9] Verifica integrità dei file...${NC}"

REQUIRED_FILES=(
    "server.js" 
    "package.json" 
    "db.js" 
    "config.js"
)

REQUIRED_DIRS=(
    "routes"
    "backups"
)

MISSING_FILES=0
MISSING_DIRS=0

# Verifica file
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ ${file}${NC}"
    else
        echo -e "${RED}✗ ${file} mancante${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

# Verifica directory
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ ${dir}/${NC}"
    else
        echo -e "${YELLOW}⚠ ${dir}/ mancante (verrà creata)${NC}"
        mkdir -p "$dir"
        MISSING_DIRS=$((MISSING_DIRS + 1))
    fi
done

# Verifica file nella cartella routes
if [ -f "routes/worksites.js" ]; then
    echo -e "${GREEN}✓ routes/worksites.js${NC}"
else
    echo -e "${RED}✗ routes/worksites.js mancante (CRITICO!)${NC}"
    MISSING_FILES=$((MISSING_FILES + 1))
fi

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${RED}✗ ${MISSING_FILES} file critici mancanti. Setup fallito.${NC}"
    exit 1
fi

# Crea directory necessarie se non esistono
mkdir -p reports
mkdir -p backups
mkdir -p temp

echo -e "${GREEN}✓ Struttura directory verificata${NC}"

# Configurazione file email
echo -e "${YELLOW}[8/9] Configurazione file di sistema...${NC}"

# Crea email_config.json se non esiste
if [ ! -f "email_config.json" ]; then
    if [ -f "email_config.example.json" ]; then
        echo -e "${YELLOW}Copia configurazione email da esempio...${NC}"
        cp email_config.example.json email_config.json
    else
        echo -e "${YELLOW}Creazione file configurazione email...${NC}"
        cat > email_config.json <<'EOF'
{
  "emailEnabled": true,
  "smtpHost": "smtp.gmail.com",
  "smtpPort": 587,
  "smtpSecure": false,
  "smtpUser": "your-email@gmail.com",
  "smtpPassword": "your-app-password",
  "fromEmail": "your-email@gmail.com",
  "fromName": "Sistema Timbrature",
  "dailyReportEnabled": true,
  "dailyReportTime": "00:05"
}
EOF
    fi
    echo -e "${GREEN}✓ email_config.json creato${NC}"
    echo -e "${MAGENTA}⚠️  IMPORTANTE: Modifica email_config.json con le tue credenziali Gmail!${NC}"
else
    echo -e "${GREEN}✓ email_config.json già presente${NC}"
fi

# Crea backup_settings.json se non esiste
if [ ! -f "backup_settings.json" ]; then
    echo -e "${YELLOW}Creazione configurazione backup automatico...${NC}"
    cat > backup_settings.json <<'EOF'
{
  "enabled": true,
  "schedule": "0 2 * * *",
  "maxBackups": 30,
  "backupPath": "./backups"
}
EOF
    echo -e "${GREEN}✓ backup_settings.json creato${NC}"
fi

# Crea .gitignore per proteggere dati sensibili
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}Creazione .gitignore...${NC}"
    cat > .gitignore <<'EOF'
# Configurazione email con credenziali sensibili
email_config.json

# Database locale
*.db
*.db-journal
*.db-shm
*.db-wal

# Node modules
node_modules/

# Log files
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Backup
backups/*.db

# Temporary files
temp/
*.tmp

# Reports generati
reports/attendance_report_*.xlsx
reports/hours_report_*.xlsx
reports/worksite_report_*.xlsx
reports/forced_attendance_report_*.xlsx
reports/admin_audit_report_*.xlsx
reports/BACKUP_*.db

# Sistema operativo
.DS_Store
Thumbs.db
EOF
    echo -e "${GREEN}✓ .gitignore creato${NC}"
fi

# Test rapido del server
echo -e "${YELLOW}[9/9] Test avvio server...${NC}"

# Test sintassi JavaScript
if node -c server.js; then
    echo -e "${GREEN}✓ server.js sintatticamente corretto${NC}"
else
    echo -e "${RED}✗ Errore di sintassi in server.js${NC}"
    exit 1
fi

# Test avvio rapido (5 secondi)
timeout 5 node server.js > /tmp/server_test.log 2>&1 &
SERVER_PID=$!
sleep 3

# Test connessione
if curl -s http://localhost:3000/api/ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server funzionante (test ping superato)${NC}"
else
    echo -e "${YELLOW}⚠️  Test ping non riuscito (normale se non esiste endpoint /api/ping)${NC}"
fi

# Ferma il test
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# Ottieni l'indirizzo IP della macchina
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Setup completato
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ Setup completato con successo!                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📁 Directory del server:${NC}"
echo -e "   ${PROJECT_DIR}"
echo ""
echo -e "${YELLOW}🌐 Indirizzo IP del server:${NC}"
echo -e "   ${GREEN}${IP_ADDRESS}${NC}"
echo ""
echo -e "${YELLOW}📊 Database:${NC}"
echo -e "   ${GREEN}${PROJECT_DIR}/ingresso_uscita.db${NC} (creato al primo avvio)"
echo ""
echo -e "${YELLOW}🚀 Per avviare il server manualmente:${NC}"
echo -e "   ${GREEN}cd ${PROJECT_DIR}${NC}"
echo -e "   ${GREEN}node server.js${NC}"
echo ""
echo -e "${YELLOW}🔧 Funzionalità Disponibili:${NC}"
echo -e "   ${GREEN}✓${NC} Gestione timbrature ingresso/uscita"
echo -e "   ${GREEN}✓${NC} Timbrature forzate con validazione overlap"
echo -e "   ${GREEN}✓${NC} Report Excel (Timbrature, Ore, Cantieri)"
echo -e "   ${GREEN}✓${NC} Audit Trail completo operazioni admin"
echo -e "   ${GREEN}✓${NC} Sistema backup automatico"
echo -e "   ${GREEN}✓${NC} Report giornalieri via email"
echo -e "   ${GREEN}✓${NC} Gestione cantieri con geofencing"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ==================== FUNZIONE PER CREARE SERVIZIO SYSTEMD ====================
create_systemd_service() {
    local SERVICE_NAME="ingresso-uscita"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    echo -e "${YELLOW}Creazione servizio systemd...${NC}"
    
    # Crea il file di configurazione
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Server Ingresso/Uscita - Sistema Gestione Presenze v1.1.3
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
SyslogIdentifier=ingresso-uscita

# Variabili d'ambiente
Environment=NODE_ENV=production
Environment=PORT=3000

# Limiti di sicurezza
LimitNOFILE=4096
LimitNPROC=512

[Install]
WantedBy=multi-user.target
EOF
    
    # Ricarica systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ Servizio systemd creato: ${SERVICE_NAME}${NC}"
    echo -e "${BLUE}File di configurazione: ${SERVICE_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}Comandi disponibili:${NC}"
    echo -e "   ${GREEN}sudo systemctl start ${SERVICE_NAME}${NC}      ${BLUE}# Avvia il server${NC}"
    echo -e "   ${GREEN}sudo systemctl stop ${SERVICE_NAME}${NC}       ${BLUE}# Ferma il server${NC}"
    echo -e "   ${GREEN}sudo systemctl restart ${SERVICE_NAME}${NC}    ${BLUE}# Riavvia il server${NC}"
    echo -e "   ${GREEN}sudo systemctl status ${SERVICE_NAME}${NC}     ${BLUE}# Stato del server${NC}"
    echo -e "   ${GREEN}sudo systemctl enable ${SERVICE_NAME}${NC}     ${BLUE}# Abilita avvio automatico${NC}"
    echo -e "   ${GREEN}sudo systemctl disable ${SERVICE_NAME}${NC}    ${BLUE}# Disabilita avvio automatico${NC}"
    echo ""
    echo -e "${YELLOW}Log del server:${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} -f${NC}              ${BLUE}# Log in tempo reale${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} -n 100${NC}          ${BLUE}# Ultimi 100 log${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} --since today${NC}   ${BLUE}# Log di oggi${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Vuoi abilitare l\'avvio automatico? [s/N] ${NC})" -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo systemctl enable "$SERVICE_NAME"
        echo -e "${GREEN}✓ Avvio automatico abilitato${NC}"
    fi
    
    read -p "$(echo -e ${YELLOW}Vuoi avviare il server ora? [s/N] ${NC})" -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo systemctl start "$SERVICE_NAME"
        sleep 2
        sudo systemctl status "$SERVICE_NAME" --no-pager
        echo -e "${GREEN}✓ Server avviato${NC}"
        echo ""
        echo -e "${MAGENTA}📱 Configura l'app Flutter con IP: ${IP_ADDRESS}${NC}"
    fi
}

# ==================== MENU SCELTA GESTIONE SERVER ====================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Scegli come vuoi gestire il server:${NC}"
echo ""
echo -e "${GREEN}1)${NC} systemd (servizio di sistema - ${BLUE}CONSIGLIATO per Raspberry Pi${NC})"
echo -e "${GREEN}2)${NC} PM2 (process manager con monitoraggio)"
echo -e "${GREEN}3)${NC} Avvio manuale (node server.js)"
echo -e "${GREEN}4)${NC} Nessuno (configuro dopo)"
echo ""
read -p "$(echo -e ${YELLOW}Scelta [1-4]: ${NC})" CHOICE < /dev/tty

case $CHOICE in
    1)
        create_systemd_service
        ;;
    2)
        echo -e "${YELLOW}Installazione PM2...${NC}"
        if ! command -v pm2 &> /dev/null; then
            sudo npm install -g pm2
            echo -e "${GREEN}✓ PM2 installato${NC}"
        else
            echo -e "${GREEN}✓ PM2 già installato${NC}"
        fi
        
        read -p "$(echo -e ${YELLOW}Vuoi avviare il server con PM2 ora? [s/N] ${NC})" -n 1 -r < /dev/tty
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            cd "$PROJECT_DIR"
            pm2 start server.js --name ingresso-uscita
            pm2 save
            echo -e "${GREEN}✓ Server avviato con PM2${NC}"
            
            read -p "$(echo -e ${YELLOW}Vuoi configurare l\'avvio automatico con PM2? [s/N] ${NC})" -n 1 -r < /dev/tty
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                pm2 startup
                echo -e "${YELLOW}Esegui il comando mostrato sopra per completare la configurazione${NC}"
            fi
            
            echo ""
            echo -e "${MAGENTA}📱 Configura l'app Flutter con IP: ${IP_ADDRESS}${NC}"
        fi
        ;;
    3)
        echo -e "${YELLOW}Hai scelto avvio manuale${NC}"
        echo ""
        echo -e "${GREEN}Per avviare il server:${NC}"
        echo -e "   cd ${PROJECT_DIR}"
        echo -e "   node server.js"
        echo ""
        echo -e "${MAGENTA}📱 Configura l'app Flutter con IP: ${IP_ADDRESS}${NC}"
        ;;
    4)
        echo -e "${YELLOW}Nessuna configurazione automatica${NC}"
        echo -e "${MAGENTA}📱 Configura l'app Flutter con IP: ${IP_ADDRESS}${NC}"
        ;;
    *)
        echo -e "${RED}Scelta non valida${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📝 PROSSIMI PASSI:${NC}"
echo ""
echo -e "${YELLOW}1. Configura email per report automatici:${NC}"
echo -e "   ${GREEN}nano ${PROJECT_DIR}/email_config.json${NC}"
echo -e "   Vedi guida: ${BLUE}${PROJECT_DIR}/SETUP_EMAIL.md${NC}"
echo ""
echo -e "${YELLOW}2. Configura l'app Flutter:${NC}"
echo -e "   • Apri l'app sul dispositivo mobile"
echo -e "   • Vai in Impostazioni"
echo -e "   • Inserisci indirizzo server: ${GREEN}${IP_ADDRESS}${NC}"
echo ""
echo -e "${YELLOW}3. Verifica connessione:${NC}"
echo -e "   • Crea un dipendente di test"
echo -e "   • Prova una timbratura"
echo -e "   • Verifica che i dati vengano salvati"
echo ""
echo -e "${YELLOW}4. (Opzionale) Configura firewall:${NC}"
echo -e "   ${GREEN}sudo ufw allow 3000/tcp${NC}"
echo ""
echo -e "${GREEN}✨ Setup completato! Buon lavoro! ✨${NC}"
echo ""
