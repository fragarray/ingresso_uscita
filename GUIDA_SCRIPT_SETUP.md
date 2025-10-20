# 📘 Guida Script di Setup e Aggiornamento

## 🎯 Panoramica

Questo progetto include tre script bash per gestire l'installazione e l'aggiornamento del server su Raspberry Pi o sistemi Linux.

---

## 📂 Script Disponibili

### 1. `setup_server_fixed.sh` - **Installazione Completa**

**Quando usarlo:**
- ✅ Prima installazione su un nuovo Raspberry Pi
- ✅ Installazione da zero su un server Linux
- ✅ Reinstallazione completa dopo aver rimosso tutto

**Dove eseguirlo:**
```bash
cd ~                    # Vai nella home del Raspberry
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh
bash setup_server_fixed.sh
```

**Cosa fa:**
1. Installa Node.js (se non presente)
2. Installa build-essentials e dipendenze
3. Crea directory `~/ingresso_uscita_server`
4. Scarica i file dal repository GitHub
5. Installa dipendenze npm
6. Configura email_config.json
7. Configura servizio systemd o PM2
8. Avvia il server

**Directory creata:**
```
~/ingresso_uscita_server/
├── server.js
├── db.js
├── package.json
├── migrate_username_auth.js
├── email_config.json
├── backup_settings.json
├── routes/
├── backups/
└── ...
```

---

### 2. `update_server.sh` - **Aggiornamento Rapido**

**Quando usarlo:**
- ✅ Aggiornare il server con le ultime modifiche
- ✅ Applicare nuove funzionalità
- ✅ Eseguire migrazioni del database

**Dove eseguirlo:**
```bash
cd ~                    # QUALSIASI CARTELLA va bene
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
bash update_server.sh
```

**Cosa fa:**
1. Chiede dove si trova la cartella del server (default: `~/ingresso_uscita_server`)
2. Crea backup del database
3. Crea backup delle configurazioni
4. Scarica aggiornamenti da GitHub
5. **RILEVA automaticamente se serve migrazione database**
6. Esegue migrazione in modo interattivo (se necessario)
7. Aggiorna dipendenze npm
8. Ripristina configurazioni
9. Riavvia il servizio

**⚠️ IMPORTANTE - Aggiornamento v1.2.0:**

Se hai una versione precedente del server, questo script:
- Rileva automaticamente se il database usa ancora email per login
- Propone la migrazione a username-based authentication
- Esegue `migrate_username_auth.js` in modo guidato
- Crea backup automatico prima della migrazione
- Mostra gli username generati per ogni utente

**Cosa viene preservato:**
- ✅ Database (con backup)
- ✅ email_config.json
- ✅ backup_settings.json
- ✅ Cartella backups/
- ✅ Password utenti (invariate)

---

### 3. `setup_server_ubuntu_core.sh` - **Setup per Ubuntu Core**

**Quando usarlo:**
- ✅ Installazione su Ubuntu Core (sistema snap-based)
- ⚠️ NON usare su Raspberry Pi OS standard

---

## 🔄 Flusso Tipico di Utilizzo

### Prima Installazione
```bash
# Sul Raspberry Pi
cd ~
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh
bash setup_server_fixed.sh

# Lo script ti guiderà attraverso:
# 1. Installazione Node.js
# 2. Creazione directory
# 3. Download codice
# 4. Configurazione systemd/PM2
# 5. Avvio server
```

### Aggiornamento (dopo qualche settimana/mese)
```bash
# Sul Raspberry Pi - da QUALSIASI cartella
cd ~
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
bash update_server.sh

# Lo script chiederà:
# "Directory del server [/home/pi/ingresso_uscita_server]:"
# Premi INVIO per usare il default, o digita il percorso

# Se rileva database vecchio:
# "Vuoi eseguire la migrazione ora? [s/N]"
# Digita 's' per procedere
```

---

## 🗂️ Struttura Directory Tipica

```
/home/pi/                                    # Home del Raspberry
│
├── setup_server_fixed.sh                    # Script scaricato (eliminabile dopo setup)
├── update_server.sh                         # Script scaricato (eliminabile dopo update)
│
└── ingresso_uscita_server/                  # Directory del server
    ├── server.js                            # Server principale
    ├── db.js                                # Gestione database
    ├── package.json                         # Dipendenze npm
    ├── migrate_username_auth.js             # Script migrazione
    ├── email_config.json                    # Configurazione email (PRESERVATO)
    ├── backup_settings.json                 # Configurazione backup (PRESERVATO)
    ├── ingresso_uscita.db                   # Database SQLite (PRESERVATO)
    │
    ├── routes/                              # API routes
    │   ├── worksites.js
    │   └── ...
    │
    ├── backups/                             # Backup automatici (PRESERVATI)
    │   ├── db_backup_20251020_143022.db
    │   └── ...
    │
    └── node_modules/                        # Dipendenze (ricreate ad ogni update)
```

---

## 🆕 Migrazione v1.2.0 - Da Email a Username

### Cosa Cambia?
- **PRIMA (v1.1.x):** Login con `email` + `password`
- **ADESSO (v1.2.0):** Login con `username` + `password`

### La Migrazione è Automatica?
✅ **Sì!** Lo script `update_server.sh` rileva automaticamente se il tuo database è vecchio e ti guida attraverso la migrazione.

### Cosa Fa la Migrazione?
```javascript
// PRIMA (nel database)
{
  id: 1,
  name: "Mario Rossi",
  email: "mario.rossi@example.com",  // Usato per login
  password: "123456",
  isAdmin: 1
}

// DOPO (nel database)
{
  id: 1,
  name: "Mario Rossi",
  username: "mario.rossi",           // Nuovo! Generato da email
  email: "mario.rossi@example.com",  // Ora opzionale
  password: "123456",                // INVARIATA
  role: "admin"                      // admin / employee / foreman
}
```

