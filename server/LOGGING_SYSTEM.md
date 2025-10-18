# Sistema di Logging Dettagliato - Server

## Panoramica

È stato implementato un sistema di logging completo che traccia **tutte le operazioni** del server, con particolare attenzione alle operazioni che modificano il database.

## Modifiche Implementate

### 1. Middleware di Logging HTTP (server.js)

Aggiunto middleware globale che logga **ogni richiesta HTTP** prima di essere processata:

```javascript
app.use((req, res, next) => {
  const timestamp = new Date().toLocaleString('it-IT');
  console.log(`\n📡 [${timestamp}] ${req.method} ${req.originalUrl}`);
  
  // Log body per POST/PUT/PATCH (password censurata)
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && Object.keys(req.body).length > 0) {
    const sanitizedBody = { ...req.body };
    if (sanitizedBody.password) sanitizedBody.password = '***';
    console.log(`   📦 Body:`, JSON.stringify(sanitizedBody, null, 2));
  }
  
  // Log query params
  if (Object.keys(req.query).length > 0) {
    console.log(`   🔍 Query:`, req.query);
  }
  
  next();
});
```

### 2. Operazioni di Autenticazione

#### Login (`POST /api/login`)
**Prima:**
- Nessun log specifico

**Dopo:**
```
🔐 [LOGIN] Tentativo di login per: mario.rossi@example.com
✅ [LOGIN] Login riuscito - ID: 5, Nome: Mario Rossi, Admin: No
```

Oppure in caso di errore:
```
⛔ [LOGIN] Credenziali non valide per: utente@wrong.com
❌ [LOGIN] Errore database: Connection timeout
```

### 3. Operazioni sulle Timbrature

#### Timbratura Normale (`POST /api/attendance`)
**Log dettagliati:**
```
⏱️  [TIMBRATURA] Nuova timbratura ricevuta
   👤 Dipendente ID: 12
   🏗️  Cantiere ID: 3
   ⏰ Timestamp: 2025-10-18T14:30:00.000
   ➡️  Tipo: INGRESSO
   📍 Coordinate: 40.3548917, 18.1707463
   📱 Dispositivo: Android 13 - Pixel 6
✅ [TIMBRATURA] Registrata con successo - Record ID: 457
📊 [TIMBRATURA] Report Excel aggiornato
```

#### Timbratura Forzata (`POST /api/attendance/force`)
**Log ultra-dettagliati:**
```
🔨 [TIMBRATURA FORZATA] Richiesta ricevuta
   👤 Dipendente ID: 8
   🏗️  Cantiere ID: 2
   ⬅️  Tipo: USCITA
   👨‍💼 Admin ID: 1
   📝 Note: Dimenticato di timbrare
   ⏰ Timestamp personalizzato: 2025-10-17T18:00:00.000
✅ [TIMBRATURA FORZATA] Admin verificato: Admin (admin@example.com)
⏰ [TIMBRATURA FORZATA] Usando timestamp personalizzato: 2025-10-17T18:00:00.000
✅ [TIMBRATURA FORZATA] Registrata con successo - Record ID: 458
   📋 DeviceInfo: Forzato da Admin | Note: Dimenticato di timbrare
📊 [TIMBRATURA FORZATA] Report Excel aggiornato
```

### 4. Operazioni sui Dipendenti

#### Creazione Dipendente (`POST /api/employees`)
```
➕ [DIPENDENTE] Creazione nuovo dipendente
   👤 Nome: Luca Bianchi
   📧 Email: luca.bianchi@example.com
   👨‍💼 Admin: No
   🌙 Turni notturni: Sì
✅ [DIPENDENTE] Creato con successo - ID: 13
```

#### Modifica Dipendente (`PUT /api/employees/:id`)
```
✏️  [DIPENDENTE] Aggiornamento dipendente ID: 8
   👤 Nome: Marco Verdi
   📧 Email: marco.verdi@example.com
   👨‍💼 Admin: No
   🌙 Turni notturni: No
   🔑 Password: Aggiornata
✅ [DIPENDENTE] Aggiornato con successo - Righe modificate: 1
```

#### Eliminazione Dipendente (`DELETE /api/employees/:id`)

