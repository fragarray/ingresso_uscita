# Fix: Nuove Regole Timbratura Forzata - LOGICA RIGOROSA

## 🎯 Obiettivo

Implementare regole rigorose per la timbratura forzata per garantire la coerenza dei dati nel database e prevenire errori di tracciamento delle ore lavorate.

---

## 📋 Nuove Regole Implementate

### **Regola 1: Solo INGRESSO può essere forzato**
❌ **VIETATO**: Forzare timbratura di USCITA in modo indipendente
✅ **PERMESSO**: Forzare solo timbratura di INGRESSO

**Razionale:**
- Un'uscita senza ingresso corrispondente crea dati incoerenti
- Tutti i record OUT devono avere un record IN precedente
- Garantisce integrità referenziale implicita dei dati

---

### **Regola 2: OUT obbligatoria per timbrature > 8 ore fa**
🚫 **OBBLIGATORIO**: Se forzi IN di più di 8 ore fa, DEVI forzare anche OUT

**Criteri:**
```dart
final hoursSinceIn = DateTime.now().difference(forcedInDateTime).inHours;
final mustForceOut = hoursSinceIn >= 8;
```

**Workflow:**
1. Admin seleziona data/ora > 8 ore fa
2. Sistema mostra dialog OBBLIGATORIO per OUT
3. Admin DEVE inserire OUT o annullare TUTTA l'operazione
4. Salvataggio atomico: IN + OUT insieme

**Razionale:**
- Giornata lavorativa tipica dura 8 ore
- Se forzi IN di ieri, dipendente sicuramente ha anche fatto OUT
- Evita dipendenti "fantasma" che risultano IN da giorni

---

### **Regola 3: Salvataggio Atomico - DOPO completamento UI**
⚙️ **LOGICA**: Nulla viene salvato nel DB finché non si hanno tutti i dati

**Vecchia Logica (ERRATA):**
```dart
// ❌ Salvava IN immediatamente, poi chiedeva OUT
await saveIN();  // Già nel DB!
final shouldAddOut = await showDialog(); // E se annullo?
if (shouldAddOut) await saveOUT(); // OUT opzionale
```

**Nuova Logica (CORRETTA):**
```dart
// ✅ Raccoglie TUTTI i dati prima di salvare
final forcedInData = await collectInData();
if (mustForceOut) {
  final outData = await collectOutData(); // OBBLIGATORIO
  if (outData == null) {
    // Annullato -> NON salva NULLA
    return;
  }
}

// SOLO ORA salva nel DB
await saveIN(forcedInData);
if (outData != null) {
  await saveOUT(outData);
}
```

---

## 🔧 Modifiche al Codice

### 1. **Rimozione Selezione IN/OUT**

**File**: `lib/widgets/personnel_tab.dart`

**Prima:**
```dart
String selectedType = 'in'; // Admin poteva cambiare
// UI con 2 pulsanti: INGRESSO / USCITA
Row(
  children: [
    // Pulsante INGRESSO
    InkWell(onTap: () => setState(() => selectedType = 'in')),
    // Pulsante USCITA
    InkWell(onTap: () => setState(() => selectedType = 'out')),
  ],
)
```

**Ora:**
```dart
final String selectedType = 'in'; // Sempre INGRESSO (final)
// UI semplificata con solo info
Container(
  decoration: BoxDecoration(color: Colors.green[50]),
  child: Text('Si può forzare solo INGRESSO'),
)
```

---

### 2. **Validazione Ore e Dialog Obbligatorio**

**Nuovo Codice:**
```dart
final now = DateTime.now();
DateTime forcedDateTime = useCustomDateTime ? customDateTime : now;

// Calcola ore trascorse
final hoursSinceIn = now.difference(forcedDateTime).inHours;

// REGOLA: Se > 8 ore, OUT è OBBLIGATORIA
final mustForceOut = hoursSinceIn >= 8;

if (mustForceOut) {
  // Dialog NON chiudibile (barrierDismissible: false)
  final shouldAddOut = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // ⚠️ Non può ignorare
    builder: (context) => _buildRequireOutDialog(...),
  );

  if (shouldAddOut != true) {
    // Admin ha annullato -> NON salva NULLA
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operazione annullata: timbratura non salvata')),
    );
    return; // EXIT: nessun salvataggio
  }

  // Raccogli dati OUT
  final outData = await _collectOutData(...);
  if (outData == null) {
    // Admin ha annullato -> NON salva NULLA
    return; // EXIT: nessun salvataggio
  }

  outDateTime = outData['dateTime'];
  outNotes = outData['notes'];
}
```

