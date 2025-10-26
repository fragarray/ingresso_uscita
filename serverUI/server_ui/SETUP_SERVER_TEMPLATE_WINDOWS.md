# 🔧 Setup Server Template per Windows

## 🎯 Problema

Quando crei un nuovo server, l'applicazione mostra l'errore:
```
npm error code ENOENT
npm error syscall open
npm error path C:\Users\...\IngressoUscita_Servers\...\package.json
npm error errno -4058
npm error enoent Could not read package.json
```

Questo significa che i file template del server (server.js, package.json, ecc.) non sono stati copiati correttamente.

---

## ✅ Soluzione 1: Copia Manuale (Temporanea)

Se stai usando la versione compilata **senza ricompilare**, copia manualmente la cartella `server`:

### Passo 1: Individua l'eseguibile
```
build\windows\x64\runner\Release\server_ui.exe
```

### Passo 2: Copia la cartella server
```powershell
# Dalla cartella del progetto
Copy-Item -Path "..\server" -Destination "build\windows\x64\runner\Release\server" -Recurse
```

Oppure manualmente:
1. Vai in: `c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\serverUI\server`
2. Copia l'intera cartella `server`
3. Incollala in: `c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui\build\windows\x64\runner\Release\`

La struttura finale sarà:
```
build\windows\x64\runner\Release\
├── server_ui.exe
├── server\
│   ├── server.js
│   ├── package.json
│   ├── db.js
│   ├── config.js
│   └── routes\
│       └── ...
└── ... (altri file)
```

---

## ✅ Soluzione 2: Ricompila con Fix (Permanente)

Ho già modificato il codice per gestire automaticamente il percorso su Windows.

### Ricompila l'applicazione:

```powershell
cd "c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui"
flutter build windows --release
```

Dopo la ricompilazione, il percorso verrà rilevato automaticamente:
- **In Debug**: cerca in `..\..\server` (relativo al progetto)
- **In Release**: cerca nella cartella `server` accanto all'eseguibile

---

## 📋 Verifica

Dopo aver applicato una delle soluzioni:

1. **Avvia l'applicazione**
2. **Clicca "Aggiungi Server"**
3. **Inserisci**:
   - Nome: "Test Server"
   - Porta: 3001
4. **Clicca "Crea Server"**

### Output atteso (nei log):
```
📂 Percorso sorgente server template: C:\...\server
📂 Percorso destinazione: C:\Users\...\IngressoUscita_Servers\Test Server
✓ Copiato: server.js
✓ Copiato: db.js
✓ Copiato: config.js
✓ Copiato: package.json
✓ Copiato: routes/...
✅ Cartella server creata
```

### Se vedi l'errore:
```
Directory template server non trovata: ...
Assicurati che la cartella "server" sia presente insieme all'applicazione.
```
→ Applica la **Soluzione 1**

---

## 🚀 Distribuzione

Quando distribuisci l'applicazione ad altri utenti, includi la cartella `server`:

```
SinergyWork_ServerManager\
├── server_ui.exe
├── server\          ← Importante!
│   ├── server.js
│   ├── package.json
│   └── ...
└── data\
    └── ...
```

---

## 🆘 Troubleshooting

### Problema: "npm error ENOENT"
- **Causa**: File template non trovati
- **Soluzione**: Applica Soluzione 1 o 2

### Problema: "Directory template server non trovata"
- **Causa**: Cartella `server` non presente
- **Soluzione**: Copia manualmente la cartella `server`

### Problema: Server non si avvia dopo la creazione
- **Causa**: Node.js non installato o non nel PATH
- **Soluzione**: Installa Node.js da https://nodejs.org/

---

## 📝 Note Tecniche

Il codice modificato cerca la cartella `server` in questo ordine:

1. **Debug Mode**: `<progetto>\serverUI\server`
2. **Release Mode**: `<exe_directory>\server`
3. **Fallback**: Percorsi comuni per Linux/macOS

Vedi il codice in `lib\screens\add_server_screen.dart` → getter `_integratedServerPath`
