# 📱 Sinergy Work

Sistema completo di gestione timbrature con geolocalizzazione e gestione cantieri.

![Flutter](https://img.shields.io/badge/Flutter-3.9.2-blue)
![Node.js](https://img.shields.io/badge/Node.js-Express-green)
![SQLite](https://img.shields.io/badge/Database-SQLite-blue)

## ✨ Funzionalità

### 👷 Area Dipendente
- ✅ Timbratura ingresso/uscita con GPS
- ✅ Selezione cantiere di lavoro
- ✅ Verifica automatica distanza dal cantiere (geofencing 100m)
- ✅ Visualizzazione ultime timbrature
- ✅ Indicatore visivo posizione valida/non valida

### 👨‍💼 Area Amministratore
- ✅ **Gestione Personale**: CRUD dipendenti con storico presenze
- ✅ **Presenze Oggi**: Dashboard real-time con statistiche
- ✅ **Gestione Cantieri**: Mappa interattiva per posizionare cantieri
- ✅ **Report Excel**: Esportazione con filtri avanzati in italiano

### 🗺️ Gestione Cantieri
- ✅ Creazione cantieri su mappa interattiva
- ✅ Recupero automatico indirizzo da coordinate
- ✅ Attivazione/disattivazione cantieri
- ✅ Visualizzazione marker colorati per stato

### 📊 Report Avanzati
- ✅ Esportazione Excel formattata in italiano
- ✅ Filtri per dipendente, cantiere, periodo
- ✅ Intestazioni colorate e bordi
- ✅ Filtri automatici sulle colonne
- ✅ Coordinate GPS con 6 decimali di precisione

## 🚀 Quick Start

### Prerequisiti
- Flutter SDK 3.9.2+
- Node.js 16+
- npm o yarn

### 1. Installazione Server
```bash
cd server
npm install
npm start

# Scarica ed esegui lo script in un solo comando
curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server.sh | bash

```
Server disponibile su `http://localhost:3000`

### 2. Installazione App Flutter
```bash
flutter pub get
flutter run
```

### 3. Credenziali Default
- Email: `admin@example.com`
- Password: `admin123`

## 📁 Struttura Progetto

```
ingresso_uscita/
├── lib/
│   ├── main.dart                 # Entry point app
│   ├── models/                   # Modelli dati
│   │   ├── employee.dart
│   │   ├── attendance_record.dart
│   │   └── work_site.dart
│   ├── pages/                    # Schermate principali
│   │   ├── login_page.dart
│   │   ├── employee_page.dart
│   │   └── admin_page.dart
│   ├── services/                 # Servizi backend/API
│   │   ├── api_service.dart
│   │   └── location_service.dart
│   └── widgets/                  # Widget riutilizzabili
│       ├── personnel_tab.dart
│       ├── reports_tab.dart
│       └── work_sites_tab.dart
├── server/
│   ├── server.js                 # Server Express
│   ├── db.js                     # Setup database
│   ├── routes/
│   │   └── worksites.js         # Routes cantieri
│   └── reports/                  # Report Excel generati
└── pubspec.yaml                  # Dipendenze Flutter
```

## 🛠️ Tecnologie Utilizzate

### Frontend (Flutter)
- **provider**: State management
- **http**: API calls
- **location**: GPS e geolocalizzazione
- **flutter_map**: Mappa interattiva
- **excel**: Generazione report
- **intl**: Formattazione date
- **sqflite**: Database locale

### Backend (Node.js)
- **express**: Web framework
- **sqlite3**: Database
- **exceljs**: Generazione Excel
- **cors**: CORS handling

## 📖 Documentazione

- [📋 CHANGELOG.md](CHANGELOG.md) - Tutte le modifiche implementate
- [📘 GUIDA_RAPIDA.md](GUIDA_RAPIDA.md) - Guida utente completa

## 🔐 Sicurezza

- ⚠️ **IMPORTANTE**: Questo è un progetto di esempio. In produzione:
  - Implementare hash password (bcrypt)
  - Aggiungere JWT per autenticazione
  - Usare HTTPS
  - Validare input lato server
  - Implementare rate limiting

## 🗃️ Database Schema

### Tabella `employees`
```sql
CREATE TABLE employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  isAdmin INTEGER DEFAULT 0
);
```

### Tabella `attendance_records`
```sql
CREATE TABLE attendance_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employeeId INTEGER NOT NULL,
  workSiteId INTEGER,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  type TEXT CHECK(type IN ('in', 'out')) NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  deviceInfo TEXT,
  FOREIGN KEY (employeeId) REFERENCES employees (id),
  FOREIGN KEY (workSiteId) REFERENCES work_sites (id)
);
```

### Tabella `work_sites`
```sql
CREATE TABLE work_sites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  address TEXT NOT NULL,
  isActive INTEGER DEFAULT 1,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 🎯 API Endpoints

### Authentication
- `POST /api/login` - Login utente

### Employees
- `GET /api/employees` - Lista dipendenti
- `POST /api/employees` - Crea dipendente
- `DELETE /api/employees/:id` - Elimina dipendente

### Attendance
- `GET /api/attendance` - Lista timbrature
- `POST /api/attendance` - Registra timbratura
- `GET /api/attendance/report` - Download report Excel

### Work Sites
- `GET /api/worksites` - Lista cantieri
- `POST /api/worksites` - Crea cantiere
- `PUT /api/worksites/:id` - Modifica cantiere
- `DELETE /api/worksites/:id` - Elimina cantiere

## 🌍 Geofencing

Il sistema implementa un controllo di prossimità tra dipendente e cantiere:
- **Raggio**: 100 metri (configurabile)
- **Algoritmo**: Formula di Haversine per calcolo distanza
- **Comportamento**: Alert se fuori range, ma timbratura comunque possibile

## 📱 Piattaforme Supportate

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 11.0+
- ✅ Windows (Desktop)
- ✅ Web (Browser moderni)

## 🐛 Troubleshooting

### Server non si avvia
```bash
cd server
rm -rf node_modules
npm install
npm start
```

### App non si connette
Verifica che il server sia attivo e che l'URL sia corretto in `lib/services/api_service.dart`

### GPS non funziona
- Su dispositivi reali: Verifica permessi posizione
- Su Windows/Web: GPS simulato (sempre valido)

## 📄 Licenza

Questo progetto è fornito a scopo educativo.

## 👥 Contributi

Contributi, issues e feature requests sono benvenuti!

## 🙏 Ringraziamenti

- Flutter Team
- OpenStreetMap per le mappe
- ExcelJS per la generazione report

---

**Fatto con ❤️ usando Flutter e Node.js**