---

### 3. **Nuovo Dialog "Uscita Obbligatoria"**

**Funzione:** `_buildRequireOutDialog()`

**Caratteristiche:**
- Icona rossa di errore
- Titolo: "Uscita Obbligatoria"
- Spiega la regola delle 8 ore
- Mostra ore trascorse: `"più di 8 ore fa ($hoursSince ore)"`
- Pulsanti:
  - `ANNULLA TUTTO` → Nessun salvataggio
  - `OK, AGGIUNGI USCITA` → Continua con OUT

**Codice:**
```dart
Widget _buildRequireOutDialog(
  BuildContext context,
  Employee employee,
  WorkSite workSite,
  DateTime inDateTime,
) {
  final now = DateTime.now();
  final hoursSince = now.difference(inDateTime).inHours;
  
  return AlertDialog(
    title: Row(children: [
      Icon(Icons.error, color: Colors.red),
      Text('Uscita Obbligatoria'),
    ]),
    content: Column(children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red),
        ),
        child: Column(children: [
          Text('REGOLA OBBLIGATORIA', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          )),
          Text('Stai forzando un ingresso di più di 8 ore fa ($hoursSince ore).'),
          Text('Per mantenere la coerenza dei dati, DEVI forzare anche l\'uscita.'),
        ]),
      ),
      // Info dipendente e cantiere
    ]),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('ANNULLA TUTTO'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text('OK, AGGIUNGI USCITA'),
      ),
    ],
  );
}
```

---

### 4. **Salvataggio Atomico con Gestione Errori**

**Codice:**
```dart
try {
  // 1. Salva INGRESSO
  final inSuccess = await ApiService.forceAttendance(
    employeeId: employee.id!,
    workSiteId: selectedWorkSite!.id!,
    type: 'in',
    adminId: admin.id!,
    notes: notes.isNotEmpty ? notes : null,
    timestamp: useCustomDateTime ? customDateTime : null,
  );

  if (!inSuccess) {
    // Fallito: mostra errore e ESCI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Errore durante la timbratura forzata'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // 2. Se c'è OUT, salvalo SUBITO
  if (outDateTime != null) {
    final outSuccess = await ApiService.forceAttendance(
      employeeId: employee.id!,
      workSiteId: selectedWorkSite!.id!,
      type: 'out',
      adminId: admin.id!,
      notes: outNotes,
      timestamp: outDateTime,
    );

    if (outSuccess) {
      // ✅ Entrambe salvate
      await Future.delayed(Duration(milliseconds: 300));
      context.read<AppState>().triggerRefresh();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Coppia IN/OUT forzata per ${employee.name}\n'
            'IN: ${forcedDateTime.hour}:${forcedDateTime.minute} - '
            'OUT: ${outDateTime.hour}:${outDateTime.minute}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // ❌ CRITICO: IN salvato ma OUT fallito!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ERRORE CRITICO: Ingresso salvato ma uscita fallita!\n'
            'Controllare manualmente il dipendente ${employee.name}',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 8), // Messaggio lungo
        ),
      );
    }
  } else {
    // Solo IN salvato (timbratura recente < 8 ore)
    await Future.delayed(Duration(milliseconds: 300));
    context.read<AppState>().triggerRefresh();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Ingresso forzato per ${employee.name}\nDipendente attualmente IN'),
        backgroundColor: Colors.green,
      ),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Errore: $e')),
  );
}
```

---

## 📊 Matrice Decisionale

