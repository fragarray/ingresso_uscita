# Changelog - Sistema Autenticazione Username e Ruoli

**Data**: 2025-01-XX  
**Versione**: 2.0.0

## 🔴 Breaking Changes

### Autenticazione con Username
Il sistema di login è stato completamente modificato:

- **PRIMA**: Login tramite email + password
- **ADESSO**: Login tramite username + password

⚠️ **IMPORTANTE**: Gli utenti esistenti dovranno utilizzare il loro nuovo username generato automaticamente dalla migrazione.

### Campo Email Opzionale
- L'email non è più obbligatoria per tutti i dipendenti
- L'email è **obbligatoria SOLO per gli amministratori** (necessaria per l'invio dei report)
- L'email può essere lasciata vuota per dipendenti e capicantiere

### Nuovo Sistema di Ruoli
Sono stati introdotti tre ruoli distinti:

1. **Amministratore** (`admin`)
   - Accesso completo a tutte le funzionalità
   - Gestione dipendenti, cantieri, timbrature
   - Visualizzazione e download di tutti i report
   - Email obbligatoria

2. **Dipendente** (`employee`)
   - Timbratura IN/OUT sui cantieri
   - Visualizzazione delle proprie timbrature
   - Nessun accesso ai dati di altri dipendenti
   - Email opzionale

3. **Capocantiere** (`foreman`)
   - Visualizzazione cantieri attivi
   - Monitoraggio dipendenti attualmente timbrati IN per cantiere
   - Download report storico timbrature per cantiere
   - Email opzionale

---

## 🗄️ Modifiche Database

### Nuove Colonne

```sql
-- Colonna username (obbligatoria, unica)
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;

-- Colonna role (admin/employee/foreman)
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';
```

### Modifiche Vincoli

- **Rimosso** vincolo `UNIQUE` su colonna `email`
- **Aggiunto** vincolo `UNIQUE` su colonna `username`
- Email può ora contenere valori `NULL`

---

## 🔧 Migrazione Database

### Script di Migrazione

È stato creato uno script automatico per migrare i database esistenti:

```bash
node server/migrate_username_auth.js
```

### Cosa Fa lo Script

1. **Backup Automatico**: Crea una copia di sicurezza del database prima di qualsiasi modifica
2. **Generazione Username**: Estrae la parte prima della `@` dall'email e la sanitizza
3. **Gestione Duplicati**: Aggiunge suffissi numerici in caso di username duplicati (user1, user2, etc.)
4. **Assegnazione Ruoli**: Converte il campo booleano `isAdmin` nel nuovo campo `role`
5. **Ricostruzione Tabella**: Ricrea la tabella senza il vincolo UNIQUE sull'email
6. **Validazione**: Verifica l'integrità dei dati dopo la migrazione
7. **Rollback Automatico**: In caso di errore, ripristina il database originale

### Output dello Script

```
=== MIGRAZIONE AUTENTICAZIONE USERNAME ===

✓ Backup creato: employees.db.backup.2025-01-15_14-30-00
✓ 45 username generati
✓ 0 duplicati gestiti
✓ Colonna role aggiunta (3 admin, 2 foreman, 40 employee)
✓ Tabella ricostruita senza UNIQUE su email
✓ Migrazione completata con successo!

Username generati:
- mario.rossi@example.com → mario.rossi
- g.bianchi@company.it → g.bianchi
- admin@site.com → admin
```

### Rollback Manuale

Se necessario, è possibile ripristinare manualmente il backup:

```bash
# Windows PowerShell
Copy-Item "server\employees.db.backup.YYYY-MM-DD_HH-MM-SS" "server\employees.db" -Force

# Linux/Mac
cp server/employees.db.backup.YYYY-MM-DD_HH-MM-SS server/employees.db
```

---

## 🌐 Nuovi Endpoint API

### Autenticazione

