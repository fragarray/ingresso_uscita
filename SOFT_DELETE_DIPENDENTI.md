# Soft Delete Dipendenti e Ricerca Avanzata Report

## 📋 Panoramica
Implementato sistema di **soft delete** per i dipendenti invece di eliminazione fisica, permettendo di conservare lo storico completo e accedere ai dati dei dipendenti eliminati.

## 🗄️ Modifiche Database

### Nuove colonne in `employees`:
- `isActive` (INTEGER DEFAULT 1) - Indica se il dipendente è attivo
- `deletedAt` (DATETIME) - Timestamp di quando è stato eliminato

### Comportamento:
- **Prima**: `DELETE FROM employees WHERE id = ?` (eliminazione fisica)
- **Dopo**: `UPDATE employees SET isActive = 0, deletedAt = ? WHERE id = ?` (soft delete)

## 🔧 Modifiche Backend (server.js)

### GET /api/employees
```javascript
// Query parametro: ?includeInactive=true
- Solo attivi (default): WHERE isActive = 1
- Tutti (con inattivi): ORDER BY isActive DESC, name ASC
```

### DELETE /api/employees/:id
```javascript
// Soft delete invece di eliminazione fisica
UPDATE employees SET isActive = 0, deletedAt = ? WHERE id = ?
```

## 💻 Modifiche Frontend

### 1. Modello Employee (`lib/models/employee.dart`)
Aggiunti campi:
```dart
final bool isActive;
final DateTime? deletedAt;
```

### 2. ApiService (`lib/services/api_service.dart`)
```dart
Future<List<Employee>> getEmployees({bool includeInactive = false})
```

### 3. Tab Report (`lib/widgets/reports_tab.dart`)

#### Campo di ricerca dipendenti:
- **TextField** con ricerca in tempo reale (nome/email)
- **FilterChip "Inattivi"** per includere/escludere dipendenti eliminati
- **Lista dinamica** che mostra risultati filtrati
- **Indicatori visivi**:
  - 🟢 Icon verde per dipendenti attivi
  - 🔴 Icon rosso per dipendenti inattivi
  - Testo barrato per dipendenti eliminati
  - Badge "(Eliminato)" nei dipendenti inattivi

#### Funzionalità:
1. **Ricerca live**: Filtra mentre digiti
2. **Toggle inattivi**: Mostra/nascondi dipendenti eliminati
3. **Selezione**: Click su dipendente per selezionarlo
4. **Clear**: Pulsante X per cancellare ricerca
5. **Chip selezionato**: Mostra dipendente selezionato con possibilità di rimuoverlo

## 🎯 Flusso Utente

### Eliminazione Dipendente:
1. Admin clicca elimina
2. Controlli sicurezza (non può eliminare se stesso / unico admin)
3. Prima conferma
4. **Download automatico report** dipendente
5. Conferma download
6. Conferma finale
7. **Soft delete**: `isActive = 0`, `deletedAt = now()`
8. Dipendente non appare più nella lista personale
9. **Storico conservato**: Tutte le timbrature restano nel database

### Generazione Report:
1. Tab Report → Campo ricerca dipendenti
2. (Opzionale) Attiva chip "Inattivi"
3. Cerca dipendente per nome/email
4. Seleziona dipendente (o lascia vuoto per "Tutti")
5. Configura filtri (cantiere, date)
6. Genera report Excel

## ✅ Vantaggi

### Conservazione Dati:
- ✅ Storico timbrature completo
- ✅ Tracciabilità eliminazioni (deletedAt)
- ✅ Possibilità di riattivare dipendenti (manualmente via DB)
- ✅ Report accurati anche per dipendenti passati

### Sicurezza:
- ✅ Nessuna perdita di dati
- ✅ Audit trail completo
- ✅ Conformità normativa (conservazione dati lavoro)

### UX:
- ✅ Ricerca intuitiva con autocomplete
- ✅ Distinzione visiva attivi/inattivi
- ✅ Filtro rapido con chip
- ✅ Lista pulita senza dipendenti eliminati (per default)

## 🧪 Test

### Test 1: Eliminazione
1. Elimina un dipendente
2. Verifica che NON appaia più in "Personale"
3. Verifica che il report sia stato scaricato
4. Check database: `isActive = 0`, `deletedAt` popolato

### Test 2: Report con Inattivi
1. Tab Report
2. Attiva chip "Inattivi"
3. Cerca dipendente eliminato
4. Dovrebbe apparire con icon rossa e testo barrato
5. Selezionalo e genera report
6. Il report dovrebbe contenere le sue timbrature

### Test 3: Ricerca
1. Digita parte del nome
2. Lista si filtra in tempo reale
3. Click su dipendente → si seleziona
4. Click X → si deseleziona

## 📊 Compatibilità Retroattiva

### Dipendenti esistenti:
- `isActive` = 1 (default via ALTER TABLE)
- `deletedAt` = NULL
- Funzionano normalmente

### Migrazione automatica:
- Colonne aggiunte via `ALTER TABLE` in `db.js`
- Default values impostati correttamente
- Nessun intervento manuale richiesto

## 🔮 Funzionalità Future

### Possibili estensioni:
- Pulsante "Riattiva" per dipendenti eliminati (admin only)
- Statistiche eliminazioni (chi ha eliminato cosa e quando)
- Report comparativo attivi vs inattivi
- Export CSV lista dipendenti eliminati
- Filtro per data eliminazione

## 📝 Note Tecniche

### Performance:
- Index su `isActive` consigliato per query rapide
- `ORDER BY isActive DESC` mostra prima gli attivi

### Sicurezza:
- Soft delete solo lato server
- Controlli eliminazione lato client
- Impossibile eliminare via SQL injection (prepared statements)

### Backup:
- Prima dell'eliminazione: report Excel automatico
- Dopo eliminazione: dati ancora in DB
- Double safety per dati critici
