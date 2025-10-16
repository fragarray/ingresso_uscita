# 🔄 Migrazione da node-server a ingresso-uscita

Se hai già configurato il servizio systemd con il nome `node-server` (come hai fatto tu), puoi:

1. **Mantenere il nome attuale** (raccomandato se funziona)
2. **Migrare al nuovo nome** (per uniformità con il repository)

## ✅ Opzione 1: Mantenere `node-server` (Raccomandato)

Il tuo file systemd è **perfetto e ottimizzato**. Non c'è bisogno di cambiarlo!

### Cosa fare dopo gli aggiornamenti del codice:

```bash
# 1. Aggiorna il codice
cd ~/ingresso_uscita_server
git pull
npm install

# 2. Verifica nodemailer
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"

# 3. Riavvia il servizio
sudo systemctl restart node-server

# 4. Verifica che funzioni
sudo systemctl status node-server
sudo journalctl -t node-server -f
```

**Vantaggi:**
- ✅ Zero downtime
- ✅ Nessuna reconfigurazione
- ✅ Tutto continua a funzionare come prima
- ✅ Il fix nodemailer viene applicato automaticamente

## 🔄 Opzione 2: Migrare a `ingresso-uscita`

Se preferisci uniformarti al repository:

### Passo 1: Backup del servizio attuale

```bash
sudo cp /etc/systemd/system/node-server.service /tmp/node-server.service.backup
```

### Passo 2: Ferma e disabilita il vecchio servizio

```bash
sudo systemctl stop node-server
sudo systemctl disable node-server
```

### Passo 3: Crea il nuovo servizio

**Opzione A - Template già pronto:**
```bash
cd ~/ingresso_uscita_server
sudo cp server/ingresso-uscita.service /tmp/
sudo nano /tmp/ingresso-uscita.service

# Modifica solo se necessario (già configurato per pi):
# User=pi
# WorkingDirectory=/home/pi/ingresso_uscita_server
# ExecStart=/usr/bin/node /home/pi/ingresso_uscita_server/server.js

# Copia in systemd
sudo cp /tmp/ingresso-uscita.service /etc/systemd/system/
```

**Opzione B - Rinomina il tuo file esistente:**
```bash
# Il tuo file è già perfetto, basta rinominarlo!
sudo mv /etc/systemd/system/node-server.service /etc/systemd/system/ingresso-uscita.service

# Opzionale: aggiorna la descrizione
sudo nano /etc/systemd/system/ingresso-uscita.service
# Cambia Description=Node.js server
# In:    Description=Server Ingresso/Uscita - Sistema Gestione Presenze
```

### Passo 4: Ricarica e avvia

```bash
sudo systemctl daemon-reload
sudo systemctl enable ingresso-uscita
sudo systemctl start ingresso-uscita
sudo systemctl status ingresso-uscita
```

### Passo 5: Verifica i log

```bash
# Nuovo nome servizio
sudo journalctl -u ingresso-uscita -f

# Se hai mantenuto SyslogIdentifier, funziona ancora
sudo journalctl -t node-server -f   # (se lo avevi)
```

### Passo 6: Rimuovi il vecchio servizio

Solo dopo aver verificato che tutto funziona:

```bash
sudo rm /etc/systemd/system/node-server.service
sudo systemctl daemon-reload
```

## 📊 Confronto File

### Il Tuo File (node-server.service) ✅ OTTIMO
```ini
[Unit]
Description=Node.js server
After=network.target

[Service]
ExecStart=/usr/bin/node /home/pi/ingresso_uscita_server/server.js
WorkingDirectory=/home/pi/ingresso_uscita_server
Restart=always                      # ← MEGLIO del mio!
RestartSec=10
User=pi
Environment=NODE_ENV=production
StandardOutput=syslog               # ← Più pulito del mio!
StandardError=syslog
SyslogIdentifier=node-server        # ← Ottimo per filtrare log!

[Install]
WantedBy=multi-user.target
```

