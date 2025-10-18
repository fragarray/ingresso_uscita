#!/bin/bash

#######################################################################
# Script di Setup Server Ingresso/Uscita - Ubuntu Core IoT Edition
# 
# Questo script è ottimizzato per Ubuntu Core IoT su Raspberry Pi
# Usa snap packages invece di apt
#
# Uso: bash setup_server_ubuntu_core.sh
#######################################################################

set -e  # Esce in caso di errore

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Setup Server Ingresso/Uscita                       ║${NC}"
echo -e "${BLUE}║   Ubuntu Core IoT Edition                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Verifica sistema operativo
echo -e "${YELLOW}[1/7] Verifica sistema operativo...${NC}"
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}✗ Questo script richiede Linux${NC}"
    exit 1
fi

# Verifica se è Ubuntu Core
if command -v snap &> /dev/null; then
    echo -e "${GREEN}✓ Sistema Ubuntu Core rilevato${NC}"
    IS_UBUNTU_CORE=true
else
    echo -e "${YELLOW}⚠️ Sistema Linux standard (non Ubuntu Core)${NC}"
    IS_UBUNTU_CORE=false
    read -p "Continuare comunque? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Installazione Node.js
echo -e "${YELLOW}[2/7] Verifica installazione Node.js...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js non trovato. Installazione in corso...${NC}"
    
    if [ "$IS_UBUNTU_CORE" = true ]; then
        # Ubuntu Core: usa snap
        sudo snap install node --classic --channel=20/stable
        echo -e "${GREEN}✓ Node.js installato via snap${NC}"
    else
        # Ubuntu standard: usa apt
        sudo apt-get update
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo -e "${GREEN}✓ Node.js installato via apt${NC}"
    fi
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js già installato: ${NODE_VERSION}${NC}"
fi

# Verifica npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ npm non trovato${NC}"
    if [ "$IS_UBUNTU_CORE" = true ]; then
        echo -e "${YELLOW}Reinstallo Node.js con npm...${NC}"
        sudo snap refresh node --channel=20/stable
    else
        sudo apt-get install -y npm
    fi
fi
NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm versione: ${NPM_VERSION}${NC}"

# Installazione Git
echo -e "${YELLOW}[3/7] Verifica installazione Git...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git non trovato. Installazione in corso...${NC}"
    
    if [ "$IS_UBUNTU_CORE" = true ]; then
        # Ubuntu Core: usa snap
        sudo snap install git-ubuntu --classic
        # Crea alias per compatibilità
        sudo ln -sf /snap/bin/git-ubuntu.git /usr/local/bin/git 2>/dev/null || true
        echo -e "${GREEN}✓ Git installato via snap${NC}"
    else
        # Ubuntu standard: usa apt
        sudo apt-get install -y git
        echo -e "${GREEN}✓ Git installato via apt${NC}"
    fi
else
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✓ Git già installato: ${GIT_VERSION}${NC}"
fi

# Installazione SQLite3
echo -e "${YELLOW}[4/7] Verifica installazione SQLite3...${NC}"
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${YELLOW}SQLite3 non trovato. Installazione in corso...${NC}"
    
    if [ "$IS_UBUNTU_CORE" = true ]; then
        # Ubuntu Core: usa snap o installa binario manualmente
        # SQLite3 non è critico per il funzionamento (è una dipendenza npm)
        echo -e "${YELLOW}SQLite3 CLI non disponibile via snap, ma sqlite3 npm funzionerà${NC}"
    else
        # Ubuntu standard: usa apt
        sudo apt-get install -y sqlite3
        echo -e "${GREEN}✓ SQLite3 installato via apt${NC}"
    fi
else
    SQLITE_VERSION=$(sqlite3 --version)
    echo -e "${GREEN}✓ SQLite3 già installato: ${SQLITE_VERSION}${NC}"
fi

# Crea directory del progetto
echo -e "${YELLOW}[5/7] Creazione directory del progetto...${NC}"

# In Ubuntu Core, usa directory accessibile
if [ "$IS_UBUNTU_CORE" = true ]; then
    # Usa /var/snap/node/common/ per dati persistenti
    PROJECT_DIR="/var/snap/node/common/ingresso_uscita_server"
else
    PROJECT_DIR="$HOME/ingresso_uscita_server"
fi

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ La directory $PROJECT_DIR esiste già${NC}"
    read -p "Sovrascrivere? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Backup della directory esistente...${NC}"
        BACKUP_DIR="${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        sudo mv "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || mv "$PROJECT_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}✓ Backup creato in: ${BACKUP_DIR}${NC}"
    else
        echo -e "${RED}✗ Installazione annullata${NC}"
        exit 1
    fi
fi

# Crea directory con permessi corretti
if [ "$IS_UBUNTU_CORE" = true ]; then
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown $USER:$USER "$PROJECT_DIR"
else
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}✓ Directory creata: ${PROJECT_DIR}${NC}"

