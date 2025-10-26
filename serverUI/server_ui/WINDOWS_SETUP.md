# 🪟 Guida Setup Windows - Sinergy Work Server Manager

Guida completa per installare e configurare il Server Manager su Windows 10/11.

## 📋 Prerequisiti

### 1. Node.js
Il Server Manager richiede Node.js per eseguire i server.

**Download**: https://nodejs.org/

**Installazione**:
1. Scarica la versione LTS (Long Term Support)
2. Esegui l'installer
3. ✅ Assicurati di selezionare "Add to PATH" durante l'installazione
4. Riavvia il computer dopo l'installazione

**Verifica Installazione**:
```powershell
node --version
npm --version
```

Dovresti vedere le versioni installate (es. `v20.x.x` e `10.x.x`).

### 2. Flutter SDK (solo per sviluppatori)
Se vuoi compilare l'applicazione dal codice sorgente.

**Download**: https://docs.flutter.dev/get-started/install/windows

## 🚀 Installazione

### Opzione A: Usa il Build Pre-compilato (Consigliato)

1. **Scarica il Build**
   - Vai nella cartella: `build\windows\x64\runner\Release\`
   - Copia l'intera cartella `Release` dove preferisci (es. `C:\Program Files\SinergyWork\`)

2. **⚠️ IMPORTANTE: Copia la Cartella Server Template**
   
   L'applicazione ha bisogno dei file template del server per creare nuove istanze.
   
   **Metodo Automatico (Consigliato)**:
   ```powershell
   cd "c:\Users\[TUO_UTENTE]\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui"
   .\setup-server-template.ps1
   ```
   
   **Metodo Manuale**:
   - Copia la cartella `..\server` (dalla cartella `serverUI`)
   - Incollala in `build\windows\x64\runner\Release\server`
   
   Struttura finale:
   ```
   Release\
   ├── server_ui.exe
   ├── server\          ← IMPORTANTE!
   │   ├── server.js
   │   ├── package.json
   │   ├── db.js
   │   └── routes\
   └── data\
   ```

3. **Crea un Collegamento**
   - Click destro su `server_ui.exe`
   - Seleziona "Crea collegamento"
   - Sposta il collegamento sul Desktop o nella barra delle applicazioni

4. **Avvia l'Applicazione**
   - Doppio click su `server_ui.exe` o sul collegamento

### Opzione B: Compila dal Codice Sorgente

```powershell
# Naviga nella cartella del progetto
cd "c:\Users\[TUO_UTENTE]\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui"

# Installa le dipendenze
flutter pub get

# Compila per Windows (Release)
flutter build windows --release

# L'eseguibile sarà in: build\windows\x64\runner\Release\server_ui.exe
```

## 🎯 Primo Utilizzo

### 1. Verifica Node.js
Prima di aggiungere un server, assicurati che Node.js sia installato:

```powershell
node --version
```

Se ricevi un errore, reinstalla Node.js e riavvia il PC.

### 2. Prepara il Server Node.js
Assicurati di avere:
- ✅ Cartella del server (contenente `server.js`)
- ✅ Database SQLite (file `.db`)
- ✅ File `package.json` con le dipendenze

**Esempio Struttura**:
```
C:\SinergyWork\Server\
├── server.js
├── package.json
├── package-lock.json
├── ingresso_uscita.db
└── node_modules\ (verrà creata automaticamente)
```

### 3. Aggiungi un Server nell'UI

1. **Avvia Server Manager**
2. **Clicca "➕ Aggiungi Server"**
3. **Compila i campi**:
   - **Nome**: `Server Produzione` (o quello che preferisci)
   - **Porta**: `3000` (o una porta libera)
   - **Percorso Server**: `C:\SinergyWork\Server\server.js`
   - **Percorso Database**: `C:\SinergyWork\Server\ingresso_uscita.db`
4. **Clicca "Crea Server"**

### 4. Avvia il Server

1. Nella card del server, clicca **"▶️ Avvia"**
2. L'applicazione:
   - Controllerà se `node_modules` esiste
   - Se non esiste, eseguirà `npm install` (può richiedere alcuni minuti)
   - Avvierà il server
3. Lo stato cambierà da "Fermato" → "Avvio..." → "In esecuzione"
4. Verifica i log per confermare l'avvio corretto

## 🔧 Configurazione Avanzata

### Auto-Start all'Avvio di Windows

**Metodo 1: Cartella Avvio**
1. Premi `Win + R`
2. Digita `shell:startup` e premi Enter
3. Crea un collegamento a `server_ui.exe` in questa cartella

**Metodo 2: Utilità di Pianificazione**
1. Apri "Utilità di pianificazione"
2. Crea un'attività di base
3. Trigger: All'avvio del sistema
4. Azione: Avvia programma → `server_ui.exe`

### Esegui come Servizio Windows (Avanzato)

Per eseguire il Server Manager come servizio Windows:

1. **Usa NSSM (Non-Sucking Service Manager)**
   - Download: https://nssm.cc/download
   
2. **Installa il Servizio**:
   ```powershell
   nssm install SinergyWorkManager "C:\Path\To\server_ui.exe"
   ```

3. **Configura e Avvia**:
   ```powershell
   nssm start SinergyWorkManager
   ```

### Firewall Windows

Se il server deve essere accessibile dalla rete:

1. **Apri Windows Defender Firewall**
2. **Impostazioni avanzate** → **Regole connessioni in entrata**
3. **Nuova regola**:
   - Tipo: Porta
   - Protocollo: TCP
   - Porta specifica: `3000` (o la porta del tuo server)
   - Azione: Consenti connessione
   - Nome: `Sinergy Work Server`

## ⚠️ Risoluzione Problemi Windows

### "Node.js non trovato nel PATH"

**Causa**: Node.js non è installato o non è nel PATH.

**Soluzione**:
1. Verifica installazione: `node --version` in PowerShell
2. Se non funziona:
   - Reinstalla Node.js da https://nodejs.org
   - Durante l'installazione, seleziona "Add to PATH"
   - Riavvia il computer
3. Aggiungi manualmente al PATH:
   - Cerca "Variabili d'ambiente" nel menu Start
   - Modifica la variabile `Path`
   - Aggiungi: `C:\Program Files\nodejs\`

### "npm non trovato"

**Soluzione**:
```powershell
# Verifica la versione di npm
npm --version

