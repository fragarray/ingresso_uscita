# Server Manager UI

Applicazione desktop Flutter per la gestione centralizzata di server Node.js.

## Funzionalità

- **Gestione Multipla Server**: Crea e gestisci multiple istanze di server Node.js
- **Interfaccia Grafica**: Griglia di carte per visualizzare lo stato di ogni server
- **Controlli Server**: Avvia, ferma e riavvia i server con un click
- **Monitoraggio Real-time**: Visualizza log e stato dei server in tempo reale
- **System Tray**: Minimizza l'applicazione nel system tray per continuare a monitorare i server
- **Configurazione Persistente**: Salva automaticamente le configurazioni dei server

## Caratteristiche dell'Interfaccia

### Schermata Principale
- Griglia di carte che mostrano tutti i server configurati
- Carta "Aggiungi Server" per creare nuovi server
- Indicatore dello stato di ogni server (fermato, in esecuzione, errore, ecc.)
- Controlli rapidi per avviare/fermare i server

### Gestione Server
- Configurazione porta di rete
- Selezione cartella di lavoro del server
- Visualizzazione log in tempo reale
- Backup e ripristino database (funzionalità future)

### System Tray
- L'applicazione continua a funzionare in background
- Menu contestuale per accesso rapido alle funzioni
- Notifiche sullo stato dei server
- Possibilità di fermare tutti i server prima della chiusura

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
```

## Utilizzo

### Creazione Nuovo Server

1. Clicca sulla carta "Aggiungi Server" nella schermata principale
2. Inserisci:
   - Nome descrittivo del server
   - Porta di rete (viene suggerita una porta libera)
   - Percorso alla cartella contenente server.js
3. Clicca "Crea Server"

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
