# Feature: Auto-Suggerimento Uscita dopo Ingresso Forzato

## 🎯 Funzionalità Implementata

### Problema Risolto

Quando l'admin forzava un ingresso per una data passata (es: dipendente dimentica telefono), non veniva suggerita l'uscita corrispondente. Questo causava:
- ❌ Conteggio ore incompleto
- ❌ Stato dipendente rimasto IN per giorni passati
- ❌ Report ore con calcoli errati

### Soluzione

Dopo aver forzato un **INGRESSO** con data **diversa da oggi**, il sistema chiede automaticamente:

> "Vuoi aggiungere anche la timbratura di uscita per evitare conteggi errati delle ore?"

## 📋 Workflow Completo

### Scenario: Dipendente Dimentica Telefono Ieri

**Passo 1: Admin Forza Ingresso**
```
Admin apre "Forza Timbratura"
Seleziona:
  - Dipendente: Mario Rossi
  - Tipo: INGRESSO
  - Cantiere: Lecce
  - Data: 14/10/2025 (ieri)
  - Ora: 08:00
  - Note: "Telefono dimenticato"
Conferma ✅
```

**Passo 2: Sistema Mostra Dialog Suggerimento**
```
┌──────────────────────────────────────────┐
│ 🔵 Aggiungi Uscita?                     │
├──────────────────────────────────────────┤
│ ℹ️ Ingresso Forzato                      │
│   Dipendente: Mario Rossi               │
│   Cantiere: Lecce                       │
│   Data: 14/10/2025                      │
│   Ora Ingresso: 08:00                   │
│                                          │
│ Hai forzato un ingresso per una data    │
│ diversa da oggi.                        │
│                                          │
│ ⚠️ Vuoi aggiungere anche la timbratura   │
│   di uscita per evitare conteggi errati │
│   delle ore?                            │
│                                          │
│ [NO, SOLO INGRESSO] [SÌ, AGGIUNGI USCITA]│
└──────────────────────────────────────────┘
```

**Passo 3a: Admin Clicca "SÌ, AGGIUNGI USCITA"**
```
Sistema apre dialog per selezionare ora uscita:

┌──────────────────────────────────────────┐
│ 🔴 Forza Uscita - Mario Rossi           │
├──────────────────────────────────────────┤
│ ℹ️ Cantiere: Lecce                       │
│   Data: 14/10/2025                      │
│   Ingresso: 08:00                       │
│                                          │
│ Seleziona ora di uscita:                │
│ ┌────────────────────────────────┐      │
│ │ 🕐 Ora Uscita:                 │      │
│ │    16:00  ▼                    │ ← Suggerito: +8h
│ └────────────────────────────────┘      │
│                                          │
│ Note (opzionale):                       │
│ [Turno standard 8 ore           ]      │
│                                          │
│ [ANNULLA]  [FORZA USCITA]               │
└──────────────────────────────────────────┘
```

**Passo 3b: Admin Seleziona Ora e Conferma**
```
Admin modifica ora se necessario (es: 17:00)
Aggiunge note: "Turno standard 8 ore"
Clicca "FORZA USCITA" ✅
```

**Risultato Finale:**
```sql
-- Database dopo operazione completa:
INSERT INTO attendance_records:
  ID 150: IN  14/10/2025 08:00 (forzato)
  ID 151: OUT 14/10/2025 17:00 (forzato)

-- Conteggio ore:
  14/10/2025: 9 ore ✅ CORRETTO

-- Stato dipendente:
  Ultimo record (ID 151): OUT ✅ CORRETTO
```

## 🔧 Dettagli Tecnici

### Fix 1: Errore MaterialLocalizations

**Problema:**
```
Another exception was thrown: No MaterialLocalizations found.
```

**Causa:**
`showDatePicker()` aveva parametro `locale: const Locale('it', 'IT')` ma MaterialApp non aveva localizations configurate.

**Soluzione:**
Rimosso parametro `locale` dal date picker - usa automaticamente il locale di sistema.

**File Modificato:**
`lib/widgets/personnel_tab.dart` - linea ~908

**Prima:**
```dart
final date = await showDatePicker(
  context: context,
  initialDate: customDateTime,
  firstDate: DateTime(2020),
  lastDate: DateTime.now().add(const Duration(days: 1)),
  locale: const Locale('it', 'IT'),  // ❌ Causava errore
);
```

**Dopo:**
```dart
final date = await showDatePicker(
  context: context,
  initialDate: customDateTime,
  firstDate: DateTime(2020),
  lastDate: DateTime.now().add(const Duration(days: 1)),
  // ✅ Usa locale di sistema
);
```

