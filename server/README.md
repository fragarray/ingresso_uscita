# Server Gestione Presenze

Server Node.js/Express per il sistema di gestione timbrature e presenze dipendenti.

## 🚀 Avvio

```bash
npm install
npm start
```

Per sviluppo con auto-reload:
```bash
npm run dev
```

Il server sarà disponibile su `http://localhost:3000`

## 📁 Struttura

```
server/
├── db.js                 # Configurazione database SQLite
├── server.js            # Entry point e routes principali
├── routes/
│   └── worksites.js     # Routes per gestione cantieri
├── reports/             # Excel reports generati
└── database.db          # Database SQLite
```

## 🗄️ Database

Il database SQLite (`database.db`) contiene 3 tabelle:

### employees
- `id` - ID univoco
- `name` - Nome dipendente
- `email` - Email (unique)
- `password` - Password
- `isAdmin` - Flag amministratore (0/1)

### work_sites
- `id` - ID univoco
- `name` - Nome cantiere
- `latitude` - Latitudine
- `longitude` - Longitudine
- `address` - Indirizzo completo
- `isActive` - Cantiere attivo (0/1)
- `createdAt` - Data creazione

### attendance_records
- `id` - ID univoco
- `employeeId` - FK a employees
- `workSiteId` - FK a work_sites
- `timestamp` - Data/ora timbratura
- `type` - Tipo ('in' o 'out')
- `deviceInfo` - Info dispositivo
- `latitude` - Latitudine timbratura
- `longitude` - Longitudine timbratura

## 🔌 API Endpoints

### Autenticazione
- `POST /api/login` - Login dipendente

### Dipendenti
- `GET /api/employees` - Lista dipendenti
- `POST /api/employees` - Crea dipendente
- `PUT /api/employees/:id` - Aggiorna dipendente
- `DELETE /api/employees/:id` - Elimina dipendente (solo non-admin)

### Cantieri
- `GET /api/worksites` - Lista cantieri
- `POST /api/worksites` - Crea cantiere
- `PUT /api/worksites/:id` - Aggiorna cantiere
- `DELETE /api/worksites/:id` - Elimina cantiere (con backup Excel)
- `GET /api/worksites/:id/details` - Dettagli cantiere con conteggio dipendenti

### Presenze
- `POST /api/attendance` - Registra timbratura
- `GET /api/attendance/:employeeId` - Storico dipendente
- `GET /api/attendance/worksite/:workSiteId` - Presenze cantiere

### Report
- `GET /api/reports/attendance` - Genera report Excel filtrato

Query params per filtri:
- `employeeId` - ID dipendente
- `workSiteId` - ID cantiere
- `startDate` - Data inizio (YYYY-MM-DD)
- `endDate` - Data fine (YYYY-MM-DD)

## 📊 Excel Reports

I report Excel sono generati automaticamente in formato italiano con:
- Intestazioni formattate
- Filtri automatici
- Informazioni cantiere
- Dettaglio timbrature (dipendente, data/ora, tipo, cantiere, posizione)

### Backup automatico
Quando si elimina un cantiere, viene creato automaticamente un backup Excel con tutte le presenze associate nella cartella `reports/`.

## 🔒 Sicurezza

- CORS abilitato per tutte le origini
- Validazione input su tutti gli endpoints
- Password visibili (gestione interna admin)
- Gli admin non possono essere eliminati

## 🛠️ Dipendenze

- **express** - Framework web
- **sqlite3** - Database
- **exceljs** - Generazione report Excel
- **cors** - Gestione CORS

## 📝 Note

- Il server crea automaticamente le tabelle al primo avvio
- I report Excel vengono sovrascritti a ogni nuova generazione
- La cartella `reports/` deve esistere per salvare i file Excel
