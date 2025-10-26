# 📦 Integrazione Server Template come Asset

**Data**: 26 Ottobre 2025  
**Autore**: Sistema di sviluppo

## 🎯 Approccio Corretto

I file del server Node.js sono ora **integrati come asset** nell'applicazione Flutter, invece di essere cercati come file esterni. Questo garantisce:

✅ **Portabilità**: L'applicazione funziona su qualsiasi sistema senza dipendenze esterne  
✅ **Affidabilità**: I file template sono sempre disponibili  
✅ **Semplicità**: Non servono script di setup o copia manuale  
✅ **Manutenibilità**: I template sono versionati con l'app

---

## 📁 Struttura Asset

```
assets/
└── server_template/
    ├── server.js          # Server principale Node.js/Express
    ├── db.js              # Modulo database SQLite
    ├── config.js          # Configurazione server
    ├── package.json       # Dipendenze npm
    └── routes/
        └── worksites.js   # Route API cantieri
```

---

## 🔧 Come Funziona

### 1. Asset Registrati in `pubspec.yaml`

```yaml
flutter:
  assets:
    - assets/images/
    - assets/server_template/
    - assets/server_template/routes/
```

### 2. Copia Dinamica al Runtime

Quando l'utente crea un nuovo server, l'app:

1. **Legge** i file dagli asset usando `rootBundle.loadString()`
2. **Crea** la cartella del server in `%USERPROFILE%\IngressoUscita_Servers\<nome>`
3. **Scrive** i file letti dagli asset nella nuova cartella
4. **Crea** le sottocartelle necessarie (`routes`, `reports`, `backups`, `temp`)
5. **Esegue** `npm install` per installare le dipendenze

### 3. Codice di Riferimento

```dart
// Leggi asset
final assetContent = await rootBundle.loadString('assets/server_template/server.js');

// Scrivi nel filesystem
final targetFile = File(path.join(serverDir.path, 'server.js'));
await targetFile.writeAsString(assetContent);
```

---

## 🔄 Aggiornamento Asset

Quando il server viene modificato/aggiornato:

### 1. Copia i file aggiornati negli asset

```powershell
# Dalla cartella server_ui
cd "c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\serverUI\server_ui"

# Copia file principali
Copy-Item ..\server\server.js assets\server_template\ -Force
Copy-Item ..\server\db.js assets\server_template\ -Force
Copy-Item ..\server\config.js assets\server_template\ -Force
Copy-Item ..\server\package.json assets\server_template\ -Force

# Copia routes
Get-ChildItem ..\server\routes\*.js | ForEach-Object { 
    Copy-Item $_.FullName assets\server_template\routes\ -Force 
}
```

### 2. Ricompila l'applicazione

```powershell
flutter pub get
flutter build windows --release
```

---

## 📋 File Template Inclusi

| File | Descrizione | Obbligatorio |
|------|-------------|--------------|
| `server.js` | Server Express principale | ✅ Sì |
| `db.js` | Gestione database SQLite | ✅ Sì |
| `config.js` | Configurazione server | ✅ Sì |
| `package.json` | Dipendenze npm | ✅ Sì |
| `routes/worksites.js` | API cantieri | ✅ Sì |

**NON includere**:
- ❌ `database.db` - Creato automaticamente dal server
- ❌ `node_modules/` - Installato da npm
- ❌ `email_config.json` - Configurazione specifica dell'utente
- ❌ File di log o backup

---

## 🛠️ Vantaggi Rispetto all'Approccio Precedente

### ❌ Approccio Vecchio (File Esterni)

```dart
// SBAGLIATO - Cerca file sul filesystem
final sourceFile = File('/path/to/server/server.js');
await sourceFile.copy(targetPath);
```

**Problemi**:
- Percorsi hardcoded non portabili
- Dipendenza da struttura cartelle esterna
- Errori se file mancanti
- Serve script di setup

### ✅ Approccio Nuovo (Asset Integrati)

```dart
// CORRETTO - Legge dagli asset integrati
final content = await rootBundle.loadString('assets/server_template/server.js');
await File(targetPath).writeAsString(content);
```

**Vantaggi**:
- Sempre disponibili
- Nessuna dipendenza esterna
- Funziona ovunque
- Nessun setup necessario

---

## 🧪 Test

### Test Manuale

1. Compila l'app: `flutter build windows --release`
2. Avvia l'eseguibile
3. Clicca "Aggiungi Server"
4. Crea un nuovo server (nome: "Test")
5. Verifica che vengano creati:
   ```
   C:\Users\<user>\IngressoUscita_Servers\Test\
   ├── server.js
   ├── db.js
   ├── config.js
   ├── package.json
   └── routes\
       └── worksites.js
   ```

### Output Atteso

```
📂 Percorso destinazione: C:\Users\...\IngressoUscita_Servers\Test
📦 Copia file template dagli asset integrati...
✓ Copiato: server.js
✓ Copiato: db.js
✓ Copiato: config.js
✓ Copiato: package.json
✓ Copiato: routes/worksites.js
✓ Creata cartella: reports
✓ Creata cartella: temp
✓ Creata cartella: backups
✅ Cartella server creata: C:\Users\...\IngressoUscita_Servers\Test
```

---

## 🔐 Sicurezza

Gli asset sono:
- ✅ **Read-only** - Non possono essere modificati dall'utente
- ✅ **Embedded** - Inclusi nell'eseguibile
- ✅ **Versionati** - Sempre sincronizzati con la versione dell'app

---

## 📚 Riferimenti

- **Codice**: `lib/screens/add_server_screen.dart` → `_createServerDirectory()`
- **Asset**: `assets/server_template/`
- **Configurazione**: `pubspec.yaml` → sezione `flutter.assets`
- **Flutter Docs**: https://docs.flutter.dev/ui/assets/assets-and-images

---

## ✅ Checklist Sviluppatori

Quando aggiungi/modifichi file del server template:

- [ ] Copia il file in `assets/server_template/`
- [ ] Aggiorna `pubspec.yaml` se serve (nuove cartelle)
- [ ] Aggiorna `_createServerDirectory()` se servono nuovi file
- [ ] Esegui `flutter pub get`
- [ ] Testa la creazione di un nuovo server
- [ ] Aggiorna questa documentazione
- [ ] Ricompila e testa il build Release

---

**Nota**: Questo approccio è lo standard corretto per applicazioni Flutter che devono includere file template o risorse statiche.
