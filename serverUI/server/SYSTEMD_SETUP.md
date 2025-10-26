# Configurazione systemd per Server Ingresso/Uscita

Questo documento spiega come configurare il server come servizio systemd di Linux per l'avvio automatico e la gestione centralizzata.

## 📋 Prerequisiti

- Sistema Linux (Raspberry Pi, Ubuntu, Debian, etc.)
- Node.js installato
- Permessi sudo
- Server installato in una directory (es. `/home/pi/ingresso_uscita_server`)

## 🚀 Installazione Automatica (Raccomandata)

Lo script `setup_server.sh` include un'opzione per configurare automaticamente systemd:

```bash
bash setup_server.sh
```

Alla fine dell'installazione, scegli l'opzione **3) systemd** dal menu.

## 🔧 Installazione Manuale

### Passo 1: Preparare il file di configurazione

Il file `ingresso-uscita.service` si trova nella cartella `server/`.

Modificalo sostituendo:
- `YOUR_USERNAME` → il tuo username Linux (es. `pi`)
- `/home/YOUR_USERNAME/ingresso_uscita_server` → percorso completo del server

**Esempio per Raspberry Pi:**
```ini
User=pi
WorkingDirectory=/home/pi/ingresso_uscita_server
ExecStart=/usr/bin/env node /home/pi/ingresso_uscita_server/server.js
```

### Passo 2: Copiare il file in systemd

```bash
sudo cp server/ingresso-uscita.service /etc/systemd/system/
```

### Passo 3: Creare i file di log

I log vengono gestiti automaticamente da systemd tramite syslog. Non è necessario creare file manualmente.

### Passo 4: Ricaricare systemd

```bash
sudo systemctl daemon-reload
```

### Passo 5: Abilitare e avviare il servizio

```bash
# Abilita avvio automatico al boot
sudo systemctl enable ingresso-uscita

# Avvia il servizio
sudo systemctl start ingresso-uscita

# Verifica lo stato
sudo systemctl status ingresso-uscita
```

## 📊 Comandi di Gestione

### Controllo del Servizio

```bash
# Stato del servizio
sudo systemctl status ingresso-uscita

# Avviare
sudo systemctl start ingresso-uscita

# Fermare
sudo systemctl stop ingresso-uscita

# Riavviare
sudo systemctl restart ingresso-uscita

# Ricaricare configurazione (senza fermare)
sudo systemctl reload ingresso-uscita
```

### Avvio Automatico

```bash
# Abilitare avvio automatico al boot
sudo systemctl enable ingresso-uscita

# Disabilitare avvio automatico
sudo systemctl disable ingresso-uscita

# Verificare se è abilitato
sudo systemctl is-enabled ingresso-uscita
```

### Visualizzazione Log

```bash
# Log in tempo reale (systemd journal)
sudo journalctl -u ingresso-uscita -f

# Log filtrati per tag (più pulito)
sudo journalctl -t ingresso-uscita -f

# Ultimi 100 log
sudo journalctl -u ingresso-uscita -n 100

# Log di oggi
sudo journalctl -u ingresso-uscita --since today

# Log delle ultime 2 ore
sudo journalctl -u ingresso-uscita --since "2 hours ago"
```

## 🔍 Risoluzione Problemi

### Il servizio non parte

**1. Verifica errori nel file di configurazione:**
```bash
sudo systemctl status ingresso-uscita
sudo journalctl -u ingresso-uscita -n 50
```

**2. Controlla i percorsi:**
- Verifica che `WorkingDirectory` esista
- Verifica che `ExecStart` punti al file `server.js` corretto
- Controlla che Node.js sia installato: `node --version`

**3. Verifica permessi:**
```bash
# Il file deve essere di proprietà di root
ls -l /etc/systemd/system/ingresso-uscita.service

# Se necessario:
sudo chown root:root /etc/systemd/system/ingresso-uscita.service
sudo chmod 644 /etc/systemd/system/ingresso-uscita.service
```

**4. Testa manualmente:**
```bash
# Prova ad avviare il server manualmente
cd /home/pi/ingresso_uscita_server
node server.js
```

### Il servizio si avvia ma crasha

**1. Controlla i log degli errori:**
```bash
sudo journalctl -u ingresso-uscita -n 50
sudo journalctl -t ingresso-uscita --since "10 minutes ago"
```

