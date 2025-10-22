# 🔧 FIX BACKUP E RESTORE DATABASE

## Problemi Risolti

### 1. ❌ Errore "Tabella 'attendance' mancante nel database"

**Causa**: La funzione di validazione del database nel server cercava una tabella chiamata `'attendance'`, ma la tabella corretta si chiama `'attendance_records'`.

**File modificato**: `server/server.js` (linea ~3803)

**Codice vecchio**:
```javascript
const requiredTables = ['employees', 'work_sites', 'attendance'];
```

**Codice corretto**:
```javascript
const requiredTables = ['employees', 'work_sites', 'attendance_records'];
```

**Risultato**: ✅ Ora il restore di un database funziona correttamente senza errori di validazione.

---

### 2. ➕ Aggiunta opzione "1 giorno" per backup automatico

**Richiesta**: Permettere backup giornalieri oltre alle opzioni 3/7/15/30 giorni.

**File modificato**: `lib/pages/admin_page.dart` (linea ~1239)

**Modifiche applicate**:
- Aggiunto nuovo `ChoiceChip` per "1 giorno"
- Posizionato come prima opzione prima di "3 giorni"
- Logica di salvataggio identica alle altre opzioni

**Codice aggiunto**:
```dart
ChoiceChip(
  label: const Text('1 giorno'),
  selected: _autoBackupDays == 1,
  onSelected: (selected) {
    if (selected) {
      setState(() => _autoBackupDays = 1);
      _saveBackupSettings();
    }
  },
),
```

**Risultato**: ✅ Gli admin possono ora impostare backup automatici giornalieri.

---

### 3. ✅ Verifica impostazioni salvate sul server

**Domanda**: Le impostazioni di backup sono salvate sul server o nelle SharedPreferences?

**Risposta**: ✅ **Le impostazioni sono CORRETTAMENTE salvate sul server**

**Dettagli tecnici**:
- **File server**: `server/backup_settings.json`
- **Funzione di salvataggio**: `saveBackupSettings()` in `server.js` (linea ~3581)
- **API endpoint**: `POST /api/backup/settings`
- **Formato JSON**:
  ```json
  {
    "autoBackupEnabled": true,
    "autoBackupDays": 7,
    "lastBackupDate": "2025-10-22T10:30:00.000Z"
  }
  ```

**Flusso corretto**:
1. Admin cambia impostazione nell'app Flutter
2. Flutter chiama `ApiService.saveBackupSettings()`
3. API POST `/api/backup/settings` salva nel file JSON sul server
4. Il server legge queste impostazioni per il backup automatico

**Nota importante**: Le SharedPreferences nell'app Flutter sono usate SOLO per:
- IP del server (`serverIp`)
- Porta del server (`serverPort`)
- Dati di sessione (token, ultimo utente)

**Tutte le altre impostazioni** (GPS accuracy, backup settings, etc.) **sono centralizzate sul server**.

---

## Struttura Database Validata

Il restore ora valida correttamente queste tabelle:

### ✅ Tabella `employees`
Colonne richieste:
- `id` (INTEGER PRIMARY KEY)
- `name` (TEXT NOT NULL)
- `email` (TEXT)
- `password` (TEXT NOT NULL)
- `isAdmin` (INTEGER)

### ✅ Tabella `work_sites`
Contiene i cantieri con coordinate GPS

### ✅ Tabella `attendance_records` (CORRETTO!)
Contiene tutte le timbrature con campi:
- `id`, `employeeId`, `workSiteId`
- `timestamp`, `type` (in/out)
- `latitude`, `longitude`
- `isForced`, `forcedByAdminId`, `notes`

---

## Test Suggeriti

### Test 1: Restore Database
1. Vai in Impostazioni → Backup Database
2. Scarica un backup esistente
3. Clicca "Ripristina da Backup"
4. Seleziona il file .db scaricato
5. **Verifica**: Non dovrebbe più apparire l'errore "tabella 'attendance' mancante"
6. **Verifica**: Il server si riavvia e i dati vengono ripristinati correttamente

### Test 2: Backup Giornaliero
1. Vai in Impostazioni → Backup Database
2. Attiva "Backup Automatico"
3. Seleziona "1 giorno"
4. **Verifica**: L'opzione viene selezionata correttamente
5. **Verifica sul server**: Controlla `server/backup_settings.json`
   ```bash
   cat ~/ingresso-uscita/server/backup_settings.json
   ```
   Dovrebbe mostrare `"autoBackupDays": 1`

### Test 3: Persistenza Impostazioni
1. Imposta backup automatico su "1 giorno"
2. Chiudi completamente l'app
3. Riapri l'app e vai in Impostazioni
4. **Verifica**: L'opzione "1 giorno" è ancora selezionata
5. **Verifica**: Apri l'app da un altro dispositivo
6. **Verifica**: Anche dal secondo dispositivo vedi "1 giorno" (conferma centralizzazione)

---

## File Modificati

### Server
- ✅ `server/server.js` - Linea ~3803: Corretto nome tabella in validazione

### Flutter
- ✅ `lib/pages/admin_page.dart` - Linea ~1239: Aggiunta opzione "1 giorno"

---

## Riepilogo Finale

| Problema | Stato | Dettaglio |
|----------|-------|-----------|
| ❌ Errore tabella 'attendance' mancante | ✅ RISOLTO | Corretto in 'attendance_records' |
| ➕ Opzione backup "1 giorno" | ✅ AGGIUNTO | Disponibile come prima scelta |
| ❓ Impostazioni sul server | ✅ VERIFICATO | Salvate correttamente in backup_settings.json |

---

## Prossimi Passi

1. **Riavvia il server** sul Raspberry:
   ```bash
   sudo systemctl restart ingresso-uscita
   ```

2. **Ricompila l'APK** con le modifiche:
   ```bash
   flutter build apk --release
   ```

3. **Testa il restore** con un database di backup esistente

4. **Verifica backup giornaliero** impostando "1 giorno" e controllando dopo 24 ore se viene creato automaticamente

---

## Note Tecniche

### Validazione Database
La funzione `validateDatabaseStructure()` ora:
- ✅ Controlla esistenza di `attendance_records` (non più `attendance`)
- ✅ Verifica colonne critiche in `employees`
- ✅ Previene restore di database corrotti o incompatibili

### Backup Automatico
Il server controlla le impostazioni ogni 24 ore:
- Legge `backup_settings.json`
- Calcola giorni dall'ultimo backup
- Se >= `autoBackupDays`, crea nuovo backup automaticamente

### Sicurezza Restore
Prima di ogni restore, il server:
1. Valida struttura database caricato
2. Crea backup del database corrente (pre_restore_backup_*.db)
3. Chiude connessione al database corrente
4. Sostituisce il file database
5. Riavvia il processo (gestito da systemd/pm2)

---

✅ **Tutte le modifiche sono state applicate con successo!**