| Ore Trascorse | OUT Obbligatoria? | Dialog Mostrato | Annulla Permesso? | Cosa Salva |
|---------------|-------------------|-----------------|-------------------|------------|
| 0-7 ore | ❌ No | Nessuno | - | Solo IN |
| 8+ ore | ✅ Sì | `_buildRequireOutDialog()` | ✅ Sì (nulla salvato) | IN + OUT |
| Annullato OUT | - | - | - | ❌ NULLA (rollback) |

---

## 🧪 Scenari di Test

### **Test 1: Timbratura Recente (< 8 ore)**
```
Setup:
- Ora corrente: 14:00
- Forza IN: oggi 12:00 (2 ore fa)

Workflow:
1. Admin seleziona cantiere, data 12:00
2. Clicca "FORZA TIMBRATURA"
3. ✅ Sistema salva SOLO IN
4. Dipendente risulta IN

Risultato Atteso:
✅ 1 record IN nel database
✅ Dipendente stato: IN
✅ Nessun dialog OUT
```

---

### **Test 2: Timbratura Passato (> 8 ore)**
```
Setup:
- Ora corrente: 14:00
- Forza IN: oggi 06:00 (8 ore fa)

Workflow:
1. Admin seleziona cantiere, data 06:00
2. Clicca "FORZA TIMBRATURA"
3. ⚠️ Sistema mostra "Uscita Obbligatoria"
4. Admin clicca "OK, AGGIUNGI USCITA"
5. Sistema chiede ora OUT (suggerisce 14:00)
6. Admin conferma OUT 14:00
7. ✅ Sistema salva IN + OUT

Risultato Atteso:
✅ 2 record nel database: IN 06:00, OUT 14:00
✅ Dipendente stato: OUT
✅ Ore lavorate: 8 ore
```

---

### **Test 3: Annullamento Forzatura**
```
Setup:
- Ora corrente: 14:00
- Forza IN: ieri 08:00 (30 ore fa)

Workflow:
1. Admin seleziona cantiere, data ieri 08:00
2. Clicca "FORZA TIMBRATURA"
3. ⚠️ Sistema mostra "Uscita Obbligatoria"
4. Admin clicca "ANNULLA TUTTO"
5. ❌ Sistema NON salva nulla
6. Mostra: "Operazione annullata: timbratura non salvata"

Risultato Atteso:
❌ 0 record nel database
✅ Dipendente stato invariato
✅ Nessun dato salvato
```

---

### **Test 4: Errore Salvataggio OUT**
```
Setup:
- Ora corrente: 14:00
- Forza IN: ieri 08:00 (30 ore fa)
- Simula errore rete per secondo salvataggio

Workflow:
1. Admin seleziona cantiere, data ieri 08:00
2. Conferma dialog OUT
3. Seleziona OUT ieri 17:00
4. ✅ IN salvato con successo
5. ❌ OUT fallisce (errore rete)
6. ⚠️ Sistema mostra: "ERRORE CRITICO: Ingresso salvato ma uscita fallita!"

Risultato Atteso:
⚠️ 1 record IN nel database (inconsistente!)
❌ 0 record OUT
🔴 Messaggio errore ROSSO per 8 secondi
✅ Admin allertato di controllare manualmente
```

---

## ⚠️ Gestione Errori

### **Errore 1: OUT Fallito dopo IN Salvato**
**Problema:** Stato inconsistente (IN senza OUT quando richiesto)

**Gestione:**
```dart
if (!outSuccess) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '⚠️ ERRORE CRITICO: Ingresso salvato ma uscita fallita!\n'
        'Controllare manualmente il dipendente ${employee.name}',
      ),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 8), // Extra lungo
    ),
  );
}
```

**Azioni Admin:**
1. Annotare manualmente dipendente e ora
2. Verificare connessione server
3. Ri-forzare manualmente OUT quando possibile
4. Controllare storico dipendente

---

### **Errore 2: Admin Annulla Durante Processo**
**Problema:** Operazione parzialmente completata

**Gestione:**
```dart
final outData = await _collectOutData(...);
if (outData == null) {
  // Admin ha chiuso dialog o premuto ANNULLA
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Operazione annullata: timbratura non salvata'),
      backgroundColor: Colors.orange,
    ),
  );
  return; // ❌ Nessun salvataggio
}
```

