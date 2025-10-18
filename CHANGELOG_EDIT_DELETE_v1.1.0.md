# Changelog - Modifica ed Eliminazione Timbrature

**Data:** 18 ottobre 2025  
**Versione:** 1.1.0

## 🎉 Nuove Funzionalità

### ✏️ Modifica Timbrature Esistenti

- **Long press** su qualsiasi timbratura nello storico presenze apre menu contestuale
- **Dialog di modifica** permette di cambiare:
  - 📅 Data e ora IN
  - 📅 Data e ora OUT
  - 🏗️ Cantiere IN
  - 🏗️ Cantiere OUT
- **Validazione:** Uscita deve essere dopo ingresso
- **Audit trail:** Ogni modifica registra l'admin nel deviceInfo

### 🗑️ Eliminazione Timbrature

- **Opzione "Elimina"** nel menu long press
- **Conferma obbligatoria** con dettagli della timbratura
- **Eliminazione intelligente:** Se elimini IN con OUT associato, elimina entrambi
- **Irreversibile:** Avviso chiaro all'utente

### 🔒 Blocco Account Eliminati

- Account con `deleted = 1` non possono più fare login
- Messaggio chiaro: "Account Disattivato - Contatta l'amministratore"
- Validazione server-side con status `403 Forbidden`
- Auto-login disabilitato per account eliminati

## 🔧 Modifiche Tecniche

### Server (`server/server.js`)

**Nuovi Endpoint:**
- `PUT /api/attendance/:id` - Modifica timbratura
- `DELETE /api/attendance/:id` - Elimina timbratura

**Modifiche Esistenti:**
- `POST /api/login` - Aggiunto controllo `deleted = 1`

**Logging:**
- ✏️ `[MODIFICA TIMBRATURA]` con emoji e dettagli
- 🗑️ `[ELIMINA TIMBRATURA]` con audit trail
- 🚫 `[LOGIN]` Account eliminato

### Client (`lib/`)

**Nuovi Metodi API (`services/api_service.dart`):**
```dart
editAttendance({recordId, adminId, timestamp?, workSiteId?})
deleteAttendance({recordId, adminId, deleteOutToo})
```

**Modifiche UI (`widgets/personnel_tab.dart`):**
- `GestureDetector` con `onLongPress` su card timbrature
- `_showEditAttendanceMenu()` - Menu contestuale
- `_editAttendance()` - Flusso modifica completo
- `_deleteAttendance()` - Flusso eliminazione con conferma
- `_EditAttendanceDialog` - Widget dialog modifica

**Modifiche Login (`pages/login_page.dart`):**
- `on Exception catch` specifico per account eliminati
- SnackBar rosso 6 secondi con messaggio dettagliato
- `_attemptAutoLogin()` - Gestione account eliminati

## 📊 Statistiche

**File Modificati:** 4
- `server/server.js` (+186 righe)
- `lib/services/api_service.dart` (+81 righe)
- `lib/widgets/personnel_tab.dart` (+303 righe)
- `lib/pages/login_page.dart` (+28 righe)

**File Creati:** 1
- `FEATURE_EDIT_DELETE_ATTENDANCE.md` (documentazione completa)

**Totale Righe Aggiunte:** ~598

## ✅ Testing

### Completato
- ✅ Modifica timestamp IN/OUT
- ✅ Modifica cantiere IN/OUT
- ✅ Validazione OUT >= IN
- ✅ Eliminazione coppia IN/OUT
- ✅ Eliminazione record singolo
- ✅ Blocco login account eliminati
- ✅ Auto-login account eliminati
- ✅ Ricaricamento dati post-modifica

### Da Testare su Dispositivi Reali
- 📱 Long press su Android (touch)
- 🖱️ Long press su Windows (click)
- 🌐 Latency con server remoto
- 📊 Report Excel aggiornato

## 🐛 Bug Fix

### Risolti in questa release
- ✅ Account eliminati potevano ancora fare login
- ✅ Nessun modo di correggere errori nelle timbrature
- ✅ Timbrature duplicate non eliminabili
- ✅ Eliminazione IN con deleteOutToo non trovava OUT con timestamp precedente (v1.1.1)

## 🔮 Roadmap

### Prossime Versioni
- [ ] Undo/Redo per modifiche
- [ ] Export audit log
- [ ] Modifica multipla (bulk edit)
- [ ] Notifiche push su modifiche
- [ ] Permessi admin granulari

## 📝 Note Migrazione

**Da versione precedente:**
1. Nessuna migrazione DB necessaria
2. Riavviare server: `systemctl restart ingresso-uscita`
3. Distribuire nuovo APK ai dispositivi
4. Testare login con account eliminati
5. Testare modifica/eliminazione timbrature

**Breaking Changes:**
- Nessuno ✅

## 🙏 Credits

Implementato con l'assistenza di **GitHub Copilot**  
Testato su Flutter 3.9.2 / Node.js 18.x

---

**Versione Precedente:** 1.0.0  
**Versione Corrente:** 1.1.0  
**Stato:** ✅ Stabile - Pronto per produzione
