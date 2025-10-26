# 🧪 Test Server Manager - Verifica Funzionamento

## ✅ Checklist Verifica Completa

### 1. 📱 Avvio Applicazione
```bash
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui
./build/linux/arm64/release/bundle/server_ui
```

**Controlli:**
- [ ] ✅ Applicazione si avvia senza errori
- [ ] 🖥️ System tray inizializzato correttamente  
- [ ] 📺 Finestra principale visibile
- [ ] 🎨 UI responsive e funzionale

### 2. ➕ Creazione Server

**Passi:**
1. Click **"Aggiungi Server"**
2. Click **"Configura Server Ingresso/Uscita"** (pulsante arancione)
3. Verifica campi auto-compilati:
   - Nome: `Server Ingresso/Uscita`
   - Porta: `3000` (o prima disponibile)
   - Server.js: `/home/tom/ingrARM/ingresso_uscita/serverUI/server/server.js`
   - Database: `/home/tom/ingrARM/ingresso_uscita/serverUI/server/database.db`
4. Click **"Crea Server"**

**Controlli:**
- [ ] ✅ Server creato con successo
- [ ] 📋 Card server visibile nella griglia
- [ ] 🔴 Stato iniziale: "Fermato"
- [ ] ℹ️ Informazioni server corrette

### 3. 🚀 Avvio Server

**Passi:**
1. Click sulla card del server creato
2. Click **"▶ Avvia Server"**
3. Monitorare i log nella schermata dettagli

**Log Attesi:**
```
📦 Preparazione avvio server...
📦 Installazione dipendenze npm in corso...
✅ Dipendenze installate correttamente
🚀 Avvio processo Node.js...
⏳ Attendo che il server sia pronto... (5s)
✅ Server avviato correttamente su porta 3000
```

**Controlli:**
- [ ] 🟡 Stato cambia in "Avvio..." 
- [ ] 📦 npm install eseguito (se necessario)
- [ ] 🟢 Stato finale: "In esecuzione"
- [ ] 📊 Log in tempo reale visibili
- [ ] ⚡ Porta configurata raggiungibile

### 4. 🔗 Verifica API Server

**Test Health Check:**
```bash
curl http://localhost:3000/api/ping
```

**Risposta Attesa:**
```json
{
  "success": true,
  "message": "Ingresso/Uscita Server",
  "version": "1.0.0",
  "timestamp": "2025-10-26T10:00:00.000Z",
  "serverIdentity": "ingresso-uscita-server"
}
```

**Test Login:**
```bash
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

**Controlli:**
- [ ] ✅ Health check ritorna 200 OK
- [ ] 🔑 Login admin funziona
- [ ] 📋 API risponde correttamente
- [ ] 🌐 Server pienamente operativo

### 5. 🛑 Stop Server

**Passi:**
1. Dalla schermata dettagli server
2. Click **"⏹ Ferma Server"**
3. Conferma nella dialog

**Log Attesi:**
```
🛑 Arresto server in corso...
✅ Server arrestato correttamente
```

**Controlli:**
- [ ] 🟡 Stato cambia in "Arresto..."
- [ ] 🔴 Stato finale: "Fermato"
- [ ] ⏹ Processo Node.js terminato
- [ ] 📊 Log arresto visibili

### 6. 🖥️ System Tray

**Test Minimizzazione:**
1. Click **X** per chiudere finestra
2. L'app deve minimizzarsi in system tray

**Test Menu Tray:**
1. Click destro sull'icona tray
2. Verifica menu contestuale:
   - "Mostra/Nascondi"
   - "Ferma tutti i server"
   - "Esci"

**Controlli:**
- [ ] 📱 App si minimizza correttamente
- [ ] 🖱️ Menu tray funzionale
- [ ] 🔄 Ripristino da tray funziona
- [ ] ❌ Uscita da tray termina app

### 7. 💾 Persistenza Dati

**Test Restart:**
1. Chiudi completamente l'applicazione
2. Riapri l'applicazione
3. Verifica che il server creato sia ancora presente

**Test Logs:**
1. Avvia server
2. Lascia girare per qualche minuto
3. Ferma e riavvia server
4. Verifica che i log precedenti siano conservati

**Controlli:**
- [ ] 📂 Configurazioni server salvate
- [ ] 📜 Log persistenti tra sessioni
- [ ] 🔄 Stato server corretto al restart
- [ ] 💿 SharedPreferences funziona

### 8. 🎛️ Multi-Server

**Test Server Multipli:**
1. Crea un secondo server con porta diversa (3001)
2. Avvia entrambi i server
3. Verifica che funzionino simultaneamente

**Controlli:**
- [ ] 📊 Gestione multi-server
- [ ] 🚫 Controllo porte duplicate
- [ ] ⚡ Server indipendenti
- [ ] 📈 Performance accettabili

### 9. 🔧 Gestione Errori

**Test Porta Occupata:**
1. Avvia server su porta 3000
2. Crea nuovo server con stessa porta
3. Tenta avvio secondo server

**Test File Mancanti:**
1. Crea server con path server.js inesistente
2. Tenta avvio server

**Controlli:**
- [ ] ❌ Errore porta occupata gestito
- [ ] 🚫 Validazione file esistenti
- [ ] 📋 Messaggi errore chiari
- [ ] 🔄 Recovery da errori

---

## 🎯 Risultati Attesi

### ✅ Test Completato Con Successo

Tutti i punti della checklist superati:
- **Applicazione**: Stabile e responsive
- **Server Management**: Completo e funzionale  
- **API Integration**: Server reale operativo
- **System Tray**: Integrazione desktop perfetta
- **Persistenza**: Dati salvati correttamente
- **Error Handling**: Gestione errori robusta

### 📈 Performance Benchmark

**Tempi Attesi:**
- Avvio app: < 3 secondi
- Creazione server: < 1 secondo  
- Avvio server: 10-30 secondi (include npm install)
- Health check: < 1 secondo
- Stop server: < 3 secondi

### 🏆 Criteri Successo

**Funzionalità Core:**
- ✅ Gestione completa ciclo vita server
- ✅ Integrazione server Node.js reale
- ✅ UI/UX fluida e intuitiva
- ✅ System tray pienamente funzionale
- ✅ Monitoraggio real-time
- ✅ Gestione multi-server
- ✅ Persistenza configurazioni
- ✅ Error handling robusto

**Deployment Ready:**
- ✅ Build release funziona
- ✅ Eseguibile autonomo
- ✅ Dipendenze sistema soddisfatte
- ✅ Documentazione completa

---

## 🐛 Troubleshooting Test

### Problemi Comuni

#### App non si avvia
```bash
# Verifica dipendenze
ldd build/linux/arm64/release/bundle/server_ui

# Reinstalla system tray
sudo apt-get install --reinstall libayatana-appindicator3-dev
```

#### npm install fallisce
```bash
# Controllo manuale
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server
rm -rf node_modules package-lock.json
npm install
```

#### Server non risponde
```bash
# Debug processo
ps aux | grep node
netstat -tlpn | grep :3000
```

### Log Debugging

**Livelli Log:**
- 📋 INFO: Operazioni normali
- ⚠️ WARNING: Situazioni anomale
- ❌ ERROR: Errori da correggere
- 🐛 DEBUG: Dettagli tecnici

---

**Test Version**: 1.0.0
**Test Date**: 26 ottobre 2025
**Platform**: Linux ARM64