**POST /api/login**
```json
// RICHIESTA
{
  "username": "mario.rossi",  // Cambiato da "email"
  "password": "password123"
}

// RISPOSTA
{
  "id": 1,
  "name": "Mario Rossi",
  "username": "mario.rossi",
  "email": "mario.rossi@example.com",  // Può essere null
  "role": "admin",  // admin | employee | foreman
  "isAdmin": true,  // Mantenuto per backward compatibility
  "isAuthorizedForNightShift": true,
  "isActive": true
}
```

⚠️ **Fallback Temporaneo**: Il server continua ad accettare il campo `email` per compatibilità durante la transizione, ma è deprecato.

### Gestione Dipendenti

**POST /api/employees**
```json
{
  "name": "Mario Rossi",
  "username": "mario.rossi",           // OBBLIGATORIO, UNICO
  "email": "mario@example.com",        // OBBLIGATORIO SOLO SE role=admin
  "password": "password123",
  "role": "employee",                  // admin | employee | foreman
  "isAuthorizedForNightShift": false,
  "isActive": true
}
```

**PUT /api/employees/:id**
```json
{
  "name": "Mario Rossi",
  "username": "mario.rossi",           // Modificabile (con controllo unicità)
  "email": "mario@example.com",        // Opzionale (obbligatorio se admin)
  "password": "newpassword123",        // Opzionale (solo se si vuole cambiare)
  "role": "foreman",                   // Modificabile
  "isAuthorizedForNightShift": true,
  "isActive": true
}
```

### Endpoint Capocantiere (NUOVI)

**GET /api/foreman/active-employees/:workSiteId**

Restituisce la lista dei dipendenti attualmente timbrati IN sul cantiere specificato.

```json
// RISPOSTA
[
  {
    "id": 1,
    "name": "Mario Rossi",
    "username": "mario.rossi",
    "clockInTime": "2025-01-15T08:00:00.000Z"
  },
  {
    "id": 2,
    "name": "Luigi Bianchi",
    "username": "luigi.bianchi",
    "clockInTime": "2025-01-15T08:15:00.000Z"
  }
]
```

**GET /api/foreman/worksite-history/:workSiteId**

Query params opzionali:
- `startDate` (ISO 8601): Data inizio periodo
- `endDate` (ISO 8601): Data fine periodo

```json
// RISPOSTA
{
  "workSite": {
    "id": 1,
    "name": "Cantiere Via Roma",
    "address": "Via Roma 123"
  },
  "records": [
    {
      "employeeName": "Mario Rossi",
      "username": "mario.rossi",
      "date": "2025-01-15",
      "clockIn": "08:00",
      "clockOut": "17:00",
      "totalHours": "9.00",
      "isNightShift": false,
      "state": "complete"
    }
  ]
}
```

**GET /api/foreman/worksite-report/:workSiteId**

Query params opzionali:
- `startDate` (ISO 8601): Data inizio periodo
- `endDate` (ISO 8601): Data fine periodo

Genera e restituisce un file Excel (.xlsx) con il report dettagliato delle timbrature del cantiere.

---

## 📱 Modifiche Flutter

### Pagina di Login

- Campo **Email** rinominato in **Username**
- Validazione cambiata: non più controllo formato email
- Tipo tastiera cambiato da `emailAddress` a `text`
- SharedPreferences aggiornate: `saved_email` → `saved_username`

### Dialog Gestione Dipendenti

**Add Employee Dialog**:
- Nuovo campo **Username** (obbligatorio, caratteri alfanumerici e underscore)
- Nuovo campo **Ruolo** (dropdown: Dipendente / Capocantiere / Amministratore)
- Campo **Email** con validazione condizionale:
  - ✅ Obbligatorio per Amministratori
  - ⚪ Opzionale per Dipendenti e Capicantiere
- Testo di aiuto dinamico sotto il campo email

