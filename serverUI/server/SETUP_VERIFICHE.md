# ✅ Checklist Verifica Setup Server

Questo documento elenca tutte le verifiche effettuate dallo script `setup_server.sh` per garantire un'installazione completa e funzionante.

## 🔍 Verifiche Pre-Installazione

### Sistema Operativo
- [x] Verifica Linux/Raspberry Pi
- [x] Avviso per altri sistemi operativi
- [x] Possibilità di continuare comunque

### Software Richiesto
- [x] **Node.js** - Versione LTS (automaticamente installato se mancante)
- [x] **npm** - Package manager Node.js
- [x] **Git** - Per clonare il repository
- [x] **SQLite3** - Database engine

## 📦 Dipendenze npm

Lo script installa e verifica:

```json
{
  "express": "^4.21.2",
  "cors": "^2.8.5",
  "exceljs": "^4.4.0",
  "sqlite3": "^5.1.7",
  "node-cron": "^4.2.1",
  "nodemailer": "^6.9.7",
  "multer": "^2.0.2"
}
```

### Verifica Speciale Nodemailer
```bash
# Test funzionamento
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
# Output atteso: "function"
```

Se il test fallisce, nodemailer viene reinstallato automaticamente.

## 📁 Struttura File

### File Obbligatori Verificati
```
✓ server.js              # Server principale
✓ package.json           # Dipendenze
✓ db.js                  # Database setup
✓ config.js              # Configurazioni
✓ routes/worksites.js    # Routes cantieri
```

### File Creati Automaticamente
```
✓ email_config.json      # Configurazione email
✓ .gitignore             # Protezione credenziali
✓ reports/               # Directory report Excel
✓ backups/               # Directory backup database
```

## 🧪 Test Funzionalità

### Test Automatico Server (5 secondi)
```bash
# Lo script testa:
1. Avvio del server
2. Risposta endpoint /api/ping
3. Chiusura pulita del processo
```

**Nota:** Se il test fallisce, non è necessariamente un problema. Il server verrà avviato normalmente dopo.

## 📋 Checklist Manuale Post-Installazione

Dopo che lo script completa, verifica manualmente:

### 1. File di Configurazione
```bash
cd ~/ingresso_uscita_server

# Verifica presenza file critici
ls -la server.js
ls -la routes/worksites.js
ls -la email_config.json
ls -la package.json
```

### 2. Dipendenze Installate
```bash
# Verifica node_modules
ls node_modules/ | wc -l
# Output atteso: ~300+ pacchetti

# Test nodemailer
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
# Output atteso: function
```

### 3. Test Server Manuale
```bash
# Avvia manualmente
node server.js

# Output atteso (entro 2 secondi):
# Server running on port 3000
# ✓ Scheduler auto-checkout attivato (esegue alle 00:01 ogni giorno)
# ✓ Scheduler report giornaliero attivato (esegue alle 00:05 ogni giorno)
```

### 4. Test Endpoint
```bash
# In un altro terminale
curl http://localhost:3000/api/ping

# Output atteso:
{
  "success": true,
  "message": "Ingresso/Uscita Server",
  "version": "1.0.0",
  "timestamp": "2025-10-17T...",
  "serverIdentity": "ingresso-uscita-server"
}
```

### 5. Configurazione Email
```bash
# Modifica con le tue credenziali
nano email_config.json

# Campi da modificare:
# - smtpUser: tuaemail@gmail.com
# - smtpPassword: app-password-16-caratteri
# - fromEmail: tuaemail@gmail.com
```

### 6. Test Email (Opzionale)
```bash
# Dopo aver configurato email_config.json
curl -X POST http://localhost:3000/api/email/test \
  -H "Content-Type: application/json" \
  -d '{"adminId": 1, "testEmail": "tuaemail@gmail.com"}'

# Output atteso:
{"success": true, "message": "Test email sent"}
```

## 🔧 Configurazioni Gestione Server

Lo script offre 4 opzioni:

### Opzione 1: Avvio Manuale
```bash
cd ~/ingresso_uscita_server
node server.js
```
✅ Semplice
❌ Richiede terminale sempre aperto
❌ Nessun riavvio automatico

### Opzione 2: PM2
```bash
pm2 start server.js --name ingresso-uscita
pm2 save
pm2 startup
```
✅ Monitoraggio avanzato
✅ Riavvio automatico
✅ Interfaccia web disponibile
⚠️ Overhead memoria moderato

### Opzione 3: systemd (Raccomandato per Raspberry Pi)
```bash
sudo systemctl start ingresso-uscita
sudo systemctl enable ingresso-uscita
```
✅ Nativo Linux
✅ Minimo overhead
✅ Log centralizzati (journalctl)
✅ Riavvio automatico (`Restart=always`)

### Opzione 4: Manuale Dopo
Configura in seguito con i comandi sopra.

## 🚨 Problemi Comuni e Soluzioni

### Errore: File routes/worksites.js mancante
```bash
cd ~/ingresso_uscita_server
ls routes/worksites.js

# Se mancante:
git pull origin main
```

