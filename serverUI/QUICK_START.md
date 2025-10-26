# 🚀 Quick Start Guide - Server Manager UI

## 🎯 Test Rapido dell'Applicazione

L'applicazione Server Manager UI è stata creata con successo! Ecco come testarla rapidamente.

### 📋 Prerequisiti Verificati
- ✅ Flutter installato e funzionante
- ✅ Dipendenze system tray installate (`libayatana-appindicator3-dev`)
- ✅ Node.js disponibile per i server
- ✅ Applicazione compilata correttamente

### 🔧 Setup Test Environment

1. **L'applicazione è già compilata** in:
   ```
   /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui/build/linux/arm64/release/bundle/server_ui
   ```

2. **Il server di test** è configurato in:
   ```
   /home/tom/ingrARM/ingresso_uscita/serverUI/test-server.js
   ```

### 🏃‍♂️ Avvio dell'Applicazione

#### Metodo 1: Eseguibile Diretto
```bash
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui
./build/linux/arm64/release/bundle/server_ui
```

#### Metodo 2: Da Flutter (se hai problemi con permessi)
```bash
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui
flutter build linux --release && ./build/linux/arm64/release/bundle/server_ui
```

### 📱 Test dell'Interfaccia

1. **All'avvio** vedrai:
   - Finestra con titolo "Server Manager"
   - Griglia vuota con messaggio "Nessun server configurato"
   - Pulsante "Aggiungi Server" al centro

2. **System Tray** (se supportato):
   - Icona dovrebbe apparire nel system tray
   - Click destro per menu contestuale

### 🎛️ Creazione Primo Server

1. **Clicca "Aggiungi Server"** o la carta "➕ Aggiungi Server"

2. **Compila il form:**
   - **Nome**: "Test Server"
   - **Porta**: 3001 (o qualsiasi porta libera suggerita)
   - **Cartella**: `/home/tom/ingrARM/ingresso_uscita/serverUI`

3. **Clicca "Crea Server"**

### ▶️ Test Avvio/Arresto Server

1. **Nella griglia principale**, vedrai la carta del server creato
2. **Clicca il pulsante ▶️ (play)** per avviare il server
3. **Osserva i cambiamenti:**
   - Icona diventa verde 🟢
   - Stato cambia in "In esecuzione"
   - Pulsante diventa ⏹️ (stop)

4. **Per fermare:** clicca il pulsante ⏹️ (stop)

### 👁️ Visualizzazione Dettagli e Log

1. **Clicca sulla carta del server** (non sui pulsanti)
2. **Schermata dettagli** con 3 tab:
   - **Info**: Informazioni complete del server
   - **Log**: Output in tempo reale del server Node.js
   - **Config**: Configurazioni avanzate

3. **Nel tab Log** vedrai:
   - Output completo del server di test
   - Log colorati e timestamp
   - Scroll automatico agli ultimi messaggi

### 🧪 Test delle API del Server

Una volta avviato il server, puoi testarlo:

```bash
# Health check
curl http://localhost:3001/health

# Informazioni server
curl http://localhost:3001/info

# Homepage
curl http://localhost:3001/

# Test carico
curl "http://localhost:3001/work?iterations=100000"

# Test errore
curl http://localhost:3001/error
```

### 📱 Test System Tray

1. **Minimizza l'applicazione** (X sulla finestra)
   - Se hai server attivi, va nel tray
   - Se non hai server attivi, si chiude

2. **Menu Tray** (click destro sull'icona):
   - "Server attivi: X/Y"
   - "Mostra Applicazione"
   - "Ferma tutti i server"
   - "Esci"

3. **Per riaprire:** click sull'icona nel tray

### 🔍 Risoluzione Problemi

#### Application non si avvia
```bash
# Verifica dipendenze
flutter doctor

# Ricompila se necessario
cd /home/tom/ingrARM/ingresso_uscita/serverUI/server_ui
flutter clean
flutter pub get
flutter build linux --release
```

#### System Tray non visibile
- Normal su alcuni desktop environment
- L'app funziona comunque, solo senza minimizzazione nel tray
- Controlla disponibilità tray area nel desktop

#### Server non si avvia
- Verifica che Node.js sia installato: `node --version`
- Controlla che la porta non sia già in uso
- Guarda i log nella schermata dettagli per errori specifici

#### Porta già in uso
- L'app suggerisce automaticamente porte libere
- Puoi cambiare manualmente nella creazione server
- Usa `netstat -tlnp | grep :PORTA` per verificare

### 🎯 Feature da Testare

- [ ] ✅ **Creazione server multipli** (prova con porte diverse)
- [ ] ✅ **Avvio simultaneo** di più server
- [ ] ✅ **Visualizzazione log** in tempo reale
- [ ] ✅ **System tray** minimizzazione e ripristino
- [ ] ✅ **Menu contestuali** e controlli rapidi
- [ ] ✅ **Persistenza** (riavvia app e verifica server salvati)
- [ ] ✅ **Gestione errori** (porta occupata, server crashato)
- [ ] ✅ **Riavvio server** dalla schermata dettagli

### 📊 Output Atteso

**Console del Server di Test:**
```
==================================================
🚀 Server di test per Server Manager UI
📅 Avviato: 2025-10-26T...
🌐 Porta: 3001
💾 Database path: /home/tom/ingrARM/ingresso_uscita/serverUI
==================================================
✅ Server HTTP attivo sulla porta 3001
📝 Log periodico #1 - 26/10/2025, ...
📝 Log periodico #2 - 26/10/2025, ...
```

**App Server Manager:**
- Carta server verde con stato "In esecuzione"
- Log tab mostra tutti i messaggi del server
- System tray mostra "Server attivi: 1/1"

### 🎉 Successo!

Se tutto funziona:
- ✅ Puoi creare e gestire server multipli
- ✅ System tray funziona (se supportato dal desktop)
- ✅ Log vengono catturati correttamente
- ✅ Stato server aggiornato in real-time
- ✅ Configurazioni persistono tra riavvii

**L'applicazione Server Manager UI è completamente funzionante!** 🎊

---

### 📞 Supporto

Per problemi o domande:
- Controlla i log dell'applicazione nel terminale
- Verifica che tutte le dipendenze siano installate
- Testa prima il server Node.js separatamente
- Consulta la documentazione completa in `README.md`