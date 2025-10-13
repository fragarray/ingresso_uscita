# Changelog - Sistema Timbratura

## Modifiche Implementate - 13 Ottobre 2025

### 🎯 Funzionalità Principali Implementate

#### 1. **Gestione Cantieri con Geofencing**
- ✅ Aggiunto campo `workSiteId` al modello `AttendanceRecord`
- ✅ Implementata selezione cantiere nella pagina dipendente
- ✅ Calcolo automatico della distanza tra dipendente e cantiere
- ✅ Verifica geofencing con raggio di 100 metri
- ✅ Suggerimento automatico del cantiere più vicino
- ✅ Alert quando il dipendente è fuori dal raggio consentito

#### 2. **Report Excel Migliorati**
- ✅ Report completamente in italiano
- ✅ Intestazioni formattate con colori e bordi
- ✅ Colonne ottimizzate con informazioni cantiere
- ✅ Supporto filtri per:
  - Dipendente specifico
  - Cantiere specifico
  - Intervallo di date (data inizio - data fine)
- ✅ Tipo timbratura (Ingresso/Uscita) in italiano e colorato
- ✅ Filtri automatici sulle colonne
- ✅ Coordinate geografiche con 6 decimali

#### 3. **Area Admin - 4 Tab**
- ✅ **Tab Personale**: Gestione dipendenti completa con storico presenze individuali
- ✅ **Tab Presenze Oggi**: Dashboard con statistiche giornaliere
- ✅ **Tab Cantieri**: Mappa interattiva per gestire i cantieri
- ✅ **Tab Report**: Generazione report Excel con filtri avanzati

#### 4. **Miglioramenti Server**
- ✅ Corretto route duplicato `/api/attendance`
- ✅ Aggiunto supporto per `workSiteId` nelle timbrature
- ✅ Implementati filtri per generazione report
- ✅ Migliorata query con LEFT JOIN per cantieri
- ✅ Gestione corretta delle date nei filtri

#### 5. **Miglioramenti UI/UX**
- ✅ Navigazione automatica dopo login (no route named)
- ✅ Card informativo nella pagina dipendente con stato timbratura
- ✅ Indicatore visivo distanza dal cantiere
- ✅ Icona check/warning per validità posizione
- ✅ Storico timbrature con nome cantiere
- ✅ Dashboard presenze oggi con contatori statistici

### 🔧 Correzioni Tecniche

#### Server (Node.js)
- Rimosso endpoint duplicato POST `/api/attendance`
- Aggiornata query SQL per includere `workSiteId` e JOIN con `work_sites`
- Implementato sistema di filtri nel report Excel
- Formattazione avanzata Excel con ExcelJS

#### Flutter/Dart
- Aggiunto `workSiteId` nullable al modello `AttendanceRecord`
- Implementato `LocationService` con:
  - Calcolo distanza Haversine
  - Verifica geofencing
  - Ricerca cantiere più vicino
  - Descrizione distanza formattata
- Corretto sistema navigazione senza route named
- Integrazione completa delle tab Personnel e Reports

### 📋 Struttura Database

```sql
CREATE TABLE attendance_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employeeId INTEGER NOT NULL,
  workSiteId INTEGER,  -- ✨ NUOVO CAMPO
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  type TEXT CHECK(type IN ('in', 'out')) NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  deviceInfo TEXT,
  FOREIGN KEY (employeeId) REFERENCES employees (id),
  FOREIGN KEY (workSiteId) REFERENCES work_sites (id)
);
```

### 🚀 Come Usare le Nuove Funzionalità

#### Per i Dipendenti:
1. Aprire l'app e effettuare il login
2. Selezionare il cantiere dal dropdown
3. Verificare l'indicatore di distanza (✅ verde se nel raggio, ⚠️ arancione altrimenti)
4. Premere "TIMBRA INGRESSO" o "TIMBRA USCITA"
5. Visualizzare lo storico con cantieri associati

#### Per gli Admin:
1. **Tab Personale**: Gestire dipendenti e vedere lo storico individuale
2. **Tab Presenze Oggi**: Monitorare le timbrature in tempo reale
3. **Tab Cantieri**: Aggiungere/modificare cantieri sulla mappa
4. **Tab Report**: Generare report Excel filtrati per dipendente, cantiere o periodo

### ⚙️ Configurazioni

- **Raggio Geofencing**: 100 metri (configurabile in `LocationService.maxDistanceMeters`)
- **Formato Date Report**: italiano `dd/MM/yyyy HH:mm:ss`
- **Piattaforme Mock**: Windows e Web considerano sempre valida la posizione GPS

### 📝 Note Tecniche

- Il sistema usa la formula di Haversine per calcoli precisi di distanza
- Su Windows/Web il geofencing è disabilitato per testing
- I report Excel sono salvati in `server/reports/` con timestamp
- Le coordinate hanno precisione di 6 decimali (~11cm)

### 🐛 Bug Risolti

1. Route duplicato in server.js causava conflitti
2. Navigazione con route named non definite
3. Campo `workSiteId` mancante nel modello
4. Report Excel non includeva informazioni cantieri
5. Mancanza verifica posizione GPS per cantieri
6. Tab Personnel e Reports non integrate nell'app

### 🔄 Breaking Changes

⚠️ **IMPORTANTE**: È necessario riavviare il server dopo le modifiche al database!

```bash
cd server
npm start
```

Il server ricreerà automaticamente le tabelle con il nuovo schema.
