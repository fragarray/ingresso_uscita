# Feature: Modifica ed Eliminazione Timbrature

**Data implementazione:** 18 ottobre 2025  
**Versione:** 1.0.0

## 📋 Sommario

Questa funzionalità permette agli amministratori di modificare ed eliminare timbrature esistenti direttamente dall'interfaccia di gestione del personale tramite **long press** sugli elementi dello storico presenze.

## 🎯 Funzionalità Implementate

### 1. Menu Long Press

- **Attivazione:** Tieni premuto su una card di timbratura nello storico presenze
- **Opzioni disponibili:**
  - ✏️ **Modifica** - Apre dialog per modificare timestamp e cantiere
  - 🗑️ **Elimina** - Richiede conferma ed elimina la timbratura

### 2. Modifica Timbratura

**File modificati:**
- `lib/widgets/personnel_tab.dart` - Aggiunto `GestureDetector` con `onLongPress`
- `lib/services/api_service.dart` - Aggiunto metodo `editAttendance()`
- `server/server.js` - Aggiunto endpoint `PUT /api/attendance/:id`

**Campi modificabili:**
- 📅 Data e ora (IN e OUT)
- 🏗️ Cantiere (IN e OUT)

**Validazioni:**
- ✅ L'uscita deve essere successiva all'ingresso
- ✅ Solo admin possono modificare timbrature
- ✅ Timestamp viene convertito correttamente (locale → UTC)

**Dialog di modifica:**
```
┌─────────────────────────────────────┐
│ ✏️  Modifica Timbratura             │
├─────────────────────────────────────┤
│ Dipendente: Mario Rossi             │
│                                     │
│ ➡️  INGRESSO                        │
│ [📅 Data/Ora: 17/10/2025 08:30]    │
│ [🏗️ Cantiere: ▼ Cantiere A]       │
│                                     │
│ ⬅️  USCITA                          │
│ [📅 Data/Ora: 17/10/2025 17:00]    │
│ [🏗️ Cantiere: ▼ Cantiere A]       │
├─────────────────────────────────────┤
│ [Annulla]              [💾 Salva]  │
└─────────────────────────────────────┘
```

**Flusso di modifica:**
1. Long press sulla card → Menu appare
2. Clicca "Modifica" → Dialog si apre con valori attuali
3. Modifica campi desiderati
4. Clicca data/ora per aprire picker
5. Clicca "Salva"
6. ✅ Loading → API call → Ricarica dati → Conferma

### 3. Eliminazione Timbratura

**File modificati:**
- `lib/widgets/personnel_tab.dart` - Aggiunto metodo `_deleteAttendance()`
- `lib/services/api_service.dart` - Aggiunto metodo `deleteAttendance()`
- `server/server.js` - Aggiunto endpoint `DELETE /api/attendance/:id`

**Comportamento:**
- 🔗 Se elimini un IN con OUT associato, elimina **entrambi**
- ⚠️ Conferma obbligatoria con dettagli della timbratura
- 🚫 Operazione **irreversibile**

**Dialog di conferma:**
```
┌─────────────────────────────────────┐
│ ⚠️  Conferma Eliminazione           │
├─────────────────────────────────────┤
│ Sei sicuro di voler eliminare       │
│ questa timbratura?                  │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Dipendente: Mario Rossi         │ │
│ │ IN:  17/10/2025 08:30          │ │
│ │ OUT: 17/10/2025 17:00          │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ⚠️ Questa azione è irreversibile!   │
├─────────────────────────────────────┤
│ [Annulla]            [🗑️ Elimina]  │
└─────────────────────────────────────┘
```

**Flusso di eliminazione:**
1. Long press sulla card → Menu appare
2. Clicca "Elimina" → Dialog di conferma appare
3. Clicca "Elimina" nel dialog
4. 🗑️ Loading → API call → Ricarica dati → Conferma

## 🔧 Dettagli Tecnici

### API Endpoints

#### PUT /api/attendance/:id
Modifica una timbratura esistente.

**Richiesta:**
```json
{
  "adminId": 1,
  "timestamp": "2025-10-17T08:30:00",
  "workSiteId": 5
}
```

**Risposta (successo):**
```json
{
  "success": true,
  "message": "Attendance record updated"
}
```

**Validazioni server:**
- ✅ Admin deve esistere e avere `isAdmin = 1`
- ✅ Record deve esistere
- ✅ Aggiunge `Modificato da [Admin Name]` al `deviceInfo`
- ✅ Aggiorna automaticamente il report Excel

**Logging:**
```
✏️ [MODIFICA TIMBRATURA] Richiesta modifica record ID: 123
   👨‍💼 Admin ID: 1
   ⏰ Nuovo timestamp: 2025-10-17T08:30:00
   🏗️  Nuovo cantiere: 5
✅ [MODIFICA TIMBRATURA] Admin verificato: Mario Rossi
✅ [MODIFICA TIMBRATURA] Record ID 123 aggiornato con successo
   📋 DeviceInfo aggiornato: Forzato da Admin | Modificato da Mario Rossi
📊 [MODIFICA TIMBRATURA] Report Excel aggiornato
```

#### DELETE /api/attendance/:id
Elimina una timbratura esistente.

**Richiesta:**
```json
{
  "adminId": 1,
  "deleteOutToo": true
}
```

**Risposta (successo):**
```json
{
  "success": true,
  "message": "Attendance record deleted"
}
```

**Validazioni server:**
- ✅ Admin deve esistere e avere `isAdmin = 1`
- ✅ Record deve esistere
- ✅ Se `deleteOutToo = true` e record è IN, elimina anche OUT successivo
- ✅ Aggiorna automaticamente il report Excel