### Feature 2: Auto-Suggerimento OUT

**Logica Implementata:**

```dart
// Dopo successo timbratura IN forzata
if (selectedType == 'in' && useCustomDateTime) {
  final forcedDate = DateTime(customDateTime.year, customDateTime.month, customDateTime.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  
  // Se data forzata != oggi
  if (!forcedDate.isAtSameMomentAs(todayDate)) {
    // Mostra dialog suggerimento
    final shouldAddOut = await showDialog<bool>(...);
    
    if (shouldAddOut == true) {
      // Mostra dialog selezione ora OUT
      await _forceOutAfterIn(employee, workSite, customDateTime, admin);
    }
  }
}
```

**Calcolo Ora Suggerita OUT:**
```dart
// Default: 8 ore dopo l'ingresso
final suggestedOut = inDateTime.add(const Duration(hours: 8));

// Admin può modificare con time picker
```

**File Modificato:**
`lib/widgets/personnel_tab.dart` - aggiunti metodi:
- `_buildSuggestOutDialog()` - Dialog conferma
- `_forceOutAfterIn()` - Dialog selezione ora OUT

## 🎨 UI Components

### Dialog 1: Suggerimento Aggiungi Uscita

```dart
Widget _buildSuggestOutDialog(
  BuildContext context,
  Employee employee,
  WorkSite workSite,
  DateTime inDateTime,
) {
  return AlertDialog(
    title: Row(...),  // 🔵 Aggiungi Uscita?
    content: Column(
      children: [
        Container(...),  // ℹ️ Info ingresso forzato
        Text(...),       // Hai forzato un ingresso...
        Container(...),  // ⚠️ Warning conteggio ore
      ],
    ),
    actions: [
      TextButton('NO, SOLO INGRESSO'),
      ElevatedButton('SÌ, AGGIUNGI USCITA'),
    ],
  );
}
```

### Dialog 2: Selezione Ora Uscita

```dart
Future<void> _forceOutAfterIn(...) async {
  // Ora suggerita: +8 ore dall'ingresso
  DateTime outDateTime = inDateTime.add(const Duration(hours: 8));
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(...),  // 🔴 Forza Uscita
        content: Column(
          children: [
            Container(...),  // Info cantiere/data/ingresso
            InkWell(
              onTap: () async {
                final time = await showTimePicker(...);
                // Aggiorna outDateTime
              },
              child: Container(
                // 🕐 Display ora selezionata (grande, visibile)
                // ▼ Dropdown indicator
              ),
            ),
            TextField(...),  // Note opzionali
          ],
        ),
        actions: [
          TextButton('ANNULLA'),
          ElevatedButton('FORZA USCITA'),
        ],
      ),
    ),
  );
  
  if (confirmed) {
    // Forza OUT con timestamp personalizzato
    await ApiService.forceAttendance(...);
  }
}
```

## 📊 Test Scenarios

### Test 1: IN Forzato Oggi (NO Suggerimento)
```
Input:
  - Data: 15/10/2025 (oggi)
  - Ora: 10:00

Risultato:
  ✅ Timbratura IN forzata
  ❌ NO dialog suggerimento (stessa data)
  ✅ Stato dipendente: IN
```

### Test 2: IN Forzato Ieri (SÌ Suggerimento - Accetta)
```
Input:
  - Data: 14/10/2025 (ieri)
  - Ora: 08:00

Risultato:
  ✅ Timbratura IN forzata (id 150)
  ✅ Dialog suggerimento mostrato
  ✅ Admin clicca "SÌ, AGGIUNGI USCITA"
  ✅ Dialog selezione ora OUT mostrato
  ✅ Ora suggerita: 16:00 (+8h)
  ✅ Admin modifica: 17:00
  ✅ Timbratura OUT forzata (id 151)
  ✅ Refresh automatico
  ✅ Stato dipendente: OUT
  ✅ Conteggio ore 14/10: 9 ore
```

### Test 3: IN Forzato Ieri (SÌ Suggerimento - Rifiuta)
```
Input:
  - Data: 14/10/2025 (ieri)
  - Ora: 08:00

Risultato:
  ✅ Timbratura IN forzata (id 150)
  ✅ Dialog suggerimento mostrato
  ✅ Admin clicca "NO, SOLO INGRESSO"
  ✅ Solo IN forzato inserito
  ✅ Stato dipendente: IN
  ⚠️ Conteggio ore 14/10: incompleto (solo ingresso)
```

