# 📊 REPORT TIMBRATURE PROFESSIONALE - DOCUMENTAZIONE TECNICA

## 📋 Indice
1. [Panoramica](#panoramica)
2. [Architettura](#architettura)
3. [API Backend](#api-backend)
4. [Struttura Report Excel](#struttura-report-excel)
5. [Calcoli e Algoritmi](#calcoli-e-algoritmi)
6. [Formattazione Excel](#formattazione-excel)
7. [Testing](#testing)

---

## 🎯 Panoramica

### Scopo
Sistema completo per generare report Excel professionali delle timbrature con:
- **5 fogli Excel** organizzati per diversi livelli di analisi
- **Statistiche aggregate** (totali, medie, ranking)
- **Calcolo ore lavorate** per dipendente e cantiere
- **Top 3 dipendenti** evidenziati (gamification)
- **Formattazione professionale** pronta per clienti

### Miglioramenti rispetto al Vecchio Report

| Aspetto | Vecchio Report | Nuovo Report |
|---------|---------------|--------------|
| **Fogli** | 1 foglio piatto | 5 fogli strutturati |
| **Statistiche** | Nessuna | 6+ metriche aggregate |
| **Calcolo ore** | No | Sì (automatico) |
| **Ranking** | No | Top 3 con colori |
| **Analisi cantieri** | No | Foglio dedicato |
| **Presentazione** | Base | Professionale |

---

## 🏗️ Architettura

### Componenti

```
┌─────────────────────────────────────────────┐
│           Frontend (Flutter)                │
│  lib/widgets/reports_tab.dart               │
│  - _generateReport()                        │
│  - Filtri: dipendente, cantiere, periodo    │
└──────────────────┬──────────────────────────┘
                   │ HTTP GET
                   ↓
┌─────────────────────────────────────────────┐
│       Backend API (Node.js/Express)         │
│  GET /api/attendance/report                 │
│  - Params: employeeId, workSiteId, dates    │
└──────────────────┬──────────────────────────┘
                   │ Chiama
                   ↓
┌─────────────────────────────────────────────┐
│    generateAttendanceReport(filters)        │
│  server/server.js                           │
│  - Query SQL con filtri                     │
│  - Calcolo statistiche                      │
│  - Calcolo ore (calculateWorkedHours)       │
│  - Generazione 5 fogli Excel                │
│  - Formattazione professionale              │
└──────────────────┬──────────────────────────┘
                   │ Ritorna
                   ↓
┌─────────────────────────────────────────────┐
│      File Excel (ExcelJS)                   │
│  server/reports/attendance_report_XXX.xlsx  │
│  - 5 Worksheets                             │
│  - Statistiche + Top 3 + Totali             │
└─────────────────────────────────────────────┘
```

### Flusso Dati

1. **Utente** → Seleziona filtri (opzionali: dipendente, cantiere, periodo)
2. **Frontend** → Chiama API `/api/attendance/report?params`
3. **Backend** → Query SQL con filtri
4. **Backend** → Calcola statistiche e ore lavorate
5. **Backend** → Genera 5 fogli Excel con ExcelJS
6. **Backend** → Salva file in `server/reports/`
7. **Backend** → Invia file in download
8. **Frontend** → Salva file in Documents/
9. **Frontend** → Apre file automaticamente

---

## 🔌 API Backend

### Endpoint Principale

```
GET /api/attendance/report
```

#### Parametri Query (tutti opzionali)

| Parametro | Tipo | Descrizione | Esempio |
|-----------|------|-------------|---------|
| `employeeId` | Integer | Filtra per singolo dipendente | `?employeeId=5` |
| `workSiteId` | Integer | Filtra per singolo cantiere | `?workSiteId=3` |
| `startDate` | ISO 8601 | Data inizio periodo | `?startDate=2025-10-01T00:00:00.000Z` |
| `endDate` | ISO 8601 | Data fine periodo | `?endDate=2025-10-15T23:59:59.999Z` |
| `includeInactive` | Boolean | Include dipendenti inattivi | `?includeInactive=true` |

#### Esempi Richieste

**1. Report Completo (tutte le timbrature)**
```http
GET /api/attendance/report
```

**2. Report Singolo Dipendente**
```http
GET /api/attendance/report?employeeId=12
```

**3. Report Singolo Cantiere**
```http
GET /api/attendance/report?workSiteId=5
```

**4. Report Periodo Specifico**
```http
GET /api/attendance/report?startDate=2025-10-01T00:00:00.000Z&endDate=2025-10-15T23:59:59.999Z
```

**5. Report Combinato (Dipendente + Cantiere + Periodo)**
```http
GET /api/attendance/report?employeeId=12&workSiteId=5&startDate=2025-10-01T00:00:00.000Z&endDate=2025-10-15T23:59:59.999Z
```

#### Risposta

**Success (200 OK)**
```http
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="attendance_report_1697385600000.xlsx"

[Binary Excel File]
```

**Error (500 Internal Server Error)**
```json
{
  "error": "Nessuna timbratura trovata per i filtri selezionati"
}
```

---

## 📑 Struttura Report Excel

### Foglio 1: Riepilogo Generale

**Scopo**: Vista d'insieme con statistiche aggregate e ore per dipendente

**Struttura**:
```
┌────────────────────────────────────────────────────┐
│         REPORT GENERALE TIMBRATURE                 │
│   Periodo: 01/10/2025 - 15/10/2025                │
├────────────────────────────────────────────────────┤
│ STATISTICHE GENERALI                               │
│                                                    │
│ 📊 Totale Timbrature          │ 156              │
│ ✅ Ingressi (IN)              │ 78               │
│ ❌ Uscite (OUT)               │ 78               │
│ 👥 Dipendenti Coinvolti       │ 12               │
│ 🏗️ Cantieri Coinvolti         │ 4                │
│ 📅 Giorni con Timbrature      │ 15               │
├────────────────────────────────────────────────────┤
│ ORE LAVORATE PER DIPENDENTE                        │
│                                                    │
│ Dipendente     │ Ore Totali │ Giorni │ Media/Gg  │
│ Mario Rossi    │ 120h 30m   │ 15     │ 8h 02m    │
│ Luigi Bianchi  │ 110h 15m   │ 14     │ 7h 52m    │
│ ...                                                │
│ TOTALE GENERALE│ 950h 45m   │        │           │
└────────────────────────────────────────────────────┘
```

**Colonne**:
- Dipendente (30 char)
- Ore Totali (formato "XXXh YYm")
- Giorni (numero giorni lavorati)
- Media Ore/Giorno (formato "XXh YYm")

**Statistiche Calcolate**:
- `totalRecords`: Conta totale timbrature
- `totalIn`: Conta ingressi
- `totalOut`: Conta uscite
- `uniqueEmployees`: Array dipendenti unici (no duplicati)
- `uniqueWorkSites`: Array cantieri unici
- `uniqueDates`: Array date uniche (giorni con timbrature)
- `minDate` / `maxDate`: Range periodo

---

### Foglio 2: Dettaglio Giornaliero

**Scopo**: Sessioni lavoro organizzate per giorno e dipendente

**Struttura**:
```
┌──────────────────────────────────────────────────────────────┐
│      DETTAGLIO GIORNALIERO SESSIONI LAVORO                   │
├──────────────────────────────────────────────────────────────┤
│ Data      │Dipendente  │Cantiere   │Ingresso│Uscita│Ore     │
│ 15/10/2025│Mario Rossi │Cantiere A │08:00   │12:30 │4h 30m  │
│ 15/10/2025│Mario Rossi │Cantiere B │13:30   │17:00 │3h 30m  │
│ 15/10/2025│Luigi B.    │Cantiere A │08:15   │12:00 │3h 45m  │
│           │            │           │        │Totale│11h 45m │
│ 14/10/2025│...                                               │
└──────────────────────────────────────────────────────────────┘
```

**Caratteristiche**:
- Ordinamento: Date decrescenti (più recente prima)
- Raggruppamento: Per data, poi per dipendente
- Totale giornaliero: Evidenziato con sfondo azzurro
- Righe vuote: Separano i giorni

**Calcolo Sessioni**:
Utilizza `calculateWorkedHours()` per:
1. Ordinare timbrature per timestamp
2. Accoppiare IN → OUT
3. Calcolare differenza oraria
4. Raggruppare per dipendente

---

### Foglio 3: Riepilogo Dipendenti

**Scopo**: Classifica dipendenti per ore lavorate con **Top 3 evidenziati**

**Struttura**:
```
┌──────────────────────────────────────────────────────────────┐
│   RIEPILOGO DIPENDENTI - CLASSIFICA ORE LAVORATE             │
├──────────────────────────────────────────────────────────────┤
│#│Dipendente     │Ore Totali│Giorni│Media/Gg│Cantieri        │
│1│🥇 Mario Rossi │120h 30m  │15    │8h 02m  │A, B, C         │ ← ORO
│2│🥈 Luigi B.    │110h 15m  │14    │7h 52m  │A, C            │ ← ARGENTO
│3│🥉 Paolo V.    │105h 00m  │15    │7h 00m  │B, D            │ ← BRONZO
│4│ Anna N.       │98h 45m   │13    │7h 35m  │A, B            │
│...                                                            │
└──────────────────────────────────────────────────────────────┘
```

**Colonne**:
- `#`: Posizione classifica (1, 2, 3, ...)
- `Dipendente`: Nome completo
- `Ore Totali`: Somma ore lavorate (formato "XXXh YYm")
- `Giorni`: Giorni lavorati (date uniche)
- `Media/Giorno`: Ore medie per giorno lavorato
- `Cantieri Visitati`: Lista cantieri (separati da virgola)

**Top 3 Evidenziazione**:
- **1° posto**: Sfondo oro (`#FFD700`) + testo bold
- **2° posto**: Sfondo argento (`#C0C0C0`) + testo bold
- **3° posto**: Sfondo bronzo (`#CD7F32`) + testo bold

**Ordinamento**:
```javascript
sortedEmployees.sort((a, b) => b.totalHours - a.totalHours);
```
Decrescente per ore totali.

---

### Foglio 4: Riepilogo Cantieri

**Scopo**: Statistiche per cantiere (dipendenti, giorni, ore)

**Struttura**:
```
┌───────────────────────────────────────────────────────────┐
│              RIEPILOGO CANTIERI                           │
├───────────────────────────────────────────────────────────┤
│ Cantiere    │Dip.Unici│Gg.Attività│Ore Totali│Timbrature │
│ Cantiere A  │ 8       │ 15        │ 450h 30m │ 120       │
│ Cantiere B  │ 6       │ 12        │ 320h 15m │ 96        │
│ Cantiere C  │ 4       │ 10        │ 180h 00m │ 80        │
│ Cantiere D  │ 2       │ 5         │ 50h 00m  │ 40        │
└───────────────────────────────────────────────────────────┘
```

**Colonne**:
- `Cantiere`: Nome cantiere
- `Dipendenti Unici`: Numero dipendenti univoci (no duplicati)
- `Giorni Attività`: Giorni con almeno 1 timbratura
- `Ore Totali`: Somma ore lavorate cantiere
- `Timbrature`: Conta totale timbrature

**Calcolo Dipendenti Unici**:
```javascript
const empList = [...new Set(wsRecords.map(r => r.employeeId))];
stat.uniqueEmployees = empList.length;
```

**Ordinamento**:
Decrescente per ore totali (cantieri più attivi primi).

---

### Foglio 5: Timbrature Complete

**Scopo**: Lista completa timbrature (dati raw) per verifica e audit

**Struttura**:
```
┌────────────────────────────────────────────────────────────┐
│            LISTA COMPLETA TIMBRATURE                       │
├────────────────────────────────────────────────────────────┤
│Dipendente │Cantiere  │Tipo    │Data e Ora        │Maps    │
│Mario Rossi│Cantiere A│Ingresso│15/10/25 08:00:32 │Apri... │
│Mario Rossi│Cantiere A│Uscita  │15/10/25 12:30:15 │Apri... │
│Luigi B.   │Cantiere B│Ingresso│15/10/25 08:15:10 │Apri... │
│...                                                         │
└────────────────────────────────────────────────────────────┘
```

**Colonne**:
- `Dipendente`: Nome dipendente
- `Cantiere`: Nome cantiere (o "Non specificato")
- `Tipo`: "Ingresso" (verde) o "Uscita" (rosso)
- `Data e Ora`: Timestamp formattato italiano
- `Dispositivo`: Info dispositivo (opzionale)
- `Google Maps`: Link cliccabile coordinate GPS

**Caratteristiche**:
- **Filtri automatici**: Excel autofilter attivo su tutte colonne
- **Link Google Maps**: Cliccabili, aprono browser
- **Colori tipo**: Verde (IN), Rosso (OUT)
- **Ordinamento**: Timestamp decrescente (più recente prima)

---

## 🧮 Calcoli e Algoritmi

### 1. Statistiche Generali

```javascript
const stats = {
  // Totale timbrature
  totalRecords: records.length,
  
  // Conta per tipo
  totalIn: records.filter(r => r.type === 'in').length,
  totalOut: records.filter(r => r.type === 'out').length,
  
  // Dipendenti unici (no duplicati)
  uniqueEmployees: [...new Set(records.map(r => r.employeeId))],
  
  // Cantieri unici (escludi null)
  uniqueWorkSites: [...new Set(
    records.map(r => r.workSiteId).filter(id => id !== null)
  )],
  
  // Date uniche (giorni con timbrature)
  uniqueDates: [...new Set(
    records.map(r => new Date(r.timestamp).toISOString().split('T')[0])
  )],
  
  // Range periodo
  minDate: new Date(Math.min(...records.map(r => new Date(r.timestamp)))),
  maxDate: new Date(Math.max(...records.map(r => new Date(r.timestamp))))
};
```

### 2. Calcolo Ore per Dipendente

```javascript
const employeeStats = {};

stats.uniqueEmployees.forEach(empId => {
  const empRecords = records.filter(r => r.employeeId === empId);
  const empName = empRecords[0].employeeName;
  
  // Usa calculateWorkedHours per calcolare ore
  const { workSessions } = calculateWorkedHours(empRecords);
  
  // Somma ore di tutti cantieri
  let totalHours = 0;
  Object.values(workSessions).forEach(hours => totalHours += hours);
  
  // Lista cantieri visitati
  const workSitesList = [...new Set(
    empRecords.map(r => r.workSiteName).filter(n => n)
  )];
  
  // Date lavorate
  const datesList = [...new Set(
    empRecords.map(r => new Date(r.timestamp).toISOString().split('T')[0])
  )];
  
  employeeStats[empId] = {
    name: empName,
    totalRecords: empRecords.length,
    totalHours: totalHours,
    workSites: workSitesList,
    daysWorked: datesList.length,
    firstRecord: new Date(Math.min(...empRecords.map(r => new Date(r.timestamp)))),
    lastRecord: new Date(Math.max(...empRecords.map(r => new Date(r.timestamp)))),
    avgHoursPerDay: datesList.length > 0 ? totalHours / datesList.length : 0
  };
});
```

### 3. Calcolo Statistiche Cantiere

```javascript
const workSiteStats = {};

stats.uniqueWorkSites.forEach(wsId => {
  const wsRecords = records.filter(r => r.workSiteId === wsId);
  const wsName = wsRecords[0]?.workSiteName || 'Non specificato';
  
  // Calcola ore
  const { workSessions } = calculateWorkedHours(wsRecords);
  let totalHours = 0;
  Object.values(workSessions).forEach(hours => totalHours += hours);
  
  // Dipendenti unici
  const empList = [...new Set(wsRecords.map(r => r.employeeId))];
  
  // Date uniche (giorni attività)
  const datesList = [...new Set(
    wsRecords.map(r => new Date(r.timestamp).toISOString().split('T')[0])
  )];
  
  workSiteStats[wsId] = {
    name: wsName,
    totalRecords: wsRecords.length,
    totalHours: totalHours,
    uniqueEmployees: empList.length,
    daysActive: datesList.length
  };
});
```

### 4. Ordinamento Top 3

```javascript
const sortedEmployees = Object.entries(employeeStats)
  .sort(([, a], [, b]) => b.totalHours - a.totalHours);

// Applica colori ai primi 3
sortedEmployees.forEach(([empId, stat], index) => {
  const row = sheet.addRow([...]);
  
  if (index === 0) {
    row.eachCell(cell => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFD700' } }; // Oro
      cell.font = { bold: true };
    });
  } else if (index === 1) {
    row.eachCell(cell => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC0C0C0' } }; // Argento
      cell.font = { bold: true };
    });
  } else if (index === 2) {
    row.eachCell(cell => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCD7F32' } }; // Bronzo
      cell.font = { bold: true };
    });
  }
});
```

### 5. Raggruppamento Giornaliero

```javascript
// Raggruppa timbrature per data
const recordsByDate = {};
records.forEach(rec => {
  const dateKey = new Date(rec.timestamp).toISOString().split('T')[0];
  if (!recordsByDate[dateKey]) recordsByDate[dateKey] = [];
  recordsByDate[dateKey].push(rec);
});

// Ordina date (più recente prima)
const sortedDates = Object.keys(recordsByDate).sort().reverse();

sortedDates.forEach(dateKey => {
  const dateRecords = recordsByDate[dateKey];
  
  // Calcola sessioni lavoro per questa data
  const { dailySessions } = calculateWorkedHours(dateRecords);
  
  let dailyTotal = 0;
  
  // Per ogni dipendente
  Object.entries(dailySessions).forEach(([employeeName, sessions]) => {
    sessions.forEach(session => {
      sheet.addRow([
        new Date(dateKey).toLocaleDateString('it-IT'),
        employeeName,
        session.workSite,
        new Date(session.timeIn).toLocaleTimeString('it-IT'),
        new Date(session.timeOut).toLocaleTimeString('it-IT'),
        formatHoursMinutes(session.hours).formatted
      ]);
      
      dailyTotal += session.hours;
    });
  });
  
  // Aggiungi totale giornaliero
  sheet.addRow(['', '', '', '', 'Totale Giorno:', formatHoursMinutes(dailyTotal).formatted]);
  sheet.addRow([]); // Riga vuota separatore
});
```

---

## 🎨 Formattazione Excel

### Stili Definiti

#### 1. Titolo Principale
```javascript
const titleStyle = {
  font: { bold: true, size: 16, color: { argb: 'FF1F4E78' } },
  alignment: { vertical: 'middle', horizontal: 'center' }
};
```
- Font: Bold, 16pt, Blu scuro
- Allineamento: Centrato
- Uso: Titoli fogli (riga 1)

#### 2. Header Tabelle
```javascript
const headerStyle = {
  font: { bold: true, color: { argb: 'FFFFFFFF' } },
  fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF4472C4' } },
  alignment: { vertical: 'middle', horizontal: 'center' },
  border: {
    top: { style: 'thin' },
    left: { style: 'thin' },
    bottom: { style: 'thin' },
    right: { style: 'thin' }
  }
};
```
- Font: Bold, Bianco
- Sfondo: Blu (`#4472C4`)
- Bordi: Sottili su tutti i lati
- Uso: Intestazioni colonne

#### 3. Celle Statistiche
```javascript
const statStyle = {
  font: { size: 11 },
  alignment: { vertical: 'middle', horizontal: 'left' },
  border: {
    top: { style: 'thin' },
    left: { style: 'thin' },
    bottom: { style: 'thin' },
    right: { style: 'thin' }
  }
};
```
- Font: 11pt, Normale
- Bordi: Sottili
- Uso: Righe statistiche generali

#### 4. Totali
```javascript
const totalStyle = {
  font: { bold: true, size: 12 },
  fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } },
  alignment: { vertical: 'middle', horizontal: 'left' },
  border: {
    top: { style: 'medium' },
    left: { style: 'thin' },
    bottom: { style: 'medium' },
    right: { style: 'thin' }
  }
};
```
- Font: Bold, 12pt
- Sfondo: Verde chiaro (`#E2EFDA`)
- Bordi: Superiore/inferiore spesso, lati sottili
- Uso: Righe totali generali

#### 5. Top 3 Dipendenti

**Oro (1° posto)**:
```javascript
cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFD700' } };
cell.font = { bold: true };
```
- Sfondo: Oro (`#FFD700`)
- Font: Bold

**Argento (2° posto)**:
```javascript
cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC0C0C0' } };
cell.font = { bold: true };
```
- Sfondo: Argento (`#C0C0C0`)
- Font: Bold

**Bronzo (3° posto)**:
```javascript
cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCD7F32' } };
cell.font = { bold: true };
```
- Sfondo: Bronzo (`#CD7F32`)
- Font: Bold

#### 6. Totale Giornaliero
```javascript
cell.font = { bold: true };
cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCE6F1' } };
```
- Sfondo: Azzurro chiaro (`#DCE6F1`)
- Font: Bold
- Uso: Totali giorni nel dettaglio giornaliero

#### 7. Colori Tipo Timbratura
```javascript
// Ingresso (IN)
cell.font = { bold: true, color: { argb: 'FF00B050' } };

// Uscita (OUT)
cell.font = { bold: true, color: { argb: 'FFE74C3C' } };
```
- IN: Verde (`#00B050`)
- OUT: Rosso (`#E74C3C`)

### Larghezze Colonne Standard

```javascript
// Foglio 1 - Riepilogo Generale
summarySheet.columns = [
  { key: 'label', width: 35 },
  { key: 'value', width: 20 }
];

// Foglio 2 - Dettaglio Giornaliero
dailySheet.columns = [
  { key: 'date', width: 15 },
  { key: 'employee', width: 25 },
  { key: 'worksite', width: 30 },
  { key: 'timeIn', width: 12 },
  { key: 'timeOut', width: 12 },
  { key: 'hours', width: 15 }
];

// Foglio 3 - Riepilogo Dipendenti
employeesSheet.columns = [
  { key: 'rank', width: 8 },
  { key: 'name', width: 30 },
  { key: 'hours', width: 15 },
  { key: 'days', width: 12 },
  { key: 'avg', width: 18 },
  { key: 'worksites', width: 35 }
];

// Foglio 4 - Riepilogo Cantieri
worksitesSheet.columns = [
  { key: 'name', width: 35 },
  { key: 'employees', width: 18 },
  { key: 'days', width: 15 },
  { key: 'hours', width: 15 },
  { key: 'records', width: 18 }
];

// Foglio 5 - Timbrature Complete
detailSheet.columns = [
  { key: 'employeeName', width: 25 },
  { key: 'workSiteName', width: 30 },
  { key: 'type', width: 12 },
  { key: 'timestamp', width: 20 },
  { key: 'deviceInfo', width: 35 },
  { key: 'googleMaps', width: 20 }
];
```

### Filtri Automatici

Solo su Foglio 5 (Timbrature Complete):
```javascript
detailSheet.autoFilter = {
  from: 'A3',  // Inizia da riga 3 (dopo titolo e header)
  to: 'F3'     // Fino a colonna F
};
```

---

## 🧪 Testing

### Scenari di Test

#### 1. Test Report Completo
**Input**: Nessun filtro  
**Expected**:
- Tutte le timbrature
- Tutti i dipendenti
- Tutti i cantieri
- 5 fogli completi
- Top 3 evidenziato

**Validazione**:
```javascript
assert(stats.totalRecords === db.count('attendance_records'));
assert(stats.uniqueEmployees.length === db.count('DISTINCT employeeId'));
```

#### 2. Test Filtro Dipendente
**Input**: `employeeId=12`  
**Expected**:
- Solo timbrature dipendente 12
- Foglio 3: Solo 1 dipendente (evidenziato oro)
- Foglio 4: Cantieri visitati da dipendente 12

#### 3. Test Filtro Cantiere
**Input**: `workSiteId=5`  
**Expected**:
- Solo timbrature cantiere 5
- Foglio 3: Dipendenti che hanno lavorato su cantiere 5
- Foglio 4: Solo cantiere 5

#### 4. Test Periodo
**Input**: `startDate=2025-10-01&endDate=2025-10-07`  
**Expected**:
- Solo timbrature in quella settimana
- stats.minDate ≥ startDate
- stats.maxDate ≤ endDate

#### 5. Test Top 3
**Input**: Report con 5+ dipendenti  
**Expected**:
- Foglio 3: Primi 3 con sfondo oro/argento/bronzo
- Ordinamento decrescente ore
- Font bold sui primi 3

#### 6. Test Calcolo Ore
**Input**: Timbrature note  
**Expected**:
```
IN: 08:00, OUT: 12:00 → 4h 00m
IN: 13:00, OUT: 17:30 → 4h 30m
Totale: 8h 30m
```

#### 7. Test Nessuna Timbratura
**Input**: Filtri che non matchano nulla  
**Expected**:
- Error 500
- Messaggio: "Nessuna timbratura trovata per i filtri selezionati"

### Unit Test (Jest)

```javascript
describe('generateAttendanceReport', () => {
  test('calcola correttamente dipendenti unici', async () => {
    const records = [
      { employeeId: 1, ... },
      { employeeId: 1, ... },
      { employeeId: 2, ... }
    ];
    
    const stats = calculateStats(records);
    expect(stats.uniqueEmployees.length).toBe(2);
  });
  
  test('ordina dipendenti per ore decrescenti', async () => {
    const employeeStats = {
      1: { totalHours: 100 },
      2: { totalHours: 150 },
      3: { totalHours: 120 }
    };
    
    const sorted = Object.entries(employeeStats)
      .sort(([, a], [, b]) => b.totalHours - a.totalHours);
    
    expect(sorted[0][0]).toBe('2'); // 150h
    expect(sorted[1][0]).toBe('3'); // 120h
    expect(sorted[2][0]).toBe('1'); // 100h
  });
  
  test('applica colori Top 3', async () => {
    const filePath = await generateAttendanceReport({});
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.readFile(filePath);
    
    const sheet = workbook.getWorksheet('Riepilogo Dipendenti');
    const row1 = sheet.getRow(4); // Primo dipendente
    const row2 = sheet.getRow(5); // Secondo
    const row3 = sheet.getRow(6); // Terzo
    
    expect(row1.getCell(1).fill.fgColor.argb).toBe('FFFFD700'); // Oro
    expect(row2.getCell(1).fill.fgColor.argb).toBe('FFC0C0C0'); // Argento
    expect(row3.getCell(1).fill.fgColor.argb).toBe('FFCD7F32'); // Bronzo
  });
});
```

### Checklist Testing Manuale

- [ ] Report si genera senza errori
- [ ] File Excel si apre correttamente
- [ ] 5 fogli presenti con nomi corretti
- [ ] Titoli fogli formattati (blu, centrati)
- [ ] Statistiche corrette (conta manuale vs automatica)
- [ ] Ore calcolate correttamente (verifica manuale sessioni)
- [ ] Top 3 evidenziati oro/argento/bronzo
- [ ] Ordinamento dipendenti decrescente
- [ ] Totali giornalieri corretti
- [ ] Link Google Maps cliccabili
- [ ] Colori IN (verde) e OUT (rosso) applicati
- [ ] Filtri automatici funzionanti (Foglio 5)
- [ ] Larghezze colonne leggibili
- [ ] Bordi celle applicati
- [ ] Periodo visualizzato correttamente

---

## 📊 Query SQL Dettagliata

```sql
SELECT 
  ar.id,
  ar.employeeId,
  ar.workSiteId,
  ar.timestamp,
  ar.type,
  ar.deviceInfo,
  ar.latitude,
  ar.longitude,
  e.name as employeeName,
  e.isActive as employeeIsActive,
  ws.name as workSiteName
FROM attendance_records ar
JOIN employees e ON ar.employeeId = e.id
LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
WHERE 1=1
  AND e.isActive = 1                          -- Solo dipendenti attivi
  AND ar.employeeId = ?                       -- Filtro dipendente (opzionale)
  AND ar.workSiteId = ?                       -- Filtro cantiere (opzionale)
  AND ar.timestamp >= ?                       -- Filtro data inizio (opzionale)
  AND ar.timestamp <= ?                       -- Filtro data fine (opzionale)
ORDER BY ar.timestamp DESC;
```

**Parametri dinamici**: Solo quelli presenti vengono applicati.

---

## 🔄 Retrocompatibilità

### Funzione Legacy

```javascript
// Funzione legacy per retrocompatibilità (deprecata)
const updateExcelReport = async (filters = {}) => {
  // Redirige alla nuova funzione professionale
  return generateAttendanceReport(filters);
};
```

**Comportamento**:
- Chiamate a `updateExcelReport()` funzionano ancora
- Viene usata la nuova funzione `generateAttendanceReport()`
- Stesso formato parametri
- Output: Nuovo report con 5 fogli (non più 1 foglio)

**Nota**: Gli utenti potrebbero notare il cambiamento (5 fogli vs 1), ma è un miglioramento positivo.

---

## 🎯 Metriche Qualità

### Performance
- **Tempo generazione**: < 3 secondi (100 timbrature)
- **Tempo generazione**: < 10 secondi (1000 timbrature)
- **Dimensione file**: ~50-100 KB (100 timbrature)

### Usabilità
- **Leggibilità**: Titoli chiari, colori distinti
- **Navigazione**: 5 fogli organizzati logicamente
- **Comprensibilità**: Statistiche autoesplicative

### Affidabilità
- **Gestione errori**: Nessuna timbratura → Error 500
- **Calcoli**: Ore validate contro calcoli manuali
- **Formattazione**: Coerente su tutti fogli

---

## 📞 Supporto

Per problemi o domande:
1. Verificare log server (`console.log` in server.js)
2. Controllare file generato in `server/reports/`
3. Validare query SQL con filtri
4. Testare con dataset minimale (5 timbrature)

---

**Fine Documentazione Tecnica** 📊