**Logging:**
```
🗑️ [ELIMINA TIMBRATURA] Richiesta eliminazione record ID: 123
   👨‍💼 Admin ID: 1
   🔗 Elimina OUT associato: Sì
✅ [ELIMINA TIMBRATURA] Admin verificato: Mario Rossi
📋 [ELIMINA TIMBRATURA] Record trovato: Tipo=in, Dipendente=5
🗑️ [ELIMINA TIMBRATURA] Eliminato anche OUT associato
✅ [ELIMINA TIMBRATURA] Record ID 123 eliminato con successo
📊 [ELIMINA TIMBRATURA] Report Excel aggiornato
```

### Client Side

**Metodi API Service:**

```dart
// Modifica timbratura
static Future<bool> editAttendance({
  required int recordId,
  required int adminId,
  DateTime? timestamp,
  int? workSiteId,
}) async

// Elimina timbratura
static Future<bool> deleteAttendance({
  required int recordId,
  required int adminId,
  bool deleteOutToo = false,
}) async
```

**Widget Dialog:**
- `_EditAttendanceDialog` - StatefulWidget con form reattivo
- Picker integrati per data/ora
- Dropdown per cantieri
- Validazione locale prima dell'invio

## 🎨 UI/UX

### Interazioni

**Long Press Detection:**
- Funziona su entrambi i tipi di card:
  - `_buildSessionPairCard()` - Coppie complete IN/OUT
  - `_buildSingleRecordCard()` - Record singoli

**Feedback Visivo:**
- 🔄 Dialog di loading durante operazioni
- ✅ SnackBar verde per operazioni riuscite
- ❌ SnackBar rosso per errori
- ⏳ "Modifica in corso..." / "Eliminazione in corso..."

**Messaggi Utente:**
- ✅ "Timbratura modificata con successo"
- ✅ "Timbratura eliminata con successo"
- ❌ "Errore durante la modifica"
- ❌ "Errore durante l'eliminazione"
- ❌ "L'uscita deve essere successiva all'ingresso"
- ❌ "Admin non identificato"

### Responsive Design

- Dialog larghezza fissa: `500px`
- `SingleChildScrollView` per contenuto lungo
- Layout compatto per mobile
- Icone colorate per IN (verde) e OUT (rosso)

## 🔒 Sicurezza

### Autenticazione
- **Solo admin** possono modificare/eliminare
- Verifica server-side dell'admin tramite query DB
- Admin ID passato in ogni richiesta

### Validazioni
- Timestamp OUT >= IN
- Record devono esistere
- Admin deve avere `isAdmin = 1`

### Audit Trail
- Ogni modifica registra l'admin nel `deviceInfo`
- Log dettagliati server-side con emoji
- Timestamp ISO 8601 per tutte le operazioni

## 📊 Report Excel

**Aggiornamento automatico:**
- Dopo ogni modifica
- Dopo ogni eliminazione
- Gestione errori non bloccante (warning in log)

## 🧪 Testing

### Casi di test

**Modifica:**
1. ✅ Modifica timestamp IN
2. ✅ Modifica timestamp OUT
3. ✅ Modifica cantiere IN
4. ✅ Modifica cantiere OUT
5. ✅ Modifica entrambi (IN e OUT)
6. ❌ OUT prima di IN → Validazione blocca
7. ❌ Admin non autorizzato → 403

**Eliminazione:**
1. ✅ Elimina coppia IN/OUT completa
2. ✅ Elimina solo IN (senza OUT)
3. ✅ Elimina solo OUT (anomalia)
4. ❌ Admin non autorizzato → 403
5. ❌ Record inesistente → 404

**Ricaricamento dati:**
1. ✅ Lista dipendenti aggiornata
2. ✅ Storico presenze aggiornato
3. ✅ Stato dipendente (IN/OUT) aggiornato

## 📝 Note Implementative

### Timestamp Handling
- **Client → Server:** `DateTime.toIso8601String()` (UTC)
- **Server → DB:** Stored as text in ISO 8601 format
- **Display:** `DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal())`

### Record Pairing
- Logica esistente `_createAttendancePairs()` non modificata
- Eliminazione preserva integrità delle coppie
- OUT senza IN non può essere modificato (solo eliminato)

### Error Handling
- Try-catch su tutte le operazioni async
- Mounted check prima di aggiornare UI
- Messaggi utente friendly in italiano
- Log dettagliati con emoji per server

## 🚀 Deployment

**Server:**
```bash
# Nessuna migrazione DB necessaria
# Endpoints aggiunti a runtime
systemctl restart ingresso-uscita
```

**Client:**
```bash
flutter build apk --release
# Distribuisci nuova versione APK
```

## 🔮 Futuri Miglioramenti

1. **Undo/Redo** - Storia delle modifiche con possibilità di annullare
2. **Bulk Edit** - Modifica multipla di timbrature
3. **Export Audit Log** - Esportazione registro modifiche
4. **Notifiche** - Alert su modifiche critiche
5. **Permessi Granulari** - Admin con permessi limitati

## 📚 Riferimenti

- [FIX_FORCE_ATTENDANCE_VALIDATION.md](FIX_FORCE_ATTENDANCE_VALIDATION.md) - Validazioni sovrapposizione
- [SOFT_DELETE_DIPENDENTI.md](SOFT_DELETE_DIPENDENTI.md) - Sistema soft delete
- [server/README.md](server/README.md) - Documentazione API completa

---

**Implementato da:** GitHub Copilot  
**Testato su:** Android, Windows Desktop  
**Stato:** ✅ Produzione