**Soft Delete (con timbrature):**
```
🗑️  [DIPENDENTE] Richiesta eliminazione dipendente ID: 9
🔒 [DIPENDENTE] SOFT DELETE - Dipendente 9 ha 47 timbrature
✅ [DIPENDENTE] Soft delete completato - Dipendente disattivato (47 timbrature preservate)
```

**Hard Delete (senza timbrature):**
```
🗑️  [DIPENDENTE] Richiesta eliminazione dipendente ID: 12
🗑️  [DIPENDENTE] HARD DELETE - Dipendente 12 senza timbrature
✅ [DIPENDENTE] Hard delete completato - Dipendente eliminato definitivamente
```

### 5. Operazioni sui Cantieri

#### Lista Cantieri (`GET /api/worksites`)
```
📋 [CANTIERI] Richiesta lista cantieri
✅ [CANTIERI] Restituiti 8 cantieri
```

#### Creazione Cantiere (`POST /api/worksites`)
```
➕ [CANTIERE] Creazione nuovo cantiere
   🏗️  Nome: Cantiere Milano Nord
   📍 Coordinate: 45.464664, 9.188540
   🗺️  Indirizzo: Via Roma 123, Milano
   📏 Raggio: 150m
   ✅ Attivo: Sì
   📝 Descrizione: Costruzione nuovo edificio residenziale
✅ [CANTIERE] Creato con successo - ID: 9
```

#### Modifica Cantiere (`PUT /api/worksites/:id`)
```
✏️  [CANTIERE] Aggiornamento cantiere ID: 1
   🏗️  Nome: Lecce
   📍 Coordinate: 40.354891, 18.170746
   🗺️  Indirizzo: Corte dei Ziani, Lecce
   📏 Raggio: 200m
   ✅ Attivo: Sì
   📝 Descrizione: Macchina N° 854 fuori uso.
✅ [CANTIERE] Aggiornato con successo - Righe modificate: 1
```

#### Eliminazione Cantiere (`DELETE /api/worksites/:id`)
```
🗑️  [CANTIERE] Eliminazione cantiere ID: 5 (Cantiere Test)
   📦 Backup creato: BACKUP_Cantiere_Test_2025-10-18.xlsx
   📊 Timbrature preservate: 156
✅ [CANTIERE] Eliminato con successo - Backup: BACKUP_Cantiere_Test_2025-10-18.xlsx
```

## Legenda Emoji

| Emoji | Significato |
|-------|-------------|
| 📡 | Richiesta HTTP in arrivo |
| 🔐 | Operazione di login/autenticazione |
| ⏱️ | Timbratura normale |
| 🔨 | Timbratura forzata |
| 👤 | Informazione dipendente |
| 🏗️ | Informazione cantiere |
| ➕ | Creazione nuovo record |
| ✏️ | Modifica record esistente |
| 🗑️ | Eliminazione record |
| 🔒 | Soft delete (disattivazione) |
| ✅ | Operazione completata con successo |
| ❌ | Errore durante l'operazione |
| ⛔ | Operazione negata (autorizzazione) |
| ⚠️ | Warning/attenzione |
| 📦 | Dati del body della richiesta |
| 🔍 | Query parameters |
| 📊 | Aggiornamento report |
| 📝 | Note o descrizioni |
| 📍 | Coordinate geografiche |
| 🗺️ | Indirizzo |
| 📏 | Raggio/distanza |
| ⏰ | Timestamp |
| 📱 | Informazione dispositivo |
| 👨‍💼 | Amministratore |
| 🌙 | Turni notturni |
| 🔑 | Password |
| 📋 | Lista/riepilogo |

## Vantaggi del Sistema di Logging

### 1. **Tracciabilità Completa**
- Ogni operazione CRUD è tracciata con timestamp e dettagli
- Possibile ricostruire la cronologia completa delle operazioni

### 2. **Debug Facilitato**
- Errori immediatamente visibili con contesto completo
- Stack trace automatici per gli errori

### 3. **Audit e Sicurezza**
- Registrazione di chi ha fatto cosa e quando
- Le password sono automaticamente censurate nei log

### 4. **Monitoraggio Performance**
- Visibilità su tutte le chiamate API
- Possibile identificare operazioni lente

