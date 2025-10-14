# Fix Finale - Type Casting Error

## Data: 14 Ottobre 2025

## 🐛 BUG FINALE RISOLTO

### **Errore**
```
Get attendance records error: type 'int' is not a subtype of type 'double'
```

### **Output Debug Completo**
```
Restarted application in 805ms.
Get attendance records error: type 'int' is not a subtype of type 'double'
=== DEBUG LOAD LAST RECORD ===
Total records: 0
No records found for employee
=== ATTENDANCE RECORDED ===
Record type sent: in
Current _isClockedIn before reload: false
Get attendance records error: type 'int' is not a subtype of type 'double'
=== DEBUG LOAD LAST RECORD ===
Total records: 0
No records found for employee
Current _isClockedIn after reload: false
=== END ATTENDANCE RECORDED ===
```

### **Analisi**

L'errore si verificava durante il parsing dei record dal server:
1. Il dipendente timbrava → Record creato e inviato al server ✅
2. Il server salvava correttamente nel DB ✅
3. `_loadLastRecord()` richiedeva i record dal server ✅
4. Il server restituiva i dati con `CAST(latitude AS REAL)` ✅
5. **SQLite restituiva `0` come `int` invece di `0.0` come `double`** ❌
6. `AttendanceRecord.fromMap()` tentava di assegnare `int` a `double` ❌
7. **CRASH**: Exception non gestita → lista vuota ritornata
8. Risultato: `Total records: 0` anche se i record esistevano!

### **Causa Tecnica**

#### Problema con SQLite e JSON
SQLite non ha un vero tipo `REAL` per i numeri interi. Quando salvi `0.0`:
- SQLite lo memorizza come `0` (intero)
- Quando fai `CAST(latitude AS REAL)`, se il valore è `0`, SQLite ritorna `0` (int)
- JSON encode/decode in Dart preserva il tipo: `int` rimane `int`

#### Il Codice Problematico

**Server** (`server.js`):
```javascript
// Questo CAST non garantisce il tipo in JSON!
CAST(latitude AS REAL) as latitude,
CAST(longitude AS REAL) as longitude
```

**Client** (`attendance_record.dart`):
```dart
// ❌ ERRORE: Assume che map['latitude'] sia sempre double
latitude: map['latitude'],  // Se è int → CRASH!
longitude: map['longitude'],
```

### **Soluzione Implementata**

#### ✅ Client - Type-safe Casting

**File**: `lib/models/attendance_record.dart`
```dart
factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
  return AttendanceRecord(
    id: map['id'],
    employeeId: map['employeeId'],
    workSiteId: map['workSiteId'],
    timestamp: DateTime.parse(map['timestamp']),
    type: map['type'],
    deviceInfo: map['deviceInfo'],
    // ✅ Converte num (int o double) a double
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
  );
}
```

**File**: `lib/models/work_site.dart`
```dart
factory WorkSite.fromMap(Map<String, dynamic> map) {
  return WorkSite(
    id: map['id'],
    name: map['name'],
    // ✅ Converte num (int o double) a double
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    address: map['address'],
    isActive: map['isActive'] == 1,
    radiusMeters: map['radiusMeters'] != null 
        ? (map['radiusMeters'] as num).toDouble() 
        : 100.0,
    createdAt: map['createdAt'] != null 
        ? DateTime.parse(map['createdAt']) 
        : null,
  );
}
```

### **Come Funziona il Fix**

#### Type Hierarchy in Dart
```
Object
  └── num (abstract)
      ├── int
      └── double
```

#### Il Cast Corretto
```dart
// ❌ PRIMA (ERRATO):
latitude: map['latitude'],  // int non può diventare double implicitamente

// ✅ DOPO (CORRETTO):
latitude: (map['latitude'] as num).toDouble()
// 1. Cast a 'num' (accetta sia int che double)
// 2. Converti a double con .toDouble()
// 3. Se è int → converte a double
// 4. Se è già double → ritorna lo stesso valore
```

### **Esempi di Conversione**

```dart
// Caso 1: Valore intero
map['latitude'] = 0;           // int
(0 as num).toDouble();         // 0.0 (double) ✅

// Caso 2: Valore decimale
map['latitude'] = 45.123;      // double
(45.123 as num).toDouble();    // 45.123 (double) ✅

// Caso 3: Valore "intero" decimale
map['latitude'] = 12.0;        // double
(12.0 as num).toDouble();      // 12.0 (double) ✅
```

---

## 📊 IMPATTO DEL BUG

### Cosa NON Funzionava

1. ❌ **Nessun record caricato**: Exception nel parsing → lista vuota
2. ❌ **Stato sempre OUT**: Nessun record = `_isClockedIn = false`
3. ❌ **Timbrature non visualizzate**: Lista vuota in UI
4. ❌ **Admin non vedeva presenze**: Stessa exception ovunque
5. ❌ **Sistema inutilizzabile**: Impossibile verificare lo stato

### Sintomi Visibili

```
✅ Dipendente timbra → Success dal server
❌ Ma stato rimane OUT
❌ Lista "Ultime Timbrature" vuota
❌ Admin tab "Chi è Timbrato" = 0
❌ Admin tab "Presenze Oggi" = 0
```

---

## 🧪 VERIFICA DEL FIX

