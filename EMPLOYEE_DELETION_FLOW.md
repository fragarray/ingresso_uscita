# Flusso di Eliminazione Dipendente

## Panoramica

Il sistema di eliminazione dipendenti include controlli di sicurezza multi-livello e gestione automatica delle timbrature IN per garantire l'integrità dei dati.

## Flusso Completo

### 1. **Controlli Preliminari Admin**

Prima di procedere con qualsiasi azione, il sistema verifica:

- ✅ **Non può eliminare se stesso**: Un admin non può eliminare il proprio account
- ✅ **Almeno un admin deve rimanere**: Non può eliminare l'ultimo admin del sistema

Se uno di questi controlli fallisce, viene mostrato un alert di errore e l'operazione si interrompe.

### 2. **Controllo Stato Timbratura** 🆕

Il sistema verifica automaticamente se il dipendente è attualmente timbrato IN:

**Se timbrato OUT o mai timbrato:**
- ✅ Procede direttamente al passo 3

**Se timbrato IN:**
- ⚠️ **Mostra alert "Forza Timbratura OUT"** con:
  - Icona warning arancione
  - Nome del dipendente
  - Stato corrente: "TIMBRATO IN" (evidenziato)
  - Dettagli ultima timbratura (data/ora, cantiere)
  - Avviso: "È necessario timbrare OUT prima di eliminare"
  - Nota: Timbratura automatica con dati dell'ultima IN
  
- **Opzioni:**
  - `ANNULLA ELIMINAZIONE` → Interrompe tutto il processo
  - `TIMBRA OUT E CONTINUA` → Esegue timbratura OUT automatica

### 3. **Timbratura OUT Automatica** (se necessaria)

Quando l'admin conferma la timbratura OUT:

1. **Mostra loading dialog**: "Timbratura OUT in corso..."

2. **Esegue chiamata API** `forceAttendance`:
   ```dart
   ApiService.forceAttendance(
     employeeId: employee.id,
     type: 'OUT',
     workSiteId: lastRecord.workSiteId ?? 0,
     adminId: currentUser.id,
     notes: 'Timbratura OUT automatica prima dell\'eliminazione'
   )
   ```

3. **Verifica risultato:**
   - ❌ **Se fallisce**: 
     - Mostra SnackBar rossa: "Errore durante la timbratura OUT. Eliminazione annullata."
     - Interrompe l'intero processo
   - ✅ **Se ha successo**:
     - Chiude loading dialog
     - Mostra alert di conferma verde

4. **Alert di conferma timbratura**:
   - Icona check verde
   - Titolo: "Timbratura OUT completata"
   - Messaggio: Nome dipendente + "timbrato OUT con successo"
   - Box informativo verde: "La timbratura OUT è stata registrata nel database e apparirà nei report"
   - Nota: "Ora puoi procedere con l'eliminazione del dipendente"
   - Pulsante: `CONTINUA`

### 4. **Prima Conferma Eliminazione**

Alert arancione di warning:
- Titolo: "Attenzione!"
- Messaggio: 
  - Nome e ruolo del dipendente (Admin/Dipendente)
  - "Questa azione non può essere annullata"
  - "Dovrai scaricare obbligatoriamente il report completo"
- Opzioni:
  - `ANNULLA`
  - `CONTINUA`

### 5. **Download Obbligatorio Report**

Se l'admin continua:

1. **Mostra loading**: "Generazione report in corso..."

2. **Genera report Excel** filtrato per il dipendente:
   ```dart
   ApiService.downloadExcelReportFiltered(employeeId: employee.id)
   ```

3. **Verifica risultato:**
   - ❌ **Se fallisce**: 
     - SnackBar rossa: "Errore durante la generazione del report. Eliminazione annullata."
     - Interrompe processo
   - ✅ **Se ha successo**:
     - Mostra alert con path del file salvato
     - "Conserva questo file prima di procedere con l'eliminazione"

### 6. **Conferma Finale**

Alert rosso di errore (massima gravità):
- Titolo: "Conferma Finale"
- Messaggio: "ULTIMA CONFERMA"
- Dettagli dipendente:
  - Nome
  - Email
  - Ruolo
- "Il report è stato scaricato"
- "Sei assolutamente sicuro?"
- Opzioni:
  - `NO, ANNULLA`
  - `SÌ, ELIMINA` (pulsante rosso)

### 7. **Eliminazione (Soft Delete)**

Se l'admin conferma:

1. **Esegue eliminazione**:
   ```dart
   ApiService.removeEmployee(employee.id)
   ```
   - Backend esegue: `UPDATE employees SET isActive = 0, deletedAt = NOW() WHERE id = ?`
   - **NON è una cancellazione fisica**: i dati rimangono nel database

2. **Aggiorna UI**:
   - Ricarica lista dipendenti
   - Mostra SnackBar verde: "Nome eliminato. Report salvato in: [path]"

3. **Trigger refresh globale**:
   ```dart
   context.read<AppState>().triggerRefresh()
   ```

## Garanzie di Integrità Dati

### Timbrature