**Edit Employee Dialog**:
- Campo **Username** visibile ma non modificabile (read-only)
- Campo **Ruolo** modificabile con dropdown
- Validazione email si adatta al ruolo selezionato

### Nuova Pagina: ForemanPage

Pagina dedicata ai capicantiere con:
- **Lista Cantieri**: Visualizzazione di tutti i cantieri attivi
- **Dettaglio Cantiere**: Click su un cantiere mostra:
  - Dipendenti attualmente timbrati IN
  - Orario di timbratura IN di ciascuno
  - Badge con contatore dipendenti attivi
- **Date Picker**: Selezione periodo per report storico
- **Download Excel**: Bottone per scaricare il report del cantiere

### Routing Basato su Ruolo

Il routing è ora determinato dal campo `role` del dipendente:

```dart
switch (employee.role) {
  case EmployeeRole.admin:
    return AdminPage();
  case EmployeeRole.foreman:
    return ForemanPage();
  case EmployeeRole.employee:
    return EmployeePage();
}
```

---

## 🚀 Procedura di Deployment

### ⚠️ IMPORTANTE: Seguire Rigorosamente l'Ordine

#### 1. Backup Completo

```bash
# Backup database
cp server/employees.db server/employees.db.backup.manual

# Backup configurazioni
cp server/config.js server/config.js.backup
cp server/email_config.json server/email_config.json.backup
```

#### 2. Fermare il Server

```bash
# Se gestito con systemd
sudo systemctl stop ingresso-uscita

# Oppure
pkill -f "node server.js"
```

#### 3. Aggiornare il Codice Server

```bash
cd server
git pull origin main  # O il tuo branch
npm install  # Assicurarsi che tutte le dipendenze siano aggiornate
```

#### 4. Eseguire la Migrazione Database

```bash
node migrate_username_auth.js
```

⚠️ **Verificare l'output**: Lo script deve completarsi senza errori. In caso di errore, **NON procedere** e ripristinare il backup.

#### 5. Verificare il Database Migrato

```bash
# Installare sqlite3 se non presente
# sudo apt install sqlite3  # Linux
# brew install sqlite3      # Mac

sqlite3 employees.db "SELECT id, name, username, role, email FROM employees LIMIT 5;"
```

Verificare che:
- Tutti i dipendenti abbiano un `username` valorizzato
- Tutti i dipendenti abbiano un `role` (admin/employee/foreman)
- Gli amministratori abbiano ancora l'email valorizzata

#### 6. Avviare il Server

```bash
# Con systemd
sudo systemctl start ingresso-uscita
sudo systemctl status ingresso-uscita

# Manualmente
node server.js
```

#### 7. Testare le API

```bash
# Test login con username
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'

# Test lista dipendenti
curl http://localhost:3000/api/employees
```

#### 8. Compilare e Distribuire App Flutter

```bash
# Android
flutter build apk --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

#### 9. Comunicare agli Utenti

Inviare una comunicazione a tutti gli utenti con:
- Il nuovo username da utilizzare per il login
- Istruzioni su come effettuare il primo accesso
- Eventuali modifiche ai ruoli assegnati

**Template Email**:
```
Oggetto: Aggiornamento Sistema Timbrature - Nuove Credenziali

Gentile [Nome],

Il sistema di timbrature è stato aggiornato con nuove funzionalità.

I tuoi nuovi dati di accesso sono:
- Username: [username_generato]
- Password: [invariata]

Da questo momento, per accedere dovrai utilizzare il tuo username 
invece dell'indirizzo email.

Ruolo assegnato: [Dipendente/Capocantiere/Amministratore]

Per qualsiasi problema, contattare l'amministratore.

