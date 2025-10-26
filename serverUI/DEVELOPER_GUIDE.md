# Server Manager - Guida Sviluppatore

## Panoramica Architettura

L'applicazione Server Manager è sviluppata in Flutter per desktop (Linux, Windows, macOS) e utilizza il pattern **Provider** per la gestione dello stato.

### Struttura dell'Applicazione

```
lib/
├── main.dart                   # Entry point, configurazione finestra e tray
├── models/
│   └── server_instance.dart   # Modello dati per istanze server
├── providers/
│   └── server_provider.dart   # State management centralizzato
├── screens/
│   ├── home_screen.dart        # Griglia server principale
│   ├── add_server_screen.dart  # Form creazione server
│   └── server_detail_screen.dart # Dettagli, log e configurazione
├── widgets/
│   ├── server_card.dart        # Card server nella griglia
│   └── add_server_card.dart    # Card per aggiungere server
└── services/
    └── tray_service.dart       # Gestione system tray
```

## Componenti Principali

### 1. ServerInstance Model
Rappresenta un'istanza di server Node.js con:
- **Metadati**: ID, nome, porta, percorso
- **Stato**: stopped, starting, running, stopping, error
- **Runtime**: processo attivo, log, timestamp
- **Persistenza**: serializzazione JSON

### 2. ServerProvider 
Gestisce lo stato globale dell'applicazione:
- **CRUD Server**: creazione, modifica, eliminazione
- **Controllo Processi**: avvio/arresto server Node.js
- **Persistenza**: salvataggio automatico in SharedPreferences
- **Monitoraggio**: stato e log in tempo reale

### 3. TrayService
Integrazione system tray per:
- **Background Mode**: app continua a funzionare nascosta
- **Menu Contestuale**: controlli rapidi
- **Notifiche**: aggiornamenti stato server

### 4. Window Manager
Gestione finestra desktop:
- **Configurazione Iniziale**: dimensioni, posizione, titolo
- **Eventi Chiusura**: minimizzazione vs uscita
- **Integrazione Tray**: nascondere/mostrare finestra

## Flusso di Lavoro

### Avvio Server
1. Utente clicca "play" su ServerCard
2. ServerProvider esegue validazioni (porta libera)
3. Crea processo Node.js with environment vars
4. Monitora stdout/stderr per log
5. Aggiorna stato UI in real-time
6. Salva configurazione persistente

### Gestione Log
- Log vengono raccolti da stdout/stderr del processo
- Limitati a 1000 righe per performance
- Visualizzati in tempo reale nella DetailScreen
- Filtrabili e esportabili

### System Tray Integration
- App si minimizza nel tray invece di chiudersi
- Menu mostra stato corrente server
- Possibilità di fermare tutti i server
- Riapertura finestra da tray

## Configurazione Node.js

I server Node.js devono supportare queste variabili d'ambiente:

```javascript
const port = process.env.PORT || 3000;
const dbPath = process.env.DB_PATH || './database';

// Il server deve loggare su stdout per essere catturato
console.log(`Server started on port ${port}`);
```

## Sviluppo e Testing

### Setup Ambiente
```bash
# Naviga nella cartella del progetto
cd serverUI/server_ui

# Installa dipendenze
flutter pub get

# Esegui in modalità debug
flutter run -d linux

# Build per produzione
flutter build linux --release
```

### Testing Server Node.js
Crea un server di test:

```javascript
// test-server.js
const express = require('express');
const app = express();

const port = process.env.PORT || 3000;
const dbPath = process.env.DB_PATH || './database';

app.get('/', (req, res) => {
  res.json({ 
    message: 'Server running',
    port: port,
    dbPath: dbPath,
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`Test server started on port ${port}`);
  console.log(`Database path: ${dbPath}`);
  
  // Log periodici per testare
  setInterval(() => {
    console.log(`Server status: OK - ${new Date().toISOString()}`);
  }, 5000);
});

// Gestione chiusura graceful
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});
```

### Debug e Problemi Comuni

#### 1. System Tray non funziona
- **Linux**: Verifica supporto system tray nel desktop environment
- **Soluzione**: Installa pacchetti aggiuntivi o usa alternative

#### 2. Processo Node.js non si ferma
- **Causa**: Server non gestisce SIGTERM
- **Soluzione**: Implementa gestione segnali nel server.js

#### 3. Log non aggiornati
- **Causa**: Buffer stdout/stderr
- **Soluzione**: Forza flush o usa logging unbuffered

#### 4. Porte in conflitto
- **Causa**: Porta già utilizzata
- **Soluzione**: App controlla automaticamente e suggerisce alternative

## Estensioni e Personalizzazioni

### Aggiungere Nuovo Tipo Server
1. Estendi ServerInstance con nuovo campo `serverType`
2. Modifica provider per gestire comando diverso da `node server.js`
3. Aggiorna UI per selezione tipo server

### Monitoring Avanzato
1. Aggiungi endpoint health check ai server
2. Implementa polling periodico nello stato
3. Mostra metriche CPU/memoria nella UI

### Configurazione Avanzata
1. Crea modello Configuration con settings globali
2. Aggiungi schermata Settings
3. Salva in SharedPreferences separate

### Backup Automatico
1. Implementa servizio backup in background
2. Aggiungi configurazione intervalli
3. Integra con cloud storage (Google Drive, Dropbox)

## Deployment

### Linux AppImage
```bash
flutter build linux --release
# Crea AppImage con linux-appimage tools
```

### Windows Installer
```bash
flutter build windows --release
# Usa NSIS o Inno Setup per installer
```

### macOS App Bundle
```bash
flutter build macos --release
# Firma app per distribuzione Mac App Store
```

## Sicurezza

### Considerazioni
- **Processi Esterni**: Validazione input per prevenire injection
- **File System**: Restrizioni accesso cartelle sensibili
- **Network**: Validazione porte e binding interfaces
- **Logs**: Sanitizzazione output per prevenire log injection

### Best Practices
- Non salvare credenziali in plain text
- Usa canali sicuri per comunicazione inter-processo
- Implementa rate limiting per operazioni intensive
- Audit log per operazioni amministrative

## Performance

### Ottimizzazioni
- **Memory**: Limitazione log a 1000 righe per server
- **CPU**: Debounce per aggiornamenti UI frequenti
- **Disk I/O**: Batch write per SharedPreferences
- **Network**: Connection pooling per health checks

### Monitoring
- Traccia performance avvio server
- Monitora utilizzo memoria dell'app
- Log errori e crash per debugging
- Metriche usage per miglioramenti UX

## Roadmap Futura

### v2.0 Features
- [ ] Clustering e load balancing
- [ ] Docker integration
- [ ] API REST per controllo remoto
- [ ] Configurazione SSL/HTTPS
- [ ] Database integrato per configurazioni

### v3.0 Features  
- [ ] Web interface per controllo remoto
- [ ] Multi-tenancy e gestione team
- [ ] Integrazione CI/CD pipelines
- [ ] Monitoring distribuito
- [ ] Auto-scaling basato su metriche