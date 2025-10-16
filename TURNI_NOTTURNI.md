# Funzionalità Turni Notturni

## Descrizione
Implementazione del flag `allowNightShift` per autorizzare specifici dipendenti a lavorare oltre la mezzanotte senza essere soggetti all'auto-logout automatico.

## Modifiche Implementate

### 1. Database (`server/db.js`)
- **Aggiunta colonna**: `allowNightShift INTEGER DEFAULT 0` alla tabella `employees`
- **Default**: 0 (non autorizzato ai turni notturni)
- **Valori**: 
  - `0` = dipendente normale (soggetto ad auto-logout a mezzanotte)
  - `1` = autorizzato ai turni notturni (escluso dall'auto-logout)

### 2. Model Employee (`lib/models/employee.dart`)
- **Aggiunto campo**: `final bool allowNightShift`
- **Default**: `false`
- **Serializzazione**: 
  - `toMap()`: converte `bool` → `int` (0/1)
  - `fromMap()`: converte `int` (0/1) → `bool`

### 3. Dialog Creazione Dipendente (`lib/widgets/add_employee_dialog.dart`)
- **Aggiunto checkbox**: "Autorizza turni notturni"
- **Subtitle**: "Può lavorare oltre la mezzanotte (no auto-logout)"
- **Posizione**: Sotto il checkbox "Crea come Admin"
- **Stato iniziale**: `false` (non selezionato)

### 4. Dialog Modifica Dipendente (`lib/widgets/edit_employee_dialog.dart`)
- **Aggiunto checkbox**: "Autorizza turni notturni"
- **Subtitle**: "Può lavorare oltre la mezzanotte (no auto-logout)"
- **Icona**: `Icons.nights_stay` (luna) in colore indaco
- **Posizione**: Sotto il checkbox "Utente Admin"
- **Stato iniziale**: Carica il valore corrente dal dipendente

### 5. Server - Endpoint Creazione (`POST /api/employees`)
- **Aggiunto parametro**: `allowNightShift` nel body della request
- **Validazione**: Converte `bool` o `1/0` → `0/1`
- **Query SQL**: 
  ```sql
  INSERT INTO employees (name, email, password, isAdmin, allowNightShift) 
  VALUES (?, ?, ?, ?, ?)
  ```

### 6. Server - Endpoint Aggiornamento (`PUT /api/employees/:id`)
- **Aggiunto parametro**: `allowNightShift` nel body della request
- **Validazione**: Converte `bool` o `1/0` → `0/1`
- **Query SQL** (con password):
  ```sql
  UPDATE employees 
  SET name = ?, email = ?, password = ?, isAdmin = ?, allowNightShift = ? 
  WHERE id = ?
  ```
- **Query SQL** (senza password):
  ```sql
  UPDATE employees 
  SET name = ?, email = ?, isAdmin = ?, allowNightShift = ? 
  WHERE id = ?
  ```

### 7. Server - Auto-Checkout a Mezzanotte (`autoForceCheckout()`)
- **Modifica query**: Aggiunta condizione di esclusione
  ```sql
  WHERE ar.type = 'in'
    AND e.isActive = 1
    AND (e.allowNightShift IS NULL OR e.allowNightShift = 0)
  ```
- **Comportamento**:
  - Dipendenti con `allowNightShift = 0` o `NULL` → **soggetti ad auto-logout**
  - Dipendenti con `allowNightShift = 1` → **ESCLUSI dall'auto-logout**
- **Orario esecuzione**: Ogni giorno alle 00:01 (cron job)
- **Timestamp uscita forzata**: 23:59:59 del giorno precedente

## Funzionamento Auto-Checkout

### Processo Automatico
1. **Trigger**: Cron job alle 00:01 ogni notte (timezone: Europe/Rome)
2. **Query**: Trova tutti i dipendenti con ultima timbratura = IN
3. **Filtro**: Esclude dipendenti con `allowNightShift = 1`
4. **Azione**: Per ogni dipendente trovato:
   - Crea timbratura OUT forzata
   - Timestamp: 23:59:59 del giorno precedente
   - Note: "USCITA FORZATA PER SUPERAMENTO ORARIO"
   - `isForced = 1`, `forcedByAdminId = [primo admin trovato]`
5. **Report**: Aggiorna automaticamente il report Excel

### Log Console
```
⏰ [CRON] Job auto-checkout avviato alle 00:01
🕐 [AUTO-CHECKOUT] Avvio controllo timbrature aperte...
⚠️  [AUTO-CHECKOUT] Trovati 2 dipendenti ancora IN:
   ✓ Mario Rossi - Cantiere A - OUT automatico alle 23:59:59
   ✓ Luigi Bianchi - Cantiere B - OUT automatico alle 23:59:59

📊 [AUTO-CHECKOUT] Riepilogo:
   ✓ Processati: 2
   ❌ Falliti: 0
   📅 Timestamp: 2025-10-15T23:59:59
   
✓ [AUTO-CHECKOUT] Report Excel aggiornato
```

## Casi d'Uso

### Dipendente Normale (allowNightShift = 0)
- **Scenario**: Operaio con orario 08:00-17:00
- **Comportamento**: Se dimentica di timbrare OUT, riceve automaticamente un OUT forzato alle 23:59:59
- **Vantaggio**: Evita sessioni di lavoro anomale di 24+ ore nei report

### Dipendente Turni Notturni (allowNightShift = 1)
- **Scenario**: Guardiano notturno con turno 22:00-06:00
- **Comportamento**: Non viene timbrato automaticamente OUT a mezzanotte
- **Vantaggio**: Può lavorare normalmente durante la notte senza interruzioni

### Amministratore
- **Raccomandazione**: Impostare `allowNightShift = 1` per admin che potrebbero fare interventi fuori orario
- **Motivo**: Evitare auto-logout durante manutenzioni notturne

## Test Manuale

### Endpoint di Test
```
POST /api/admin/force-auto-checkout
```
Permette di eseguire manualmente l'auto-checkout senza aspettare le 00:01.

### Procedura di Test
1. Creare un dipendente con `allowNightShift = 0`
2. Creare un dipendente con `allowNightShift = 1`
3. Timbrare IN entrambi i dipendenti
4. Chiamare l'endpoint di test
5. **Risultato atteso**:
   - Dipendente con `allowNightShift = 0` → riceve OUT forzato
   - Dipendente con `allowNightShift = 1` → rimane IN (non processato)

## Compatibilità

### Database Esistenti
- La colonna `allowNightShift` viene aggiunta automaticamente all'avvio del server
- **Default**: `0` per tutti i dipendenti esistenti
- **Azione richiesta**: Modificare manualmente i dipendenti che necessitano turni notturni

### Versioni Precedenti
- I dipendenti creati prima dell'update avranno `allowNightShift = NULL` o `0`
- Saranno comunque soggetti all'auto-checkout (condizione `IS NULL OR = 0`)

## Note di Sicurezza

⚠️ **ATTENZIONE**: Autorizzare un dipendente ai turni notturni significa:
- Non verrà mai timbrato automaticamente OUT a mezzanotte
- Potrebbe rimanere "IN" per più giorni se dimentica di timbrare OUT
- Verificare regolarmente lo stato di questi dipendenti

💡 **SUGGERIMENTO**: Usare questa funzionalità solo per dipendenti con effettivi turni notturni regolari.

## Modifiche Future Suggerite

1. **Dashboard Admin**: Aggiungere indicatore visivo per dipendenti con turni notturni
2. **Alert**: Notifica se un dipendente con `allowNightShift = 1` rimane IN per più di 12 ore
3. **Report**: Sezione dedicata per analisi turni notturni
4. **Statistiche**: Conteggio ore notturne vs ore diurne

---
**Data implementazione**: 16 Ottobre 2025  
**Versione**: 1.0.0
