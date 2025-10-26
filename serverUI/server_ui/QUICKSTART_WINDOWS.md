# ⚡ Quick Start - Windows

Guida rapida per iniziare subito con Sinergy Work Server Manager su Windows.

## 📦 Installazione Rapida (5 minuti)

### Step 1: Node.js
```
1. Vai su https://nodejs.org/
2. Scarica versione LTS
3. Installa (seleziona "Add to PATH")
4. Riavvia il PC
```

Verifica:
```powershell
node --version
npm --version
```

### Step 2: Avvia Server Manager

**Metodo A - Build Precompilato** (se disponibile):
```powershell
cd build\windows\x64\runner\Release
.\server_ui.exe
```

**Metodo B - Compila da Sorgente**:
```powershell
cd serverUI\server_ui
.\build.ps1 build
cd build\windows\x64\runner\Release
.\server_ui.exe
```

### Step 3: Aggiungi il Tuo Primo Server

1. Click su **"➕ Aggiungi Server"**
2. Compila:
   - **Nome**: `Server Locale`
   - **Porta**: `3000`
   - **Percorso Server**: `C:\percorso\al\server.js`
   - **Percorso Database**: `C:\percorso\al\database.db`
3. Click **"Crea Server"**
4. Click **"▶️ Avvia"** sulla card del server

## 🎯 Uso Quotidiano

### Avviare un Server
```
1. Apri Server Manager
2. Click "▶️ Avvia" sulla card del server
3. Attendi che lo stato diventi "In esecuzione"
```

### Fermare un Server
```
1. Click "⏹️ Ferma" sulla card del server
2. Attendi conferma arresto
```

### Visualizzare Log
```
1. Click "📋 Mostra Log" sulla card
2. Leggi output in tempo reale
```

## 🔧 Troubleshooting Rapido

### Problema: "Node.js non trovato"
**Soluzione**: Installa Node.js e riavvia PC

### Problema: "Porta già in uso"
**Soluzione**: Cambia porta o chiudi app che usa quella porta
```powershell
netstat -ano | findstr :3000  # Trova processo
taskkill /PID [numero] /F      # Termina processo
```

### Problema: System Tray non funziona
**Soluzione**: Normale, l'app funziona lo stesso dalla taskbar

### Problema: Server non si avvia
**Soluzione**: Controlla i log nella card del server

## 📚 Documentazione Completa

- **Setup Dettagliato**: [WINDOWS_SETUP.md](WINDOWS_SETUP.md)
- **Compatibilità**: [WINDOWS_COMPATIBILITY.md](WINDOWS_COMPATIBILITY.md)
- **README Completo**: [README.md](README.md)

## 💡 Tips Utili

### Collegamento Desktop
```
1. Click destro su server_ui.exe
2. "Crea collegamento"
3. Sposta sul Desktop
```

### Auto-Start
```
1. Win + R → digita "shell:startup"
2. Copia collegamento a server_ui.exe
```

### Backup Database
```powershell
copy C:\path\to\ingresso_uscita.db C:\Backup\db_backup.db
```

## 🎉 Fatto!

Ora hai Server Manager funzionante su Windows!

Per domande: consulta [WINDOWS_SETUP.md](WINDOWS_SETUP.md)

---

**Tempo totale setup: ~5 minuti** ⚡