### Nuovo Template (ingresso-uscita.service) - Aggiornato con le tue migliorie
```ini
[Unit]
Description=Server Ingresso/Uscita - Sistema Gestione Presenze
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/ingresso_uscita_server
ExecStart=/usr/bin/node /home/pi/ingresso_uscita_server/server.js
Restart=always                      # ← Copiato dal tuo!
RestartSec=10
StandardOutput=syslog               # ← Copiato dal tuo!
StandardError=syslog
SyslogIdentifier=ingresso-uscita    # ← Ispirato dal tuo!
Environment=NODE_ENV=production
Environment=PORT=3000
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
```

### Differenze chiave:

| Elemento | Tuo | Nuovo | Note |
|----------|-----|-------|------|
| Description | Semplice | Descrittivo | Cosmetico |
| Type | implicit (simple) | explicit | Equivalenti |
| SyslogIdentifier | `node-server` | `ingresso-uscita` | Cambia filtro log |
| LimitNOFILE | Assente | 4096 | Opzionale (limite file aperti) |
| PORT | Assente | 3000 | Opzionale (già default) |

**Nota:** Ho aggiornato il template del repository per usare il tuo approccio migliore! (`Restart=always`, `syslog`, `SyslogIdentifier`)

## 🎯 Raccomandazione

**Mantieni il tuo servizio `node-server`** - funziona perfettamente!

L'unica cosa importante è aggiornare il codice del server per il fix nodemailer:

```bash
cd ~/ingresso_uscita_server
git pull
npm install
sudo systemctl restart node-server
```

## 🆘 Se qualcosa va storto

### Ripristino rapido dal backup

```bash
# Se hai migrato e vuoi tornare indietro:
sudo systemctl stop ingresso-uscita
sudo systemctl disable ingresso-uscita
sudo rm /etc/systemd/system/ingresso-uscita.service

sudo cp /tmp/node-server.service.backup /etc/systemd/system/node-server.service
sudo systemctl daemon-reload
sudo systemctl enable node-server
sudo systemctl start node-server
```

### Verifica che il server funzioni

```bash
# Test manuale (sempre funziona)
cd ~/ingresso_uscita_server
node server.js

# Se funziona manualmente ma non con systemd, verifica:
sudo systemctl status node-server
sudo journalctl -u node-server -n 50
```

## 📝 Comandi Utili Post-Migrazione

```bash
# Verifica servizio attivo
systemctl is-active node-server        # o ingresso-uscita
systemctl is-enabled node-server       # o ingresso-uscita

# Log in tempo reale
sudo journalctl -u node-server -f      # o ingresso-uscita
sudo journalctl -t node-server -f      # se hai SyslogIdentifier

# Statistiche del servizio
systemctl show node-server --property=ActiveState,SubState,LoadState

# Restart rapido dopo aggiornamenti
sudo systemctl restart node-server && sudo systemctl status node-server
```

## ✅ Checklist

- [ ] Backup del servizio attuale creato
- [ ] Aggiornato codice server (git pull, npm install)
- [ ] Verificato nodemailer funzionante
- [ ] Servizio riavviato
- [ ] Email di test inviata con successo
- [ ] Log verificati e funzionanti
- [ ] Avvio automatico testato (riavvia il Raspberry Pi)

## 💡 Suggerimenti

1. **Testa sempre prima del reboot:**
   ```bash
   sudo systemctl restart node-server
   sudo systemctl status node-server
   ```

2. **Monitora i log durante le prime ore:**
   ```bash
   sudo journalctl -t node-server -f
   ```

3. **Verifica i cron job alle 00:01 e 00:05:**
   - Auto-checkout mezzanotte
   - Report giornaliero email

4. **Backup regolari del database:**
   ```bash
   cp ~/ingresso_uscita_server/ingresso_uscita.db ~/backup_db_$(date +%Y%m%d).db
   ```

## 🎉 Conclusione

Il tuo servizio `node-server` è configurato in modo ottimale! 

Le modifiche che ho fatto al repository sono state **ispirate dal tuo file**, che è più pulito e professionale dell'originale.

**Non c'è bisogno di migrare** - continua a usare `node-server` e semplicemente aggiorna il codice con git pull quando necessario.