### Username Generati Automaticamente
Lo script crea username dalla parte precedente la `@` nell'email:
- `admin@example.com` → `admin`
- `mario.rossi@gmail.com` → `mario.rossi`
- `giovanni@site.it` → `giovanni`

Se ci sono duplicati, aggiunge suffisso numerico:
- `admin@example.com` → `admin`
- `admin@other.com` → `admin_1`
- `admin@third.com` → `admin_2`

### Comunicare le Credenziali agli Utenti
Dopo la migrazione, lo script mostra gli username generati. Devi comunicarli agli utenti:

**Template Email:**
```
Ciao [Nome],

Il sistema di timbrature è stato aggiornato.

Nuove credenziali di accesso:
• Username: mario.rossi
• Password: [stessa di prima]

Da ora in poi usa lo username invece dell'email per accedere.

Grazie,
Amministrazione
```

---

## ❓ FAQ

### D: Dove devo eseguire `update_server.sh`?
**R:** Puoi eseguirlo da **qualsiasi cartella**. Lo script ti chiederà dove si trova la directory del server.

```bash
# Tutti questi funzionano:
cd ~ && bash update_server.sh
cd /tmp && bash update_server.sh
cd /home/pi/Download && bash update_server.sh
```

### D: Posso eseguire `update_server.sh` dentro la cartella del server?
**R:** Sì, funziona anche così:
```bash
cd ~/ingresso_uscita_server
bash ../update_server.sh
# (premi INVIO quando chiede il percorso, userà la directory corrente)
```

### D: E se cancello accidentalmente uno script?
**R:** Scaricalo di nuovo da GitHub:
```bash
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
```

### D: La migrazione è reversibile?
**R:** La migrazione crea un backup automatico. Se qualcosa va male:
```bash
cd ~/ingresso_uscita_server/backups
ls -lh                                    # Trova il backup più recente
cp db_backup_20251020_143022.db ../ingresso_uscita.db
```

### D: Cosa succede se rifiuto la migrazione?
**R:** Il server **NON funzionerà** con il vecchio database. La v1.2.0 richiede le colonne `username` e `role`.

### D: Devo fermare il server prima di aggiornare?
**R:** No, lo script lo fa automaticamente. Ferma il servizio, aggiorna, e riavvia.

### D: Quanto tempo richiede l'aggiornamento?
**R:** 
- Download codice: ~30 secondi
- Aggiornamento npm: ~2-5 minuti
- Migrazione database: ~5 secondi
- **Totale: ~3-6 minuti**

### D: Posso vedere i log durante l'aggiornamento?
**R:** Sì, lo script mostra tutto in tempo reale. Alla fine suggerisce:
```bash
# Per systemd
sudo journalctl -u ingresso-uscita -f

# Per PM2
pm2 logs ingresso-uscita
```

---

## 🚨 Risoluzione Problemi

### Errore: "Directory non trovata"
```bash
# Lo script non trova la directory del server
# Soluzione: specifica il percorso esatto
bash update_server.sh
# Quando chiede: digita il percorso completo, es:
/home/pi/mio_server_custom
```

### Errore: "git: command not found"
```bash
# Git non installato
sudo apt-get update
sudo apt-get install -y git
```

### Errore: "npm install" fallisce
```bash
# Dipendenze di build mancanti
sudo apt-get install -y build-essential python3

# Poi riprova
cd ~/ingresso_uscita_server
npm install
```

### Migrazione fallita
```bash
# Ripristina backup
cd ~/ingresso_uscita_server
cp backups/db_backup_[TIMESTAMP].db ingresso_uscita.db

# Riprova manualmente
node migrate_username_auth.js
```

### Server non si avvia dopo update
```bash
# Controlla i log
sudo journalctl -u ingresso-uscita -n 100

# Oppure prova avvio manuale
cd ~/ingresso_uscita_server
node server.js

# Leggi l'errore e agisci di conseguenza
```

---

## 📚 Documentazione Correlata

- **CHANGELOG_USERNAME_AUTH.md** - Dettagli tecnici sulla migrazione
- **CREDENZIALI_MIGRAZIONE.md** - Template per comunicare credenziali
- **FIX_DATE_RANGE_SELECTION.md** - Fix selezione date nei report
- **SERVER_CONFIG.md** - Configurazione avanzata del server
- **SETUP_EMAIL.md** - Configurazione sistema email

---

## 🎉 Riepilogo Comandi Rapidi

```bash
# PRIMA INSTALLAZIONE
cd ~ && wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh
bash setup_server_fixed.sh

# AGGIORNAMENTO
cd ~ && wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
bash update_server.sh

# VERIFICA STATO SERVER
sudo systemctl status ingresso-uscita              # systemd
pm2 status                                        # PM2

# LOG IN TEMPO REALE
sudo journalctl -u ingresso-uscita -f             # systemd
pm2 logs ingresso-uscita                          # PM2

# RIAVVIO MANUALE
sudo systemctl restart ingresso-uscita            # systemd
pm2 restart ingresso-uscita                       # PM2

# TEST CONNESSIONE
curl http://localhost:3000/api/ping               # Da Raspberry
curl http://[IP_RASPBERRY]:3000/api/ping          # Da altro PC
```

---

**Ultimo aggiornamento:** 20 Ottobre 2025  
**Versione server:** v1.2.0  
**Compatibilità:** Raspberry Pi OS, Ubuntu, Debian
