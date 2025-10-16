#!/bin/bash

#######################################################################
# Script di Setup Server Ingresso/Uscita
# 
# Questo script scarica e configura automaticamente il server
# di gestione presenze su una macchina remota (es. Raspberry Pi)
#
# Uso: bash setup_server.sh
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
echo -e "${BLUE}║   Configurazione automatica per Raspberry Pi/Linux   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Verifica sistema operativo
echo -e "${YELLOW}[1/7] Verifica sistema operativo...${NC}"
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${YELLOW}⚠ Attenzione: questo script è ottimizzato per Linux/Raspberry Pi${NC}"
    read -p "Continuare comunque? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Installazione Node.js e npm se non presenti
echo -e "${YELLOW}[2/7] Verifica installazione Node.js...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js non trovato. Installazione in corso...${NC}"
    
    # Aggiorna lista pacchetti
    sudo apt-get update
    
    # Installa Node.js (versione LTS consigliata)
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    echo -e "${GREEN}✓ Node.js installato con successo${NC}"
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js già installato: ${NODE_VERSION}${NC}"
fi

# Verifica npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ npm non trovato. Installazione...${NC}"
    sudo apt-get install -y npm
fi
NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm versione: ${NPM_VERSION}${NC}"

# Installazione Git se non presente
echo -e "${YELLOW}[3/7] Verifica installazione Git...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git non trovato. Installazione in corso...${NC}"
    sudo apt-get install -y git
    echo -e "${GREEN}✓ Git installato con successo${NC}"
else
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✓ Git già installato: ${GIT_VERSION}${NC}"
fi

# Installazione SQLite3 se non presente
echo -e "${YELLOW}[4/7] Verifica installazione SQLite3...${NC}"
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${YELLOW}SQLite3 non trovato. Installazione in corso...${NC}"
    sudo apt-get install -y sqlite3
    echo -e "${GREEN}✓ SQLite3 installato con successo${NC}"
else
    SQLITE_VERSION=$(sqlite3 --version)
    echo -e "${GREEN}✓ SQLite3 già installato: ${SQLITE_VERSION}${NC}"
fi

# Crea directory del progetto
echo -e "${YELLOW}[5/7] Creazione directory del progetto...${NC}"
PROJECT_DIR="$HOME/ingresso_uscita_server"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ La directory $PROJECT_DIR esiste già${NC}"
    read -p "Sovrascrivere? (s/n) " -n 1 -r
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

# Clone del repository
echo -e "${YELLOW}[6/7] Download dei file dal repository GitHub...${NC}"
echo -e "${BLUE}Repository: https://github.com/fragarray/ingresso_uscita${NC}"

# Clone solo della cartella server usando sparse checkout
git init
git remote add origin https://github.com/fragarray/ingresso_uscita.git
git config core.sparseCheckout true

# Configura sparse checkout per scaricare solo la cartella server
echo "server/*" >> .git/info/sparse-checkout

# Scarica i file
git pull origin main

# Verifica che la cartella server sia stata scaricata
if [ ! -d "server" ]; then
    echo -e "${RED}✗ Errore: la cartella server non è stata scaricata${NC}"
    exit 1
fi

