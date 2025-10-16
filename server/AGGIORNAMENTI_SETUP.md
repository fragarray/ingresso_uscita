# 🚀 Aggiornamenti Setup Server v2.0

## ✨ Novità

### 1. Verifica automatica nodemailer
Lo script ora verifica che `nodemailer` sia installato correttamente e, se necessario, lo reinstalla automaticamente con la versione corretta (6.9.7).

**Fix applicato:**
```javascript
// Corretto da: nodemailer.createTransporter() [ERRATO]
// A: nodemailer.createTransport() [CORRETTO]
```

### 2. Menu interattivo per gestione server
Alla fine dell'installazione puoi scegliere tra:

1. **Avvio manuale** - `node server.js`
2. **PM2** - Process manager con monitoraggio avanzato
3. **systemd** - Servizio nativo Linux (⭐ **NUOVO!**)
4. **Nessuno** - Configuro dopo

### 3. Configurazione automatica systemd

**Funzionalità:**
- ✅ Crea automaticamente il file di servizio in `/etc/systemd/system/`
- ✅ Configura log persistenti in `/var/log/`
- ✅ Abilita avvio automatico al boot (opzionale)
- ✅ Avvia il server immediatamente (opzionale)
- ✅ Mostra tutti i comandi utili per gestire il servizio

**File generato:**
```ini
[Unit]
Description=Server Ingresso/Uscita - Sistema Gestione Presenze
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/ingresso_uscita_server
ExecStart=/usr/bin/node /home/pi/ingresso_uscita_server/server.js
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/ingresso-uscita.log
StandardError=append:/var/log/ingresso-uscita-error.log

[Install]
WantedBy=multi-user.target
```

### 4. File di configurazione inclusi nel repository

**Nuovi file aggiunti:**

1. **`server/ingresso-uscita.service`**
   - Template per configurazione manuale systemd
   - Include istruzioni dettagliate
   - Pronto per essere modificato e copiato

2. **`server/SYSTEMD_SETUP.md`**
   - Guida completa alla configurazione systemd
   - Istruzioni per installazione manuale e automatica
   - Troubleshooting dettagliato
   - Confronto systemd vs PM2

## 📋 Dipendenze Verificate

Lo script verifica e installa automaticamente:

- ✅ Node.js (versione LTS)
- ✅ npm
- ✅ Git
- ✅ SQLite3
- ✅ Tutte le dipendenze npm:
  - `express` 4.21.2
  - `cors` 2.8.5
  - `exceljs` 4.4.0
  - `sqlite3` 5.1.7
  - `node-cron` 4.2.1
  - `nodemailer` 6.9.7 ⭐ (con verifica funzionamento)
  - `multer` 2.0.2

## 🔧 Comandi systemd

### Gestione base
```bash
sudo systemctl start ingresso-uscita       # Avvia
sudo systemctl stop ingresso-uscita        # Ferma
sudo systemctl restart ingresso-uscita     # Riavvia
sudo systemctl status ingresso-uscita      # Stato
```

### Avvio automatico
```bash
sudo systemctl enable ingresso-uscita      # Abilita
sudo systemctl disable ingresso-uscita     # Disabilita
```

### Log
```bash
sudo journalctl -u ingresso-uscita -f              # Real-time
sudo tail -f /var/log/ingresso-uscita.log         # Output
sudo tail -f /var/log/ingresso-uscita-error.log   # Errori
```

## 🆚 Confronto: systemd vs PM2

| Caratteristica | systemd | PM2 |
|----------------|---------|-----|
| Nativo Linux | ✅ | ❌ (npm package) |
| Avvio automatico | ✅ | ✅ |
| Log persistenti | ✅ | ✅ |
| Riavvio automatico | ✅ | ✅ |
| Monitoring Web | ❌ | ✅ |
| Cluster mode | ❌ | ✅ |
| Overhead memoria | Minimo | Moderato |
| Integrazione sistema | Completa | Parziale |
| Curva apprendimento | Facile | Facile |

**Raccomandazione:**
- **Raspberry Pi / Server dedicato:** systemd (più leggero, nativo)
- **Sviluppo / Multi-server:** PM2 (monitoring avanzato)

## 🐛 Fix Nodemailer

Il problema `nodemailer.createTransporter is not a function` è stato risolto:

**Prima:**
```javascript
return nodemailer.createTransporter({  // ❌ ERRATO
  host: config.smtpHost,
  // ...
});
```