### Errore: nodemailer.createTransport is not a function
```bash
npm uninstall nodemailer
npm install nodemailer@6.9.7

# Verifica
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
```

### Errore: Cannot find module 'express'
```bash
cd ~/ingresso_uscita_server
rm -rf node_modules package-lock.json
npm install
```

### Server non risponde sulla porta 3000
```bash
# Verifica che la porta non sia già in uso
sudo netstat -tlnp | grep 3000

# Se occupata, termina il processo
sudo kill -9 $(sudo lsof -t -i:3000)
```

### Database non viene creato
```bash
# Verifica permessi directory
ls -la ~/ingresso_uscita_server/

# Il database viene creato automaticamente al primo avvio
# Nome: ingresso_uscita.db
```

## 📊 Verifica Completa Sistema

Script di verifica completa:

```bash
#!/bin/bash

echo "=== VERIFICA COMPLETA SISTEMA ==="
echo ""

# 1. File presenti
echo "1. File critici:"
cd ~/ingresso_uscita_server
for file in server.js package.json db.js config.js routes/worksites.js email_config.json; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file MANCANTE!"
    fi
done
echo ""

# 2. Node.js e npm
echo "2. Software:"
echo "   Node.js: $(node -v)"
echo "   npm: $(npm -v)"
echo "   SQLite: $(sqlite3 --version | awk '{print $1}')"
echo ""

# 3. Nodemailer
echo "3. Nodemailer:"
NODEMAILER_CHECK=$(node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);" 2>&1)
if [ "$NODEMAILER_CHECK" = "function" ]; then
    echo "   ✓ Nodemailer funzionante"
else
    echo "   ✗ Nodemailer NON funzionante!"
fi
echo ""

# 4. Test server
echo "4. Test server (5 secondi):"
timeout 5 node server.js > /tmp/server_check.log 2>&1 &
SERVER_PID=$!
sleep 3

if curl -s http://localhost:3000/api/ping | grep -q "success"; then
    echo "   ✓ Server risponde correttamente"
else
    echo "   ✗ Server non risponde"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
echo ""

# 5. Servizio systemd/PM2
echo "5. Gestione server:"
if systemctl is-active --quiet ingresso-uscita 2>/dev/null; then
    echo "   ✓ systemd: ingresso-uscita (attivo)"
elif systemctl is-active --quiet node-server 2>/dev/null; then
    echo "   ✓ systemd: node-server (attivo)"
elif command -v pm2 &> /dev/null && pm2 list | grep -q "ingresso-uscita"; then
    echo "   ✓ PM2: ingresso-uscita (attivo)"
else
    echo "   ⚠️  Nessun gestore automatico configurato"
fi
echo ""

echo "=== VERIFICA COMPLETATA ==="
```

Salva questo script come `verify_setup.sh`, rendilo eseguibile e lancialo:

```bash
chmod +x verify_setup.sh
./verify_setup.sh
```

## ✅ Risultato Atteso

Se tutto è configurato correttamente:

```
=== VERIFICA COMPLETA SISTEMA ===

1. File critici:
   ✓ server.js
   ✓ package.json
   ✓ db.js
   ✓ config.js
   ✓ routes/worksites.js
   ✓ email_config.json

2. Software:
   Node.js: v22.20.0
   npm: 10.9.2
   SQLite: 3.37.2

3. Nodemailer:
   ✓ Nodemailer funzionante

4. Test server (5 secondi):
   ✓ Server risponde correttamente

5. Gestione server:
   ✓ systemd: node-server (attivo)

=== VERIFICA COMPLETATA ===
```

## 🎯 Prossimi Passi

Dopo verifica positiva:

1. ✅ **Configura email:** Modifica `email_config.json` con credenziali Gmail
2. ✅ **Configura app Flutter:** Imposta l'IP del server nelle impostazioni
3. ✅ **Testa timbrature:** Effettua test di IN/OUT dall'app
4. ✅ **Verifica report:** Controlla generazione report Excel
5. ✅ **Verifica cron:** Aspetta mezzanotte per auto-checkout (00:01) e report email (00:05)

## 📚 Documentazione Correlata

- **SETUP_EMAIL.md** - Configurazione completa email
- **SYSTEMD_SETUP.md** - Guida systemd
- **MIGRAZIONE_SYSTEMD.md** - Migrazione da node-server
- **TURNI_NOTTURNI.md** - Flag allowNightShift
- **EMAIL_SISTEMA.md** - Sistema email automatico

## 🆘 Supporto

Se riscontri problemi non risolti da questa guida:

1. Controlla i log:
   ```bash
   # systemd
   sudo journalctl -u ingresso-uscita -n 100
   
   # PM2
   pm2 logs ingresso-uscita
   
   # Manuale
   node server.js
   ```

2. Verifica GitHub Issues: https://github.com/fragarray/ingresso_uscita/issues

3. Crea nuovo issue con:
   - Output di `verify_setup.sh`
   - Log del server
   - Versione Node.js e npm
   - Sistema operativo

---

**Ultima verifica:** 2025-10-17
**Versione script:** 2.0 (con verifica nodemailer, routes, email_config)