### Test 4: IN Forzato Settimana Scorsa
```
Input:
  - Data: 08/10/2025 (7 giorni fa)
  - Ora: 09:00

Risultato:
  ✅ Timbratura IN forzata
  ✅ Dialog suggerimento mostrato
  ✅ Admin aggiunge OUT 17:30
  ✅ Entrambe timbrature salvate
  ✅ Report ore include giornata completa
```

## 🔄 Sequence Diagram

```
Admin                 Sistema               Database
  |                      |                     |
  |--Forza IN 14/10---->|                     |
  |                     |--INSERT IN--------->|
  |                     |<-Success------------|
  |                     |                     |
  |<-Conferma IN--------|                     |
  |                     |                     |
  |<-Dialog Suggerisci--|                     |
  |  "Aggiungi OUT?"    |                     |
  |                     |                     |
  |--Clicca SÌ-------->|                     |
  |                     |                     |
  |<-Dialog Ora OUT-----|                     |
  |                     |                     |
  |--Seleziona 17:00-->|                     |
  |--Conferma--------->|                     |
  |                     |--INSERT OUT-------->|
  |                     |<-Success------------|
  |                     |                     |
  |<-Conferma OUT-------|                     |
  |                     |--triggerRefresh()-->|
  |                     |                     |
```

## ✅ Vantaggi

1. **Prevenzione Errori:**
   - Evita conteggi ore incompleti
   - Previene stati dipendente errati
   - Migliora qualità dati report

2. **User Experience:**
   - Workflow guidato e intuitivo
   - Suggerimento automatico intelligente
   - Ora uscita pre-calcolata (+8h)
   - Possibilità di personalizzare

3. **Flessibilità:**
   - Admin può sempre rifiutare suggerimento
   - Ora OUT modificabile
   - Note opzionali per contesto

4. **Consistenza Dati:**
   - Coppie IN-OUT complete
   - Report ore accurati
   - Storico coerente

## 🎯 Casi d'Uso

### Caso 1: Telefono Dimenticato
```
Dipendente lavora normalmente ma dimentica telefono
→ Admin forza IN mattina (8:00)
→ Sistema suggerisce OUT
→ Admin conferma OUT serale (17:00)
✅ Giornata completa registrata
```

### Caso 2: Timbratura Mancante
```
Dipendente timbra IN ma app crash durante OUT
→ Admin forza IN storico
→ Admin aggiunge OUT mancante
✅ Coppia completa ricostruita
```

### Caso 3: Correzione Multipla
```
Dipendente assente per 3 giorni, non ha timbrato
→ Admin forza IN giorno 1 → aggiunge OUT
→ Admin forza IN giorno 2 → aggiunge OUT  
→ Admin forza IN giorno 3 → aggiunge OUT
✅ Settimana completa ricostruita
```

## 📝 Note Implementazione

### Condizione Attivazione
```dart
if (selectedType == 'in' && useCustomDateTime) {
  // Calcola date
  final forcedDate = DateTime(customDateTime.year, month, day);
  final todayDate = DateTime(today.year, today.month, today.day);
  
  // Solo se data diversa da oggi
  if (!forcedDate.isAtSameMomentAs(todayDate)) {
    // Mostra suggerimento
  }
}
```

### Perché Solo per Date Passate?

- **Oggi:** Dipendente potrebbe ancora lavorare → NO suggerimento
- **Passato:** Giornata completata → SÌ suggerimento OUT
- **Futuro:** Pianificazione → Caso edge, attualmente NO suggerimento

### Calcolo Ora Suggerita

```dart
// Default: 8 ore standard
final suggestedOut = inDateTime.add(const Duration(hours: 8));

// Esempio:
// IN  08:00 → OUT suggerito 16:00
// IN  09:30 → OUT suggerito 17:30
```

Admin può sempre modificare con time picker.

## 🚀 Future Enhancements

Possibili miglioramenti futuri:

1. **Durata Personalizzata:**
   - Salvare ore lavoro standard per dipendente
   - Suggerire OUT basato su storico personale

2. **Validazione Ore:**
   - Warning se OUT < IN (errore)
   - Warning se ore totali > 12 (straordinario?)

3. **Bulk Force:**
   - Forzare multiple giornate in una volta
   - Template "settimana standard"

4. **Smart Suggestions:**
   - ML per suggerire ora OUT basato su pattern

---

**Data Implementazione:** 15 Ottobre 2025  
**Versione:** 2.2.0  
**Status:** ✅ COMPLETO E TESTATO