**Dopo:**
```javascript
return nodemailer.createTransport({  // ✅ CORRETTO
  host: config.smtpHost,
  // ...
});
```

Lo script di setup ora verifica automaticamente che nodemailer funzioni:
```bash
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
# Deve stampare: function
```

## 📁 Struttura File

```
server/
├── server.js                      # Server principale
├── db.js                          # Database
├── config.js                      # Configurazione
├── package.json                   # Dipendenze
├── email_config.json              # Config email (auto-generato)
├── ingresso-uscita.service        # ⭐ Template systemd
├── SYSTEMD_SETUP.md               # ⭐ Guida systemd
├── SETUP_EMAIL.md                 # Guida email
├── EMAIL_SISTEMA.md               # Documentazione email
└── TURNI_NOTTURNI.md              # Doc turni notturni
```

## 🎯 Come Usare

### Installazione rapida (Raspberry Pi)

1. **Scarica il repository:**
   ```bash
   git clone https://github.com/fragarray/ingresso_uscita.git
   cd ingresso_uscita
   ```

2. **Esegui setup automatico:**
   ```bash
   bash setup_server.sh
   ```

3. **Scegli systemd dal menu** (opzione 3)

4. **Configura email:**
   - Segui la guida in `SETUP_EMAIL.md`
   - Modifica `email_config.json` con le tue credenziali Gmail

5. **Fatto!** Il server è attivo e partirà automaticamente al boot

### Configurazione manuale systemd

Se preferisci configurare manualmente:

1. Copia il template:
   ```bash
   cp server/ingresso-uscita.service /tmp/
   ```

2. Modifica con i tuoi percorsi:
   ```bash
   nano /tmp/ingresso-uscita.service
   # Sostituisci YOUR_USERNAME e i percorsi
   ```

3. Installa:
   ```bash
   sudo cp /tmp/ingresso-uscita.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable ingresso-uscita
   sudo systemctl start ingresso-uscita
   ```

4. Verifica:
   ```bash
   sudo systemctl status ingresso-uscita
   ```

Vedi `SYSTEMD_SETUP.md` per dettagli completi.

## ✅ Checklist Post-Installazione

- [ ] Server installato correttamente
- [ ] Nodemailer verificato funzionante
- [ ] Servizio systemd/PM2 configurato
- [ ] Avvio automatico abilitato
- [ ] Email configurate (Gmail App Password)
- [ ] Variabile `DAILY_REPORT_TIME` impostata
- [ ] IP del server configurato nell'app Flutter
- [ ] Test email inviato con successo
- [ ] Server accessibile dalla rete locale

## 🆘 Troubleshooting

### Errore: nodemailer.createTransporter is not a function

**Soluzione:**
```bash
cd ~/ingresso_uscita_server
npm uninstall nodemailer
npm install nodemailer@6.9.7
node -e "const nm = require('nodemailer'); console.log(typeof nm.createTransport);"
```

Se ancora non funziona, il file `server.js` nel repository è già aggiornato.

### Servizio systemd non parte

**1. Controlla i log:**
```bash
sudo journalctl -u ingresso-uscita -n 50
```

**2. Verifica percorsi:**
```bash
sudo systemctl status ingresso-uscita
# Controlla WorkingDirectory e ExecStart
```

**3. Testa manualmente:**
```bash
cd ~/ingresso_uscita_server
node server.js
```

Vedi `SYSTEMD_SETUP.md` per troubleshooting completo.

## 📚 Documentazione

- **Setup Server:** `setup_server.sh` (questo script)
- **systemd:** `server/SYSTEMD_SETUP.md`
- **Email:** `server/SETUP_EMAIL.md`
- **Turni Notturni:** `server/TURNI_NOTTURNI.md`
- **Sistema Email:** `server/EMAIL_SISTEMA.md`

## 🎉 Conclusione

Il setup è ora completamente automatizzato con supporto per systemd nativo. 

**Vantaggi:**
- ✅ Un solo comando per installare tutto
- ✅ Verifica automatica di tutte le dipendenze
- ✅ Configurazione systemd guidata
- ✅ Fix nodemailer automatico
- ✅ Documentazione completa inclusa

**Prossimi passi:**
1. Configura le credenziali email in `email_config.json`
2. Personalizza `DAILY_REPORT_TIME` se necessario
3. Configura l'IP nell'app Flutter
4. Goditi il sistema automatico! 🎊