### 5. **Facilità di Manutenzione**
- Log strutturati e leggibili
- Emoji per identificazione rapida del tipo di operazione

## Esempi di Output Console

### Scenario: Dipendente effettua timbratura, admin la corregge

```
📡 [18/10/2025, 14:30:15] POST /api/attendance
   📦 Body: {
  "employeeId": 5,
  "workSiteId": 2,
  "timestamp": "2025-10-18T14:30:00.000",
  "type": "in",
  ...
}

⏱️  [TIMBRATURA] Nuova timbratura ricevuta
   👤 Dipendente ID: 5
   🏗️  Cantiere ID: 2
   ⏰ Timestamp: 2025-10-18T14:30:00.000
   ➡️  Tipo: INGRESSO
   📍 Coordinate: 40.3548917, 18.1707463
   📱 Dispositivo: Android 13
✅ [TIMBRATURA] Registrata con successo - Record ID: 234
📊 [TIMBRATURA] Report Excel aggiornato

---

📡 [18/10/2025, 16:45:20] POST /api/attendance/force
   📦 Body: {
  "employeeId": 5,
  "workSiteId": 2,
  "type": "out",
  "adminId": 1,
  "notes": "Dipendente ha dimenticato di timbrare l'uscita",
  "timestamp": "2025-10-18T16:00:00.000"
}

🔨 [TIMBRATURA FORZATA] Richiesta ricevuta
   👤 Dipendente ID: 5
   🏗️  Cantiere ID: 2
   ⬅️  Tipo: USCITA
   👨‍💼 Admin ID: 1
   📝 Note: Dipendente ha dimenticato di timbrare l'uscita
   ⏰ Timestamp personalizzato: 2025-10-18T16:00:00.000
✅ [TIMBRATURA FORZATA] Admin verificato: Admin (admin@example.com)
⏰ [TIMBRATURA FORZATA] Usando timestamp personalizzato: 2025-10-18T16:00:00.000
✅ [TIMBRATURA FORZATA] Registrata con successo - Record ID: 235
   📋 DeviceInfo: Forzato da Admin | Note: Dipendente ha dimenticato di timbrare l'uscita
📊 [TIMBRATURA FORZATA] Report Excel aggiornato
```

### Scenario: Creazione nuovo cantiere

```
📡 [18/10/2025, 09:15:30] POST /api/worksites
   📦 Body: {
  "name": "Cantiere Roma Est",
  "latitude": 41.9028,
  "longitude": 12.4964,
  "address": "Via Appia Nuova 100, Roma",
  "radiusMeters": 120,
  "description": "Ristrutturazione palazzo storico"
}

➕ [CANTIERE] Creazione nuovo cantiere
   🏗️  Nome: Cantiere Roma Est
   📍 Coordinate: 41.9028, 12.4964
   🗺️  Indirizzo: Via Appia Nuova 100, Roma
   📏 Raggio: 120m
   ✅ Attivo: Sì
   📝 Descrizione: Ristrutturazione palazzo storico
✅ [CANTIERE] Creato con successo - ID: 10
```

## Note Tecniche

1. **Performance**: Il logging è sincrono ma non impatta significativamente le performance dato che scrive su console
2. **Sicurezza**: Le password sono automaticamente censurate (`***`) nei log del body
3. **Formato Timestamp**: Usa formato italiano locale (`toLocaleString('it-IT')`)
4. **Separazione**: Ogni richiesta è preceduta da `\n` per separazione visiva
5. **Colori**: Non sono usati colori ANSI per compatibilità con tutti i terminali

## Suggerimenti per Produzione

Per un ambiente di produzione, considera:

1. **Log su File**: Usa `winston` o `bunyan` per scrivere su file
2. **Log Rotation**: Implementa rotazione automatica dei log
3. **Livelli di Log**: Distingui tra DEBUG, INFO, WARN, ERROR
4. **Aggregazione**: Usa strumenti come ELK Stack o Datadog per aggregazione
5. **Filtri Sensibili**: Estendi la censura per altri dati sensibili (es. coordinate precise)

## File Modificati

1. `server/server.js` - Middleware globale e operazioni principali
2. `server/routes/worksites.js` - Operazioni sui cantieri
