# 🖥️ Server Manager UI

Un'applicazione desktop Flutter per la gestione centralizzata di server Node.js con interfaccia grafica moderna e funzionalità di system tray.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)

## ✨ Caratteristiche Principali

- **🎛️ Gestione Multi-Server**: Crea, configura e gestisci multiple istanze di server Node.js
- **📊 Monitoraggio Real-time**: Visualizza stato, log e metriche dei server in tempo reale  
- **🔧 Controlli Intuitivi**: Avvia, ferma e riavvia server con un click
- **📱 System Tray**: L'app continua a funzionare in background nel system tray
- **💾 Configurazione Persistente**: Salvataggio automatico delle configurazioni
- **📋 Gestione Log**: Visualizza, filtra ed esporta i log dei server
- **🔒 Controllo Porte**: Verifica automatica disponibilità porte di rete

## 🖼️ Anteprima Interfaccia

### Schermata Principale
Griglia di carte che mostrano tutti i server configurati con stato visuale immediato:
- 🟢 Server in esecuzione
- ⭕ Server fermato  
- 🟡 Server in transizione (avvio/arresto)
- 🔴 Server in errore

### Dettagli Server
Schermata completa con:
- ℹ️ Informazioni server e statistiche
- 📜 Log in tempo reale con scroll automatico
- ⚙️ Configurazioni avanzate e controlli

## 🚀 Installazione Rapida

### Prerequisiti
- Flutter SDK 3.9+ 
- Dart SDK 3.0+
- Node.js 14+ (per i server gestiti)

### Setup Progetto
```bash
# Clona il repository
git clone <repo-url>
cd ingresso_uscita/serverUI

# Installa dipendenze Flutter
cd server_ui
flutter pub get

# Installa dipendenze server di test
cd ..
npm install

# Esegui l'applicazione
cd server_ui
flutter run -d linux  # o windows/macos
```

## 🎯 Utilizzo Rapido

### 1. Primo Avvio
- L'applicazione si apre con una griglia vuota
- Clicca sulla carta "➕ Aggiungi Server" per creare il primo server