# Sposta i file dalla sottocartella alla root
mv server/* .
rm -rf server

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
REQUIRED_FILES=("server.js" "package.json" "db.js" "config.js")
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
echo -e "${YELLOW}🔧 Opzioni di gestione server:${NC}"
echo ""
echo -e "${BLUE}Opzione 1 - PM2 (Process Manager):${NC}"
echo -e "   ${GREEN}npm install -g pm2${NC}"
echo -e "   ${GREEN}cd ${PROJECT_DIR}${NC}"
echo -e "   ${GREEN}pm2 start server.js --name ingresso-uscita${NC}"
echo -e "   ${GREEN}pm2 save${NC}"
echo -e "   ${GREEN}pm2 startup${NC}  ${BLUE}# per avvio automatico al boot${NC}"
echo ""
echo -e "${YELLOW}📊 Comandi utili PM2:${NC}"
echo -e "   ${GREEN}pm2 status${NC}           ${BLUE}# Stato dei processi${NC}"
echo -e "   ${GREEN}pm2 logs${NC}             ${BLUE}# Visualizza i log${NC}"
echo -e "   ${GREEN}pm2 restart all${NC}      ${BLUE}# Riavvia i processi${NC}"
echo -e "   ${GREEN}pm2 stop all${NC}         ${BLUE}# Ferma i processi${NC}"
echo ""
echo -e "${BLUE}Opzione 2 - systemd (Servizio di Sistema):${NC}"
echo -e "   ${YELLOW}Il setup ti chiederà se vuoi configurare automaticamente systemd${NC}"
echo -e "   ${YELLOW}In alternativa, crea manualmente:${NC} ${GREEN}/etc/systemd/system/ingresso-uscita.service${NC}"
echo ""
echo -e "${YELLOW}📊 Comandi utili systemd:${NC}"
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
echo -e "${YELLOW}🗄️  Database:${NC}"
echo -e "   Il database SQLite verrà creato automaticamente in:"
echo -e "   ${GREEN}${PROJECT_DIR}/ingresso_uscita.db${NC}"
echo ""
echo -e "${YELLOW}💾 Backup:${NC}"
echo -e "   I backup verranno salvati in:"
echo -e "   ${GREEN}${PROJECT_DIR}/backups/${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📝 Note:${NC}"
echo -e "   • Il server sarà accessibile sulla porta 3000"
echo -e "   • Assicurati che il firewall permetta connessioni sulla porta 3000"
echo -e "   • I log del server sono disponibili nei file di log o con i comandi del gestore scelto"
echo ""

echo ""
echo -e "${GREEN}✨ Installazione completata! Buon lavoro! ✨${NC}"
echo ""

# ==================== FUNZIONE PER CREARE SERVIZIO SYSTEMD ====================
create_systemd_service() {
    local SERVICE_NAME="ingresso-uscita"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    echo -e "${YELLOW}Creazione servizio systemd...${NC}"
    
    # Crea il file di configurazione (basato sul tuo systemctl funzionante)
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Server Ingresso/Uscita - Sistema Gestione Presenze
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which node) $PROJECT_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ingresso-uscita

# Variabili d'ambiente
Environment=NODE_ENV=production
Environment=PORT=3000

# Limiti di sicurezza (opzionali)
LimitNOFILE=4096

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
    echo -e "   ${GREEN}sudo journalctl -t ingresso-uscita -f${NC}              ${BLUE}# Log filtrati per tag${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} -n 100${NC}          ${BLUE}# Ultimi 100 log${NC}"
    echo -e "   ${GREEN}sudo journalctl -u ${SERVICE_NAME} --since today${NC}   ${BLUE}# Log di oggi${NC}"
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
echo -e "${YELLOW}Scegli come vuoi gestire il server:${NC}"
echo ""
echo -e "${GREEN}1)${NC} Avvio manuale (node server.js)"
echo -e "${GREEN}2)${NC} PM2 (process manager con monitoraggio)"
echo -e "${GREEN}3)${NC} systemd (servizio di sistema nativo Linux)"
echo -e "${GREEN}4)${NC} Nessuno (configuro dopo)"
echo ""
read -p "$(echo -e ${YELLOW}Scelta [1-4]: ${NC})" CHOICE

case $CHOICE in
    1)
        echo -e "${YELLOW}Hai scelto avvio manuale${NC}"
        echo -e "${GREEN}Per avviare il server:${NC}"
        echo -e "   cd ${PROJECT_DIR}"
        echo -e "   node server.js"
        ;;
    2)
        echo -e "${YELLOW}Installazione PM2...${NC}"
        if ! command -v pm2 &> /dev/null; then
            sudo npm install -g pm2
            echo -e "${GREEN}✓ PM2 installato${NC}"
        else
            echo -e "${GREEN}✓ PM2 già installato${NC}"
        fi
        
        read -p "$(echo -e ${YELLOW}Vuoi avviare il server con PM2 ora? [s/N] ${NC})" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            pm2 start server.js --name ingresso-uscita
            pm2 save
            echo -e "${GREEN}✓ Server avviato con PM2${NC}"
            
            read -p "$(echo -e ${YELLOW}Vuoi configurare l\'avvio automatico con PM2? [s/N] ${NC})" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                pm2 startup
                echo -e "${YELLOW}Esegui il comando mostrato sopra per completare la configurazione${NC}"
            fi
        fi
        ;;
    3)
        create_systemd_service
        ;;
    4)
        echo -e "${YELLOW}Nessuna configurazione automatica${NC}"
        ;;
    *)
        echo -e "${RED}Scelta non valida${NC}"
        ;;
esac