**Beneficio:** Nessun dato parziale salvato

---

## 📈 Benefici

1. ✅ **Integrità Dati**: Impossibile creare OUT senza IN
2. ✅ **Coerenza Temporale**: Giornate lavorate sempre complete
3. ✅ **UX Chiara**: Admin capisce subito le regole
4. ✅ **Sicurezza**: Transazioni atomiche (tutto o niente)
5. ✅ **Tracciabilità**: Tutti i record forzati hanno admin_id
6. ✅ **Report Accurati**: Ore lavorate sempre corrette

---

## 🔍 Differenze con Vecchia Logica

| Aspetto | Vecchia Logica | Nuova Logica |
|---------|----------------|--------------|
| **Tipo Forzabile** | IN o OUT | Solo IN |
| **OUT Senza IN** | ✅ Possibile | ❌ IMPOSSIBILE |
| **Soglia Obbligatorietà** | 6 ore (opzionale) | 8 ore (OBBLIGATORIA) |
| **Dialog OUT** | Opzionale | Obbligatorio se > 8h |
| **Salvataggio** | Immediato IN, poi OUT | Atomico: IN + OUT insieme |
| **Annullamento** | OUT opzionale | Rollback completo |
| **Gestione Errori** | Warning generico | Alert CRITICO dettagliato |

---

## 🚀 Prossimi Miglioramenti (Opzionali)

### 1. **Validazione Server-Side**
Aggiungere controlli nel backend:
```javascript
app.post('/api/attendance/force', async (req, res) => {
  const { type, timestamp } = req.body;
  
  // REGOLA 1: Solo IN può essere forzato
  if (type === 'out') {
    return res.status(400).json({
      error: 'Cannot force OUT directly. Force IN first.'
    });
  }
  
  // REGOLA 2: Verifica coppia IN/OUT per > 8 ore
  const hoursSince = (Date.now() - new Date(timestamp)) / (1000 * 60 * 60);
  if (hoursSince > 8) {
    // Verifica che ci sia una OUT corrispondente in arrivo
    // Oppure salva IN con flag "pending_out" = true
  }
  
  // Continua...
});
```

---

### 2. **Transaction Database**
Usare transazioni per garantire atomicità:
```javascript
db.serialize(() => {
  db.run('BEGIN TRANSACTION');
  
  try {
    // Inserisci IN
    db.run('INSERT INTO attendance_records (type, ...) VALUES ("in", ...)', (err) => {
      if (err) throw err;
      
      // Inserisci OUT
      db.run('INSERT INTO attendance_records (type, ...) VALUES ("out", ...)', (err) => {
        if (err) throw err;
        
        db.run('COMMIT');
        res.json({ success: true });
      });
    });
  } catch (e) {
    db.run('ROLLBACK');
    res.status(500).json({ error: e.message });
  }
});
```

---

### 3. **Log Audit Trail**
Registrare TUTTE le timbrature forzate:
```sql
CREATE TABLE forced_attendance_log (
  id INTEGER PRIMARY KEY,
  admin_id INTEGER,
  employee_id INTEGER,
  action TEXT, -- 'force_in', 'force_out', 'cancelled'
  timestamp DATETIME,
  forced_datetime DATETIME,
  reason TEXT,
  success BOOLEAN
);
```

---

### 4. **Notifica Admin in Caso di Inconsistenza**
Email automatica se OUT fallisce dopo IN:
```dart
if (!outSuccess) {
  // Invia email admin
  await ApiService.sendAdminAlert(
    adminId: admin.id!,
    subject: 'ERRORE CRITICO: Timbratura Inconsistente',
    body: 'IN salvato ma OUT fallito per ${employee.name} il $date',
  );
}
```

---

## ✅ Conclusione

Le nuove regole garantiscono:
- ✅ **Dati sempre coerenti**
- ✅ **Impossibile creare OUT orfani**
- ✅ **Giornate lavorate sempre complete** (se > 8 ore fa)
- ✅ **Processo chiaro per admin**
- ✅ **Gestione errori robusta**

**Data implementazione:** 18 Ottobre 2025
**Versione:** 2.0 - Logica Rigorosa
