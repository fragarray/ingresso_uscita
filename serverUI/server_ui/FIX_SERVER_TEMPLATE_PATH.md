# 🆕 Fix: Percorso Server Template su Windows

**Data**: 26 Ottobre 2025  
**Problema Risolto**: `npm error ENOENT - package.json not found`

## 🔧 Modifiche Applicate

### File Modificati

**`lib/screens/add_server_screen.dart`**:
- ✅ Sostituito percorso hardcoded Linux (`/home/tom/...`) con getter dinamico
- ✅ Aggiunto supporto multi-piattaforma (Windows/Linux/macOS)
- ✅ Aggiunto rilevamento automatico in Debug/Release mode
- ✅ Aggiunto messaggio di errore dettagliato se cartella template mancante

### Logica del Percorso

Il getter `_integratedServerPath` cerca la cartella `server` in questo ordine:

1. **Windows Debug**: `<progetto>\serverUI\server`
2. **Windows Release**: `<exe_directory>\server`
3. **Linux/macOS**: `$HOME/ingrARM/ingresso_uscita/serverUI/server`
4. **Fallback**: Percorso originale hardcoded

## 📦 File Creati

1. **`SETUP_SERVER_TEMPLATE_WINDOWS.md`**: Guida completa al problema e soluzioni
2. **`setup-server-template.ps1`**: Script PowerShell per copia automatica
3. **`FIX_SERVER_TEMPLATE_PATH.md`**: Questo file (riepilogo)

## 🚀 Come Usare

### Opzione 1: Script Automatico (Raccomandato)

```powershell
cd "c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui"
.\setup-server-template.ps1
```

Lo script:
- ✅ Verifica che la cartella sorgente esista
- ✅ Compila l'app se necessario
- ✅ Copia la cartella `server` in `build\...\Release\server`
- ✅ Verifica che tutti i file essenziali siano presenti

### Opzione 2: Copia Manuale

```powershell
# Dalla cartella server_ui
Copy-Item -Path "..\server" -Destination "build\windows\x64\runner\Release\server" -Recurse
```

### Opzione 3: Ricompila (Fix Permanente)

Il codice è già modificato, quindi ricompilando l'app il fix sarà permanente:

```powershell
flutter build windows --release
# Poi esegui setup-server-template.ps1 per copiare la cartella server
```

## 🔍 Verifica

Dopo aver applicato il fix, quando crei un nuovo server dovresti vedere:

```
📂 Percorso sorgente server template: C:\...\serverUI\server
📂 Percorso destinazione: C:\Users\...\IngressoUscita_Servers\NomeServer
✓ Copiato: server.js
✓ Copiato: db.js
✓ Copiato: config.js
✓ Copiato: package.json
✓ Copiato: package-lock.json
✓ Copiato: routes/...
✅ Cartella server creata
```

## 📚 Documentazione Correlata

- **Setup Windows**: `WINDOWS_SETUP.md`
- **Setup Template**: `SETUP_SERVER_TEMPLATE_WINDOWS.md`
- **Quick Start**: `QUICKSTART_WINDOWS.md`

## 🐛 Se il Problema Persiste

1. Verifica che la cartella `server` sia presente in `serverUI\server`
2. Controlla i permessi della cartella Release
3. Esegui l'app come Amministratore
4. Consulta `SETUP_SERVER_TEMPLATE_WINDOWS.md` per troubleshooting dettagliato

---

**Nota**: Il fix è retrocompatibile. Le installazioni esistenti continueranno a funzionare con la cartella `server` nella posizione corretta.