# Clone del repository
echo -e "${YELLOW}[6/7] Download dei file dal repository GitHub...${NC}"
echo -e "${BLUE}Repository: https://github.com/fragarray/ingresso_uscita${NC}"

# Clone solo della cartella server usando sparse checkout
git init
git remote add origin https://github.com/fragarray/ingresso_uscita.git
git config core.sparseCheckout true

# Configura sparse checkout per scaricare la cartella server e tutte le sottocartelle
echo "server/*" >> .git/info/sparse-checkout
echo "server/routes/*" >> .git/info/sparse-checkout

# Scarica i file
echo -e "${YELLOW}Download in corso...${NC}"
git pull origin main

# Verifica che la cartella server sia stata scaricata
if [ ! -d "server" ]; then
    echo -e "${RED}✗ Errore: la cartella server non è stata scaricata${NC}"
    exit 1
fi

# Sposta i file dalla sottocartella alla root (preservando struttura)
mv server/* . 2>/dev/null || true
mv server/.gitignore . 2>/dev/null || true
rm -rf server .git

echo -e "${GREEN}✓ File scaricati con successo${NC}"

# Installazione dipendenze npm
echo -e "${YELLOW}[7/7] Installazione dipendenze npm...${NC}"
npm install

# Verifica che nodemailer sia installato correttamente
echo -e "${YELLOW}Verifica installazione nodemailer...${NC}"
NODE_CHECK=$(node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);" 2>&1)
if [ "$NODE_CHECK" = "function" ]; then
    echo -e "${GREEN}✓ nodemailer installato correttamente${NC}"
else
    echo -e "${YELLOW}⚠ Reinstallazione nodemailer...${NC}"
    npm uninstall nodemailer
    npm install nodemailer@6.9.7
    echo -e "${GREEN}✓ nodemailer reinstallato${NC}"
fi

echo -e "${GREEN}✓ Tutte le dipendenze installate correttamente${NC}"

# Verifica che tutti i file necessari siano presenti
echo ""
echo -e "${YELLOW}Verifica integrità dei file...${NC}"
REQUIRED_FILES=("server.js" "package.json" "db.js" "config.js" "routes/worksites.js")
MISSING_FILES=0

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ ${file}${NC}"
    else
        echo -e "${RED}✗ ${file} mancante${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${RED}✗ Alcuni file sono mancanti. Verifica il repository.${NC}"
    exit 1
fi

# Crea directory necessarie
mkdir -p reports
mkdir -p backups

# Crea file di configurazione email se non esiste
if [ ! -f "email_config.json" ]; then
    echo -e "${YELLOW}Creazione file configurazione email...${NC}"
    cat > email_config.json <<EOF
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
    echo -e "${GREEN}✓ File email_config.json creato${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANTE: Modifica email_config.json con le tue credenziali Gmail!${NC}"
fi

# Crea .gitignore se non esiste (per proteggere credenziali)
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}Creazione .gitignore...${NC}"
    cat > .gitignore <<EOF
# Configurazione email con credenziali sensibili
email_config.json

# Database locale
*.db
*.db-journal

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
EOF
    echo -e "${GREEN}✓ File .gitignore creato${NC}"
fi

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
echo -e "${YELLOW}🚀 Per avviare il server manualmente:${NC}"
echo -e "   ${GREEN}cd ${PROJECT_DIR}${NC}"
echo -e "   ${GREEN}node server.js${NC}"
echo ""

# Ubuntu Core: solo systemd (PM2 ha problemi con snap confinement)
if [ "$IS_UBUNTU_CORE" = true ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  UBUNTU CORE: Solo systemd è supportato${NC}"
    echo -e "${YELLOW}PM2 non funziona correttamente con snap confinement${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi

echo -e "${YELLOW}🔧 Gestione server (systemd):${NC}"
echo -e "   ${GREEN}sudo systemctl start ingresso-uscita${NC}    ${BLUE}# Avvia${NC}"
echo -e "   ${GREEN}sudo systemctl stop ingresso-uscita${NC}     ${BLUE}# Ferma${NC}"
echo -e "   ${GREEN}sudo systemctl restart ingresso-uscita${NC}  ${BLUE}# Riavvia${NC}"
echo -e "   ${GREEN}sudo systemctl status ingresso-uscita${NC}   ${BLUE}# Stato${NC}"
echo -e "   ${GREEN}sudo systemctl enable ingresso-uscita${NC}   ${BLUE}# Avvio automatico${NC}"
echo -e "   ${GREEN}sudo journalctl -u ingresso-uscita -f${NC}   ${BLUE}# Log in tempo reale${NC}"
echo ""
echo -e "${YELLOW}⚙️  Configurazione app Flutter:${NC}"
echo -e "   Nell'app, vai in ${GREEN}Impostazioni${NC} e imposta l'indirizzo IP:"
echo -e "   ${GREEN}${IP_ADDRESS}${NC}"
echo ""
echo -e "${YELLOW}📧 Configurazione Email:${NC}"
echo -e "   Modifica il file di configurazione:"
echo -e "   ${GREEN}nano ${PROJECT_DIR}/email_config.json${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📝 Note Ubuntu Core:${NC}"
echo -e "   • Node.js installato come snap confinato"
echo -e "   • Il server gira in ${PROJECT_DIR}"
echo -e "   • Usa systemd per gestione automatica"
echo -e "   • PM2 NON è supportato su Ubuntu Core"
echo ""

echo ""
echo -e "${GREEN}✨ Installazione completata! Buon lavoro! ✨${NC}"
echo ""

# Test rapido server (opzionale, può fallire su Ubuntu Core per permessi)
echo -e "${YELLOW}Eseguo test rapido del server...${NC}"
timeout 5 node server.js > /tmp/server_test.log 2>&1 &
SERVER_PID=$!
sleep 3

# Test connessione
if curl -s http://localhost:3000/api/ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server funzionante (test superato)${NC}"
else
    echo -e "${YELLOW}⚠️  Test non riuscito (probabilmente normale su Ubuntu Core)${NC}"
fi

# Ferma il test
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""

# ==================== FUNZIONE PER CREARE SERVIZIO SYSTEMD ====================
create_systemd_service() {
    local SERVICE_NAME="ingresso-uscita"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    echo -e "${YELLOW}Creazione servizio systemd...${NC}"
    
    # Rileva percorso node (diverso tra snap e apt)
    NODE_PATH=$(which node)
    
    # Crea il file di configurazione
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Server Ingresso/Uscita - Sistema Gestione Presenze
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$NODE_PATH $PROJECT_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ingresso-uscita

# Variabili d'ambiente
Environment=NODE_ENV=production
Environment=PORT=3000

# Ubuntu Core snap: permessi necessari
Environment=PATH=/snap/bin:/usr/local/bin:/usr/bin:/bin

# Limiti di sicurezza
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Ricarica systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ Servizio systemd creato: ${SERVICE_NAME}${NC}"
    echo -e "${BLUE}File di configurazione: ${SERVICE_FILE}${NC}"
    echo -e "${BLUE}Node.js path: ${NODE_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}Comandi disponibili:${NC}"
    echo -e "   ${GREEN}sudo systemctl start ${SERVICE_NAME}${NC}      ${BLUE}# Avvia il server${NC}"
    echo -e "   ${GREEN}sudo systemctl stop ${SERVICE_NAME}${NC}       ${BLUE}# Ferma il server${NC}"
    echo -e "   ${GREEN}sudo systemctl restart ${SERVICE_NAME}${NC}    ${BLUE}# Riavvia il server${NC}"
    echo -e "   ${GREEN}sudo systemctl status ${SERVICE_NAME}${NC}     ${BLUE}# Stato del server${NC}"
    echo -e "   ${GREEN}sudo systemctl enable ${SERVICE_NAME}${NC}     ${BLUE}# Abilita avvio automatico${NC}"
    echo ""
    echo -e "${YELLOW}Log del server:${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} -f${NC}              ${BLUE}# Log in tempo reale${NC}"
    echo -e "   ${GREEN}sudo journalctl -t ingresso-uscita -f${NC}              ${BLUE}# Log filtrati per tag${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Vuoi abilitare l\'avvio automatico? [s/N] ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo systemctl enable "$SERVICE_NAME"
        echo -e "${GREEN}✓ Avvio automatico abilitato${NC}"
    fi
    
    read -p "$(echo -e ${YELLOW}Vuoi avviare il server ora? [s/N] ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo systemctl start "$SERVICE_NAME"
        sleep 2
        sudo systemctl status "$SERVICE_NAME" --no-pager
        echo -e "${GREEN}✓ Server avviato${NC}"
    fi
}

# ==================== MENU SCELTA GESTIONE SERVER ====================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Vuoi configurare il servizio systemd ora?${NC}"
echo ""
echo -e "${GREEN}1)${NC} Sì, configura systemd (raccomandato)"
echo -e "${GREEN}2)${NC} No, configuro manualmente dopo"
echo ""
read -p "$(echo -e ${YELLOW}Scelta [1-2]: ${NC})" CHOICE

case $CHOICE in
    1)
        create_systemd_service
        ;;
    2)
        echo -e "${YELLOW}Nessuna configurazione automatica${NC}"
        echo -e "${YELLOW}Usa i comandi mostrati sopra quando sei pronto${NC}"
        ;;
    *)
        echo -e "${YELLOW}Scelta non valida, configura manualmente dopo${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}✨ Setup Ubuntu Core completato! ✨${NC}"
echo ""