- ✅ **Nessun dipendente può essere eliminato con stato IN**
- ✅ **Timbratura OUT automatica tracciata** con:
  - Admin che l'ha forzata
  - Nota specifica: "Timbratura OUT automatica prima dell'eliminazione"
  - Timestamp corrente
  - Stesso cantiere dell'ultima timbratura IN

### Report

- ✅ **Report sempre completo** perché include la timbratura OUT forzata
- ✅ **Dati storici preservati** (soft delete)
- ✅ **Report scaricato obbligatoriamente** prima dell'eliminazione

### Tracciabilità

- ✅ **Timestamp eliminazione** (`deletedAt`)
- ✅ **Flag soft delete** (`isActive = 0`)
- ✅ **Timbrature forzate tracciate** (adminId, notes)

## Scenari d'Uso

### Scenario 1: Dipendente Timbrato OUT
```
Admin clicca "Elimina"
  ↓
Controlli admin OK
  ↓
Dipendente NON timbrato IN
  ↓
Prima conferma → Download report → Conferma finale → Eliminazione
```

### Scenario 2: Dipendente Timbrato IN
```
Admin clicca "Elimina"
  ↓
Controlli admin OK
  ↓
Dipendente TIMBRATO IN ⚠️
  ↓
Alert: "Forza Timbratura OUT"
  ↓
Admin conferma "TIMBRA OUT E CONTINUA"
  ↓
Timbratura OUT automatica ✅
  ↓
Alert: "Timbratura OUT completata"
  ↓
Prima conferma → Download report → Conferma finale → Eliminazione
```

### Scenario 3: Admin Annulla Durante Timbratura
```
Admin clicca "Elimina"
  ↓
Controlli admin OK
  ↓
Dipendente TIMBRATO IN ⚠️
  ↓
Alert: "Forza Timbratura OUT"
  ↓
Admin clicca "ANNULLA ELIMINAZIONE"
  ↓
PROCESSO INTERROTTO ❌
Dipendente rimane inalterato (ancora timbrato IN)
```

### Scenario 4: Errore Durante Timbratura OUT
```
Admin clicca "Elimina"
  ↓
Controlli admin OK
  ↓
Dipendente TIMBRATO IN ⚠️
  ↓
Alert: "Forza Timbratura OUT"
  ↓
Admin conferma "TIMBRA OUT E CONTINUA"
  ↓
Timbratura OUT fallisce ❌ (errore server/rete)
  ↓
SnackBar: "Errore durante la timbratura OUT. Eliminazione annullata."
  ↓
PROCESSO INTERROTTO
Dipendente rimane inalterato (ancora timbrato IN)
```

## Messaggi Utente

### Alert Timbratura OUT Richiesta
```
┌─────────────────────────────────────────┐
│ ⚠️ Forza Timbratura OUT - [Nome]       │
├─────────────────────────────────────────┤
│ [Box arancione]                         │
│ ℹ️ STATO ATTUALE: TIMBRATO IN          │
│                                         │
│ Ultima timbratura:                      │
│ • Tipo: ENTRATA                         │
│ • Data/Ora: 14/10/2025 09:30           │
│ • Cantiere: ID 5                        │
│                                         │
│ [Box rosso]                             │
│ ⚠️ È necessario timbrare OUT prima di  │
│    eliminare il dipendente.             │
│                                         │
│ Nota: La timbratura OUT verrà          │
│ registrata automaticamente con i dati   │
│ dell'ultima timbratura IN.              │
├─────────────────────────────────────────┤
│ [ANNULLA ELIMINAZIONE] [TIMBRA OUT E CONTINUA] │
└─────────────────────────────────────────┘
```

### Alert Timbratura Completata
```
┌─────────────────────────────────────────┐
│ ✅ Timbratura OUT completata            │
├─────────────────────────────────────────┤
│ [Nome] è stato timbrato OUT con successo.│
│                                         │
│ [Box verde]                             │
│ ℹ️ Timbratura registrata                │
│ La timbratura OUT è stata registrata    │
│ nel database e apparirà nei report.     │
│                                         │
│ Ora puoi procedere con l'eliminazione   │
│ del dipendente.                         │
├─────────────────────────────────────────┤
│                    [CONTINUA]            │
└─────────────────────────────────────────┘
```

## Codice Backend

La timbratura OUT forzata viene registrata con:

```sql
INSERT INTO attendance (
  employeeId, 
  workSiteId, 
  type, 
  timestamp, 
  deviceInfo,
  isForced,
  forcedByAdminId
) VALUES (
  ?, -- ID dipendente
  ?, -- ID cantiere (stesso dell'ultima IN)
  'OUT',
  NOW(),
  'Forzato da [Admin] | Note: Timbratura OUT automatica prima dell\'eliminazione',
  1,
  ? -- ID admin corrente
)
```

## Benefici

1. **Integrità dati**: Nessun dipendente può rimanere "timbrato IN" dopo l'eliminazione
2. **Report completi**: Ogni periodo lavorativo ha sempre IN + OUT
3. **Tracciabilità**: Ogni timbratura forzata è documentata
4. **UX chiara**: L'admin capisce esattamente cosa sta succedendo
5. **Sicurezza**: Conferme multiple prevengono eliminazioni accidentali
6. **Reversibilità parziale**: Soft delete permette recupero dati se necessario