**2. Verifica dipendenze npm:**
```bash
cd /home/pi/ingresso_uscita_server
npm install
```

**3. Verifica nodemailer:**
```bash
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
# Deve stampare: function
```

### Riavvii continui

Se il servizio si riavvia continuamente, systemd lo fermerà automaticamente dopo 5 tentativi.

**Controlla la causa:**
```bash
sudo journalctl -u ingresso-uscita -n 100
```

**Rimuovi i limiti temporaneamente (solo per debug):**
```ini
# In /etc/systemd/system/ingresso-uscita.service
[Service]
StartLimitInterval=0
```

Poi: `sudo systemctl daemon-reload && sudo systemctl restart ingresso-uscita`

## 🔄 Aggiornamento del Server

Quando aggiorni il codice del server:

```bash
cd /home/pi/ingresso_uscita_server

# Scarica aggiornamenti (se usi git)
git pull

# Aggiorna dipendenze
npm install

# Riavvia il servizio
sudo systemctl restart ingresso-uscita

# Verifica
sudo systemctl status ingresso-uscita
```

## 🗑️ Disinstallazione

Per rimuovere il servizio:

```bash
# Ferma e disabilita
sudo systemctl stop ingresso-uscita
sudo systemctl disable ingresso-uscita

# Rimuovi il file di configurazione
sudo rm /etc/systemd/system/ingresso-uscita.service

# Ricarica systemd
sudo systemctl daemon-reload

# (Opzionale) Rimuovi i log
sudo rm /var/log/ingresso-uscita.log
sudo rm /var/log/ingresso-uscita-error.log
```

## 📌 Note Importanti

1. **Avvio automatico:** Con systemd abilitato, il server si avvierà automaticamente:
   - All'avvio del sistema
   - Dopo un crash (riavvio automatico con `Restart=always`)
   - Anche dopo uno stop manuale (grazie a `Restart=always`)

2. **Log persistenti:** I log vengono salvati automaticamente da systemd:
   - Accessibili con `journalctl`
   - Filtrabili per servizio: `journalctl -u ingresso-uscita`
   - Filtrabili per tag: `journalctl -t ingresso-uscita`
   - Rotazione automatica gestita da systemd

3. **Sicurezza:** Il servizio viene eseguito con i permessi dell'utente specificato, non come root.

4. **Email automatiche:** I cron job per auto-checkout (00:01) e report giornaliero (00:05) funzioneranno automaticamente.

5. **Restart Policy:**
   - `Restart=always` → Riavvia sempre, anche dopo stop manuale (server production)
   - `Restart=on-failure` → Riavvia solo in caso di crash (sviluppo/test)

6. **Confronto con PM2:**
   - **systemd:** Nativo Linux, leggero, integrato con il sistema, log centralizzati
   - **PM2:** Più feature (cluster mode, monitoring web), più pesante

## 🆘 Supporto

Per ulteriori problemi, controlla:
- **Repository GitHub:** https://github.com/fragarray/ingresso_uscita
- **Log dettagliati:** `sudo journalctl -u ingresso-uscita -xe`
- **File di configurazione esempio:** `server/ingresso-uscita.service`

## 📝 Esempio di Output Corretto

Quando il servizio funziona correttamente, lo stato mostra:

```
● ingresso-uscita.service - Server Ingresso/Uscita - Sistema Gestione Presenze
     Loaded: loaded (/etc/systemd/system/ingresso-uscita.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2025-10-16 14:30:00 CEST; 2h ago
       Docs: https://github.com/fragarray/ingresso_uscita
   Main PID: 12345 (node)
      Tasks: 11 (limit: 4915)
     Memory: 45.2M
        CPU: 1.234s
     CGroup: /system.slice/ingresso-uscita.service
             └─12345 node /home/pi/ingresso_uscita_server/server.js

Oct 16 14:30:00 raspberrypi systemd[1]: Started Server Ingresso/Uscita.
Oct 16 14:30:01 raspberrypi node[12345]: Server running on port 3000
Oct 16 14:30:01 raspberrypi node[12345]: ✓ Scheduler auto-checkout attivato
Oct 16 14:30:01 raspberrypi node[12345]: ✓ Scheduler report giornaliero attivato
```
