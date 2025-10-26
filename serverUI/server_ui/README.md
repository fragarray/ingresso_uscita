# 🖥️ Sinergy Work - Server Manager UI

Applicazione desktop per gestire uno o più server Node.js di Sinergy Work.

![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.9.2-blue)

## ✨ Funzionalità

- ✅ **Gestione Multi-Server**: Gestisci più istanze del server Sinergy Work
- ✅ **Avvio/Arresto**: Controlla i server con un click
- ✅ **Monitoraggio Real-time**: Visualizza log e stato in tempo reale
- ✅ **System Tray**: Minimizza nel system tray (quando supportato)
- ✅ **Auto-Dependencies**: Installa automaticamente le dipendenze npm
- ✅ **Template Integrato**: Server template incluso come asset
- ✅ **Cross-Platform**: Compatibile con Windows, Linux e macOS

## 🚀 Requisiti

### Prerequisiti
- **Flutter SDK 3.9.2+** 
- **Node.js 16+** (per eseguire i server)
- **npm** (incluso con Node.js)

### Windows
- Windows 10/11
- Node.js deve essere nel PATH di sistema

### Linux
- Ubuntu 20.04+ o equivalente
- GTK 3.0+
- Opzionale: `libappindicator3-dev` (per system tray)

### macOS
- macOS 10.14+
- Xcode Command Line Tools

## Installazione

```bash
# Naviga nella cartella serverUI
cd serverUI/server_ui

# Installa le dipendenze
flutter pub get

# Esegui l'applicazione
flutter run -d linux  # Per Linux
flutter run -d windows  # Per Windows
flutter run -d macos  # Per macOS
```

## Dipendenze

- **window_manager**: Gestione finestre desktop
- **system_tray**: Integrazione system tray
- **provider**: State management
- **shared_preferences**: Persistenza configurazioni

## Struttura Progetto

```
lib/
├── models/
│   └── server_instance.dart    # Modello dati server
├── providers/
│   └── server_provider.dart    # Gestione stato applicazione
├── screens/
│   ├── home_screen.dart        # Schermata principale
│   ├── add_server_screen.dart  # Aggiunta nuovo server
│   └── server_detail_screen.dart # Dettagli e configurazione server
├── widgets/
│   ├── server_card.dart        # Carta server nella griglia
│   └── add_server_card.dart    # Carta "Aggiungi Server"
├── services/
│   └── tray_service.dart       # Gestione system tray
└── main.dart                   # Entry point applicazione

assets/
└── server_template/            # Template server Node.js (integrato)
    ├── server.js
    ├── db.js
    ├── config.js
    ├── package.json
    └── routes/
        └── worksites.js
```

## Utilizzo

### Creazione Nuovo Server

Quando crei un nuovo server, l'applicazione:

1. **Estrae** i file template dagli asset integrati
2. **Crea** una nuova cartella in `%USERPROFILE%\IngressoUscita_Servers\<nome>`
3. **Copia** tutti i file necessari (server.js, db.js, routes, ecc.)
4. **Installa** automaticamente le dipendenze con `npm install`
5. **Avvia** il server sulla porta specificata

**Passaggi**:
1. Clicca sulla carta "Aggiungi Server"
2. Inserisci:
   - Nome descrittivo del server (es: "Produzione", "Test")
   - Porta di rete (viene suggerita una porta libera, es: 3000)
3. Clicca "Crea Server"

**Nota**: Non serve specificare percorsi! I file template sono integrati nell'app.

### Avvio/Arresto Server

- **Avvio**: Clicca il pulsante play (▶) sulla carta del server
- **Arresto**: Clicca il pulsante stop (⏹) sulla carta del server

### Visualizzazione Dettagli

Clicca su una carta server per aprire la schermata di dettaglio con:
- Informazioni complete del server
- Log in tempo reale
- Configurazioni avanzate
- Controlli per backup/ripristino

### Minimizzazione nel Tray

- Premi X per chiudere la finestra (l'app resta attiva nel tray se ci sono server in esecuzione)
- Clicca sull'icona nel tray per riaprire l'applicazione
- Menu tray per controllo rapido dei server

## Configurazione Server Node.js

L'applicazione si aspetta che ogni server abbia:

- Un file `server.js` nella cartella specificata
- Supporto per le variabili d'ambiente:
  - `PORT`: Porta su cui avviare il server
  - `DB_PATH`: Percorso del database (se applicabile)

Esempio di server.js compatibile:

```javascript
const express = require('express');
const app = express();

const port = process.env.PORT || 3000;
const dbPath = process.env.DB_PATH || './database';

app.listen(port, () => {
  console.log(`Server avviato sulla porta ${port}`);
  console.log(`Database path: ${dbPath}`);
});
```