Cordiali saluti
```

---

## 🧪 Test Checklist

### Test Migrazione Database

- [ ] Script crea backup automatico
- [ ] Tutti i dipendenti hanno un username unico
- [ ] Username generati sono corretti (sanitizzati, senza caratteri speciali)
- [ ] Duplicati gestiti con suffissi numerici
- [ ] Ruoli assegnati correttamente:
  - Admin hanno `role='admin'`
  - Altri dipendenti hanno `role='employee'`
  - Capicantiere hanno `role='foreman'` (se già presenti)
- [ ] Email degli admin sono conservate
- [ ] Vincolo UNIQUE rimosso da email
- [ ] Vincolo UNIQUE applicato a username

### Test Autenticazione

- [ ] Login con username funziona
- [ ] Login con email funziona (fallback temporaneo)
- [ ] Password errata respinta
- [ ] Account disattivati (`isActive=false`) respinti
- [ ] Risposta contiene tutti i campi (incluso `role`)

### Test Gestione Dipendenti

- [ ] Creazione dipendente con username
- [ ] Username duplicato viene respinto (errore 400)
- [ ] Creazione admin senza email viene respinta
- [ ] Creazione dipendente senza email è permessa
- [ ] Modifica username con controllo unicità
- [ ] Modifica ruolo funziona
- [ ] Cambio password opzionale funziona

### Test Routing

- [ ] Admin vede AdminPage dopo login
- [ ] Dipendente vede EmployeePage dopo login
- [ ] Capocantiere vede ForemanPage dopo login

### Test ForemanPage

- [ ] Lista cantieri carica correttamente
- [ ] Click su cantiere mostra dettagli
- [ ] Dipendenti attualmente IN sono visibili
- [ ] Orari di timbratura IN corretti
- [ ] Badge contatore dipendenti corretto
- [ ] Date picker funziona
- [ ] Download Excel genera file corretto
- [ ] File Excel contiene dati corretti
- [ ] File Excel si apre senza errori

### Test Ricerca Dipendenti

- [ ] Ricerca per nome funziona
- [ ] Ricerca per username funziona
- [ ] Ricerca per email funziona (se presente)
- [ ] Ricerca gestisce email null senza errori

---

## 📊 Statistiche Modifiche

### File Modificati
- **Server**: 4 file (db.js, server.js, migrate_username_auth.js, README.md)
- **Flutter**: 8 file (main.dart, employee.dart, api_service.dart, login_page.dart, add_employee_dialog.dart, edit_employee_dialog.dart, foreman_page.dart, admin_page.dart, personnel_tab.dart, reports_tab.dart)

### Righe di Codice
- **Aggiunte**: ~800 righe
- **Modificate**: ~150 righe
- **Rimosse**: ~50 righe

### Nuovi Endpoint API
- 3 endpoint dedicati ai capicantiere

### Nuove Funzionalità
- Sistema di ruoli a 3 livelli
- Autenticazione basata su username
- Pagina report capocantiere
- Gestione email opzionale

---

## 🔮 Considerazioni Future

### Prossimi Miglioramenti Possibili

1. **Reset Password**: Implementare funzionalità di recupero password tramite email (per chi ha l'email configurata)
2. **Multi-foreman**: Permettere l'assegnazione di capicantiere a cantieri specifici
3. **Notifiche Push**: Avvisare i capicantiere quando i dipendenti timbrano IN/OUT
4. **Permessi Granulari**: Aggiungere permessi specifici oltre ai ruoli base
5. **Log Audit**: Tracciare tutte le modifiche ai dipendenti e ai ruoli

### Manutenzione

- Rimuovere il fallback login via email dopo 1-2 mesi dalla migrazione
- Monitorare l'uso della pagina capocantiere per possibili miglioramenti
- Raccogliere feedback dagli utenti sui nuovi flussi

---

## 📞 Supporto

Per problemi o domande relative a questa migrazione:

1. Verificare i log del server: `journalctl -u ingresso-uscita -f`
2. Controllare il file di backup del database
3. Consultare questo documento
4. Contattare lo sviluppatore

---

**Fine Documento** - Versione 1.0 - 2025-01-XX