### 2. Configurazione Server
- **Nome**: Descrizione del server (es: "Server Produzione")
- **Porta**: Porta di rete (l'app suggerisce porte libere)
- **Cartella**: Percorso che contiene `server.js`

### 3. Test con Server Esempio
```bash
# Crea cartella di test
mkdir test-server-instance
cd test-server-instance

# Copia il server di esempio
cp ../test-server.js ./server.js
cp ../package.json ./

# Installa dipendenze
npm install

# Ora puoi configurare questa cartella nell'app
```

### 4. Controlli Server
- **▶️ Avvia**: Clicca il pulsante play sulla carta
- **⏹️ Ferma**: Clicca il pulsante stop quando è in esecuzione  
- **👁️ Dettagli**: Clicca sulla carta per aprire la schermata completa

### 5. System Tray
- **Minimizzare**: Clicca X per nascondere nel tray (se ci sono server attivi)
- **Riaprire**: Clicca l'icona nel tray
- **Menu**: Click destro sull'icona per controlli rapidi

## 📁 Struttura Progetto

```
serverUI/
├── 📱 server_ui/              # Applicazione Flutter principale
│   ├── lib/
│   │   ├── models/            # Modelli dati
│   │   ├── providers/         # State management  
│   │   ├── screens/           # Schermate UI
│   │   ├── widgets/           # Componenti riutilizzabili
│   │   ├── services/          # Servizi (tray, etc.)
│   │   └── main.dart          # Entry point
│   ├── assets/                # Risorse (icone, etc.)
│   └── pubspec.yaml           # Dipendenze Flutter
│
├── 🧪 test-server.js          # Server Node.js di esempio
├── 📦 package.json            # Dipendenze server di test
├── 📖 README.md              # Questa guida
└── 📚 DEVELOPER_GUIDE.md     # Guida sviluppatori
```

## 🔧 Configurazione Server Node.js

I server devono supportare le seguenti variabili d'ambiente:

```javascript
// server.js
const express = require('express');
const app = express();

// L'app Server Manager passa queste variabili
const port = process.env.PORT || 3000;
const dbPath = process.env.DB_PATH || './database';

app.listen(port, () => {
  // Log su console per essere catturati dall'app
  console.log(`Server avviato sulla porta ${port}`);
  console.log(`Database path: ${dbPath}`);
});

// Gestione chiusura graceful (importante!)
process.on('SIGTERM', () => {
  console.log('Chiusura server...');
  process.exit(0);
});
```

## 🛠️ Build per Distribuzione

### Linux AppImage
```bash
cd server_ui
flutter build linux --release
# L'eseguibile sarà in build/linux/x64/release/bundle/
```

### Windows Eseguibile
```bash
cd server_ui
flutter build windows --release
# L'eseguibile sarà in build/windows/runner/Release/
```

### macOS App
```bash
cd server_ui
flutter build macos --release
# L'app sarà in build/macos/Build/Products/Release/
```

## 🐛 Troubleshooting

### ❓ Problemi Comuni

#### Server non si avvia
- ✅ Verifica che Node.js sia installato: `node --version`
- ✅ Controlla che `server.js` esista nella cartella specificata
- ✅ Verifica permessi di lettura/scrittura sulla cartella
- ✅ Controlla i log nella schermata dettagli per errori specifici

#### Porta già in uso
- ✅ L'app controlla automaticamente e suggerisce porte alternative
- ✅ Verifica che nessun altro servizio usi la stessa porta
- ✅ Usa `netstat -tlnp | grep :porta` per controllare (Linux)

#### System Tray non visibile
- ✅ **Linux**: Alcuni desktop environment richiedono estensioni aggiuntive
- ✅ **Windows**: Controlla le impostazioni dell'area di notifica  
- ✅ **macOS**: L'icona appare nella barra menu in alto

#### App non si chiude
- ✅ Se ci sono server attivi, l'app si minimizza nel tray invece di chiudersi
- ✅ Ferma tutti i server prima di uscire, o usa "Esci" dal menu tray

## 🎨 Personalizzazione

### Temi e Colori
Modifica `lib/main.dart` per personalizzare il tema:

```dart
theme: ThemeData(
  primaryColor: const Color(0xFF1976D2), // Cambia colore principale
  // ... altre personalizzazioni
),
```

### Icone System Tray
Sostituisci `assets/images/tray_icon.png` con la tua icona personalizzata.

## 🤝 Contributi

Contributi benvenuti! Per maggiori informazioni consulta [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md).

### Processo Contributi
1. 🍴 Fork del repository
2. 🌿 Crea un branch per la tua feature
3. ✅ Aggiungi/aggiorna test se necessario  
4. 📝 Commit delle modifiche con messaggi descrittivi
5. 📤 Push e crea una Pull Request

## 📄 Licenza

Questo progetto è rilasciato sotto licenza MIT. Vedi file `LICENSE` per i dettagli.

## 🚧 Roadmap

### v1.1 (Prossima Release)
- [ ] 🔍 Ricerca e filtri server
- [ ] 📊 Grafici utilizzo risorse  
- [ ] 🔔 Notifiche desktop per eventi
- [ ] 💾 Backup/ripristino configurazioni

### v2.0 (Futuro)
- [ ] 🐳 Supporto Docker containers
- [ ] 🌐 API REST per controllo remoto
- [ ] 👥 Gestione multi-utente
- [ ] ☁️ Sync cloud configurazioni

## 📞 Supporto

- 🐛 **Bug Report**: Apri un issue su GitHub
- 💡 **Feature Request**: Apri un issue con label "enhancement" 
- 📚 **Documentazione**: Consulta la [Developer Guide](DEVELOPER_GUIDE.md)
- 💬 **Domande**: Usa le Discussions su GitHub

---

**Realizzato con ❤️ usando Flutter e Dart**