# Se manca, reinstalla Node.js (npm è incluso)
```

### System Tray non Funziona

**Causa**: Il package `system_tray` può essere instabile su Windows.

**Comportamento**: L'icona non appare nel system tray, ma l'applicazione funziona normalmente.

**Soluzione**: Non è un problema critico, usa l'applicazione dalla taskbar.

### ### "npm error code ENOENT" / "Could not read package.json"

**Causa**: I file template del server non sono stati copiati correttamente.

**Errore tipico**:
```
npm error code ENOENT
npm error syscall open
npm error path C:\Users\...\IngressoUscita_Servers\...\package.json
npm error errno -4058
```

**Soluzione**:

1. **Verifica che la cartella `server` esista** accanto all'eseguibile:
   ```
   Release\
   ├── server_ui.exe
   └── server\  ← Deve esistere!
   ```

2. **Se manca, copiala manualmente o usa lo script**:
   ```powershell
   # Dalla cartella del progetto
   .\setup-server-template.ps1
   ```
   
3. **Oppure ricompila con il fix**:
   ```powershell
   flutter build windows --release
   # Poi esegui setup-server-template.ps1
   ```

Vedi anche: `SETUP_SERVER_TEMPLATE_WINDOWS.md`

### "Port already in use"

**Causa**: Un altro programma sta usando la porta.

**Soluzione**:
```powershell
# Trova quale processo usa la porta 3000
netstat -ano | findstr :3000

# Termina il processo (sostituisci PID con il numero trovato)
taskkill /PID [PID] /F
```

### Server non si Avvia

**Verifica**:
1. I log nella card del server mostrano errori?
2. Il percorso di `server.js` è corretto?
3. Node.js è installato? (`node --version`)
4. Le dipendenze npm sono installate?

**Soluzione Manuale**:
```powershell
# Vai nella cartella del server
cd C:\Path\To\Server

# Installa dipendenze manualmente
npm install

# Prova ad avviare manualmente
node server.js
```

### "EPERM: operation not permitted"

**Causa**: Permessi insufficienti o antivirus che blocca.

**Soluzione**:
1. Esegui l'applicazione come Amministratore (click destro → "Esegui come amministratore")
2. Aggiungi eccezione nell'antivirus per la cartella del server
3. Disabilita temporaneamente Windows Defender durante l'installazione npm

### Errori di Build (per sviluppatori)

**"Visual Studio not found"**:
- Installa Visual Studio Build Tools
- Download: https://visualstudio.microsoft.com/downloads/
- Seleziona "Desktop development with C++"

**"CMake not found"**:
- Flutter 3.9+ include CMake
- Esegui `flutter doctor -v` per diagnosticare

## 📊 Monitoraggio Performance

### Task Manager
Per monitorare l'uso di risorse:
1. Apri Task Manager (`Ctrl + Shift + Esc`)
2. Cerca `server_ui.exe` e i processi `node.exe`
3. Monitora CPU, RAM, e Network

### Logs Avanzati
Per debug avanzato, esegui da PowerShell:

```powershell
# Abilita log verbose
$env:FLUTTER_LOG=1
.\server_ui.exe
```

## 🔐 Sicurezza

### Consigli:
- 🔒 **Non esporre il server direttamente su Internet** senza HTTPS
- 🔒 **Usa firewall** per limitare l'accesso alla rete locale
- 🔒 **Backup regolari** del database
- 🔒 **Aggiorna Node.js** regolarmente

### Backup Automatico (Script PowerShell)
```powershell
# backup_server.ps1
$source = "C:\SinergyWork\Server\ingresso_uscita.db"
$dest = "C:\Backup\ingresso_uscita_$(Get-Date -Format 'yyyyMMdd_HHmmss').db"
Copy-Item $source $dest
```

Pianifica questo script con l'Utilità di Pianificazione.

## 📞 Supporto

Se riscontri problemi non coperti da questa guida:

1. Controlla i log dell'applicazione
2. Verifica i requisiti di sistema
3. Consulta la documentazione principale: [README.md](README.md)
4. Apri una issue su GitHub

## 🎓 Risorse Utili

- **Node.js Download**: https://nodejs.org/
- **Flutter Windows Setup**: https://docs.flutter.dev/get-started/install/windows
- **NSSM (Windows Service)**: https://nssm.cc/
- **Visual Studio Build Tools**: https://visualstudio.microsoft.com/downloads/

---

**Fatto con ❤️ per Windows users**