### Test Case 1: Coordinate 0,0
```dart
// Dati dal server
{
  "latitude": 0,        // int
  "longitude": 0        // int
}

// ❌ PRIMA: CRASH!
latitude: map['latitude']  // type 'int' is not a subtype of type 'double'

// ✅ DOPO: OK!
latitude: (map['latitude'] as num).toDouble()  // 0.0 (double)
```

### Test Case 2: Coordinate Reali
```dart
// Dati dal server
{
  "latitude": 45.123456,   // double
  "longitude": 9.654321    // double
}

// ✅ PRIMA: OK (quando era double)
latitude: map['latitude']  // 45.123456

// ✅ DOPO: OK (sempre)
latitude: (map['latitude'] as num).toDouble()  // 45.123456
```

### Test Case 3: Mix
```dart
// Dati dal server (scenario reale)
{
  "latitude": 45,       // int (valore "tondo")
  "longitude": 9.5      // double
}

// ❌ PRIMA: CRASH su latitude!
latitude: map['latitude']  // CRASH!

// ✅ DOPO: OK per entrambi!
latitude: (map['latitude'] as num).toDouble()    // 45.0
longitude: (map['longitude'] as num).toDouble()  // 9.5
```

---

## 🔍 DEBUGGING FUTURE

### Come Riconoscere Questo Tipo di Errore

**Sintomo**: Exception `type 'X' is not a subtype of type 'Y'`

**Dove guardare**:
1. Modelli con `fromMap()` o `fromJson()`
2. Campi numerici (int/double confusion)
3. Dati provenienti da JSON/Database

**Come evitarlo**:
```dart
// ❌ MAI fare cast implicito per numeri
someDouble: map['value']

// ✅ SEMPRE convertire esplicitamente
someDouble: (map['value'] as num).toDouble()
someInt: (map['value'] as num).toInt()
```

---

## 📁 FILE MODIFICATI

### 1. `lib/models/attendance_record.dart`
```diff
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      // ... altri campi ...
-     latitude: map['latitude'],
-     longitude: map['longitude'],
+     latitude: (map['latitude'] as num).toDouble(),
+     longitude: (map['longitude'] as num).toDouble(),
    );
  }
```

### 2. `lib/models/work_site.dart`
```diff
  factory WorkSite.fromMap(Map<String, dynamic> map) {
    return WorkSite(
      // ... altri campi ...
-     latitude: map['latitude'],
-     longitude: map['longitude'],
-     radiusMeters: map['radiusMeters']?.toDouble() ?? 100.0,
+     latitude: (map['latitude'] as num).toDouble(),
+     longitude: (map['longitude'] as num).toDouble(),
+     radiusMeters: map['radiusMeters'] != null 
+         ? (map['radiusMeters'] as num).toDouble() 
+         : 100.0,
    );
  }
```

---

## ✅ STATO FINALE

### Tutti i Problemi Risolti

1. ✅ **Type casting corretto** - num → double
2. ✅ **Record caricati correttamente** - Nessuna exception
3. ✅ **Stato timbratura corretto** - Basato su record reali
4. ✅ **UI aggiornata** - Liste popolate correttamente
5. ✅ **Admin funzionante** - Tutte le tab mostrano dati corretti

### Flow Completo Ora Funziona

```
1. Dipendente timbra IN
   ↓
2. Server salva record (latitude: 0, longitude: 0)
   ↓
3. Client richiede records
   ↓
4. Server risponde con JSON (latitude: 0 come int)
   ↓
5. ✅ fromMap() converte: (0 as num).toDouble() = 0.0
   ↓
6. ✅ AttendanceRecord creato correttamente
   ↓
7. ✅ _isClockedIn = true (record.type == 'in')
   ↓
8. ✅ UI mostra "TIMBRATO IN"
   ↓
9. ✅ Admin vede dipendente nella lista
```

---

## 🎯 CONCLUSIONE

Il problema non era nella logica di business ma in un **type mismatch** tra SQLite/JSON e Dart. 

SQLite può restituire numeri come `int` anche quando richiesti come `REAL`, e JSON preserva questo tipo. Dart richiede conversioni esplicite tra `int` e `double`.

La soluzione è semplice ma fondamentale: **sempre convertire esplicitamente i valori numerici da JSON/Map usando `(value as num).toDouble()`**.

Con questo fix, il sistema è completamente funzionante! ✅

---

## 📝 BEST PRACTICES

### Per Sviluppatori Flutter

```dart
// ✅ SEMPRE per campi double da JSON
double myValue = (map['value'] as num).toDouble();

// ✅ SEMPRE per campi int da JSON (se possibile double nel JSON)
int myValue = (map['value'] as num).toInt();

// ✅ Con null safety
double? myValue = map['value'] != null 
    ? (map['value'] as num).toDouble() 
    : null;

// ❌ MAI fare cast implicito
double myValue = map['value'];  // RISCHIO CRASH!
```

### Per Backend (Node.js + SQLite)

```javascript
// ⚠️ CAST AS REAL non garantisce il tipo in JSON
// Il tipo dipende dal valore effettivo

// ✅ MEGLIO: Assicurati che i valori siano sempre float
// Quando inserisci:
latitude: parseFloat(latitude),
longitude: parseFloat(longitude)

// ✅ O gestisci la conversione nel client (come fatto)
```
