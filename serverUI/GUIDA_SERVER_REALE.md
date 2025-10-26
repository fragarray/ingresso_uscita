# 🚀 Guida Server Manager - Gestione Server Reale

## 📋 Panoramica

Il **Server Manager** ora può gestire il vero server **Ingresso/Uscita** Node.js con tutte le sue funzionalità avanzate, inclusa l'installazione automatica delle dipendenze npm.

## 🔧 Prerequisiti

### Sistema
- **Node.js** v16+ (attualmente: v20.19.5 ✅)
- **npm** v8+ (attualmente: v10.8.2 ✅)
- **Linux** con supporto Desktop (Ubuntu/Debian)
- **Flutter** per sviluppo (opzionale)

### Dipendenze Sistema
```bash
# Già installate ✅
sudo apt-get install libayatana-appindicator3-dev
```

## 🏗️ Configurazione Server

### 1. Server Integrato (Consigliato)
Il server Ingresso/Uscita è già copiato in `/home/tom/ingrARM/ingresso_uscita/serverUI/server/`

**Configurazione Rapida:**
1. Apri l'applicazione Server Manager
2. Clicca **"Aggiungi Server"** 
3. Clicca **"Configura Server Ingresso/Uscita"** (pulsante arancione)
4. Verifica i percorsi auto-compilati:
   - **Server.js**: `/home/tom/ingrARM/ingresso_uscita/serverUI/server/server.js`
   - **Database**: `/home/tom/ingrARM/ingresso_uscita/serverUI/server/database.db`
5. Clicca **"Crea Server"**

### 2. Server Personalizzato
Per configurare un server in una posizione diversa:

1. **Nome Server**: Nome descrittivo (es: "Prod Server")
2. **Porta**: Porta disponibile (3000-4000)
3. **Percorso server.js**: Path completo al file server.js
4. **Percorso Database**: Path al file database.db

## 🚀 Funzionalità Automatiche

### Installazione Dipendenze
L'applicazione controlla automaticamente:
- ✅ Esistenza di `node_modules`
- 📦 Installa dipendenze con `npm install` se necessarie
- ⏳ Mostra progresso dell'installazione nei log

### Monitoraggio Server
- 🔍 **Health Check**: Richiesta a `/api/ping` per verificare il server
- ⏰ **Timeout**: 30 secondi per l'avvio
- 📊 **Real-time Logs**: Output STDOUT/STDERR in tempo reale
- 🛡️ **Auto-restart**: Rilevamento crash con notifica

### System Tray
- 🖥️ **Minimizzazione**: L'app si minimizza nella system tray
- ⚡ **Quick Actions**: Avvio/Stop rapido dei server
- 📢 **Notifiche**: Stato dei server nella tray

## 📊 Funzionalità Server Ingresso/Uscita

### Core Features
- 👥 **Gestione Dipendenti** con ruoli (admin, employee, foreman)
- 🏗️ **Gestione Cantieri** con geofencing
- ⏰ **Timbrature** con coordinate GPS
- 📈 **Report Excel** automatici
- 📧 **Email Reports** giornalieri programmati
- 🔄 **Auto-checkout** a mezzanotte
- 🔒 **Audit Log** per amministratori

### API Endpoints
- `GET /api/ping` - Health check
- `POST /api/login` - Autenticazione
- `GET /api/employees` - Lista dipendenti
- `GET /api/attendance` - Timbrature
- `POST /api/attendance` - Nuova timbratura
- `GET /api/worksites` - Lista cantieri

### Database
**SQLite** con schema completo:
- `employees` - Dipendenti e amministratori
- `attendance_records` - Timbrature
- `work_sites` - Cantieri
- `audit_log` - Log operazioni admin
- `app_settings` - Configurazioni

## 🎛️ Uso dell'Applicazione

### Avvio Server
1. **Seleziona Server**: Click sulla card del server
2. **Start Button**: Pulsante verde "▶ Avvia"
3. **Monitoraggio**: I log mostrano:
   ```
   📦 Installazione dipendenze npm in corso...
   ✅ Dipendenze installate correttamente
   🚀 Avvio processo Node.js...
   ⏳ Attendo che il server sia pronto... (5s)
   ✅ Server avviato correttamente su porta 3000
   ```

### Gestione Logs
- 📜 **Real-time**: Log in tempo reale nella schermata dettagli
- 🔍 **Filtri**: Cerca nel log per debugging
- 💾 **Persistenza**: Log salvati tra le sessioni
- 🧹 **Limite**: Massimo 1000 righe per server

### Stop Server
1. **Stop Button**: Pulsante rosso "⏹ Ferma"
2. **Graceful Shutdown**: Il server termina pulitamente
3. **Force Kill**: Terminazione forzata dopo timeout

## 🛠️ Troubleshooting

### Errori Comuni

#### Porta già in uso
```
❌ Errore nell'avvio del server: Porta 3000 già in uso
```
**Soluzione**: Cambia porta nelle impostazioni server

#### Dipendenze mancanti
```
📦 Installazione dipendenze npm in corso...
❌ Errore installazione dipendenze
```
**Soluzione**: 
```bash
cd /path/to/server
npm install
```

#### Timeout avvio
```
❌ Timeout: il server non risponde dopo 30 secondi
```
**Soluzione**: 
- Controlla i log per errori
- Verifica che Node.js sia installato
- Controlla permessi file

### Debug Avanzato

#### Log dettagliati
I log mostrano:
- 📦 Installazione dipendenze
- 🚀 Avvio processo Node.js
- 📊 Output server completo
- ❌ Errori con stack trace

#### Controllo manuale
```bash
# Test manuale server
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server
npm install
PORT=3000 node server.js

# Verifica health check
curl http://localhost:3000/api/ping
```

## 🔒 Sicurezza

### Credenziali Default
- **Username**: `admin`
- **Password**: `admin123`
- **Email**: `admin@example.com`

⚠️ **IMPORTANTE**: Cambia le credenziali al primo accesso!

### Configurazione Sicurezza
- 🔐 Password hashing (da implementare)
- 🛡️ Rate limiting API
- 📝 Audit log completo
- 🚫 Validazione input

## 📈 Monitoraggio Produzione

### Metriche
- ⚡ **Uptime**: Tempo di attività server
- 📊 **Requests**: Numero richieste API
- 👥 **Active Users**: Utenti connessi
- 📈 **Performance**: Tempi di risposta

### Alerts
- 🚨 **Server Down**: Notifica crash
- ⚠️ **High CPU**: Uso risorse elevato
- 🔒 **Security**: Tentativi login falliti

## 🔄 Backup e Ripristino

### Database Backup
```bash
# Backup automatico del database
cp database.db backup_$(date +%Y%m%d_%H%M%S).db
```

### Configurazioni
Le configurazioni server sono salvate in:
- `~/.local/share/server_manager/servers.json`

## 🚀 Deployment Produzione

### Build Release
```bash
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui
flutter build linux --release
```

### Eseguibile
```bash
./build/linux/arm64/release/bundle/server_ui
```

### Autostart
Aggiungi a startup applicazioni o crea service systemd.

---

## 📞 Supporto

Per assistenza:
1. 📋 Controlla i log dell'applicazione
2. 🔍 Verifica prerequisiti sistema
3. 📚 Consulta questa documentazione
4. 🐛 Crea issue con log dettagliati

**Versione**: 1.0.0 con Server Reale
**Data**: 26 ottobre 2025