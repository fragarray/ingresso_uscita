# 🏗️ Report Cantiere Avanzato - Documentazione Tecnica

## 📋 Panoramica

Sistema completo per generare report Excel professionali sui cantieri, con statistiche aggregate, calcolo ore lavorate, analisi dipendenti e visualizzazioni dettagliate.

---

## ✨ Caratteristiche Principali

### 📊 Report Multi-Foglio Excel

Il report cantiere include **4 fogli** completi:

#### 1. **Riepilogo Cantiere** 📈
- Informazioni cantiere (nome, indirizzo, coordinate)
- Statistiche principali:
  - 👥 Dipendenti totali (senza duplicati)
  - 📅 Giorni di apertura
  - ⏱️ Ore totali lavorate
  - 📊 Media ore per giorno
  - 👤 Media ore per dipendente
  - 🔢 Timbrature totali
- Tabella ore per dipendente con ranking
- Totale generale

#### 2. **Dettaglio Giornaliero** 📅
- Sessioni di lavoro per ogni giorno
- Raggruppamento per dipendente
- Ora ingresso/uscita
- Ore lavorate per sessione
- Totale ore giornaliere

#### 3. **Lista Dipendenti** 👥
- Classifica dipendenti per ore lavorate
- **Top 3 evidenziati**:
  - 🥇 Oro: 1° classificato
  - 🥈 Argento: 2° classificato
  - 🥉 Bronzo: 3° classificato
- Ore totali per dipendente
- Giorni presenti
- Prima e ultima timbratura

#### 4. **Timbrature Originali** 🕐
- Lista completa timbrature
- Dipendente, tipo, data/ora, dispositivo
- Colori: Verde (IN), Rosso (OUT)

---

## 🎯 Funzionalità Report

### Modalità di Generazione

Il report cantiere supporta **3 modalità**:

#### 1️⃣ **Singolo Cantiere**
```
Parametri: workSiteId + periodo
Output: Report specifico cantiere selezionato
```

#### 2️⃣ **Tutti i Cantieri**
```
Parametri: periodo (no workSiteId)
Output: Report aggregato tutti i cantieri
```

#### 3️⃣ **Cantiere + Dipendente Filtrato**
```
Parametri: workSiteId + employeeId + periodo
Output: Report cantiere con solo timbrature dipendente specifico
```

---

## 📊 Statistiche Calcolate

### Metriche Principali

| Metrica | Calcolo | Descrizione |
|---------|---------|-------------|
| **Dipendenti Totali** | `DISTINCT employeeId` | Numero unico dipendenti |
| **Giorni di Apertura** | `DISTINCT DATE(timestamp)` | Giorni con almeno 1 timbratura |
| **Ore Totali** | `SUM(OUT - IN)` | Somma tutte ore lavorate |
| **Media Ore/Giorno** | `Ore Totali / Giorni` | Media ore per giorno apertura |
| **Media Ore/Dipendente** | `Ore Totali / Dipendenti` | Media ore per dipendente |
| **Timbrature Totali** | `COUNT(*)` | Numero totale timbrature |

### Metriche per Dipendente

| Metrica | Descrizione |
|---------|-------------|
| Ore Totali | Somma ore lavorate da dipendente |
| Giorni Presenti | Numero giorni con timbrature |
| Media Ore/Giorno | Ore totali / Giorni presenti |
| Prima Timbratura | Data/ora prima timbratura |
| Ultima Timbratura | Data/ora ultima timbratura |

---

## 🔧 Implementazione Backend

### Funzione Principale

**`generateWorkSiteReport(workSiteId, employeeId, startDate, endDate)`**

```javascript
// Parametri:
// - workSiteId: int (opzionale) - ID cantiere specifico
// - employeeId: int (opzionale) - Filtra solo dipendente
// - startDate: ISO 8601 (opzionale) - Data inizio
// - endDate: ISO 8601 (opzionale) - Data fine

// Output:
// - File Excel con 4 fogli
// - Nome file: report_cantiere_{id}_{timestamp}.xlsx
```

### Query SQL

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
  ws.name as workSiteName,
  ws.address as workSiteAddress
FROM attendance_records ar
JOIN employees e ON ar.employeeId = e.id
LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
WHERE 1=1
  AND ar.workSiteId = ? -- Se specificato
  AND ar.employeeId = ? -- Se specificato
  AND ar.timestamp >= ? -- Se specificato
  AND ar.timestamp <= ? -- Se specificato
ORDER BY ar.timestamp ASC
```

### Algoritmo Calcolo Statistiche

```javascript
// 1. Calcola ore lavorate (riusa calculateWorkedHours)
const { workSessions, dailySessions } = calculateWorkedHours(records);

// 2. Estrai dipendenti unici
const uniqueEmployees = [...new Set(records.map(r => r.employeeId))];

// 3. Estrai date uniche
const uniqueDates = [...new Set(
  records.map(r => new Date(r.timestamp).toISOString().split('T')[0])
)];

// 4. Calcola ore totali
let totalHours = 0;
Object.values(workSessions).forEach(hours => totalHours += hours);

// 5. Calcola medie
const avgHoursPerDay = totalHours / uniqueDates.length;
const avgHoursPerEmployee = totalHours / uniqueEmployees.length;

// 6. Raggruppa per dipendente
const employeeHours = {};
records.forEach(record => {
  if (!employeeHours[record.employeeId]) {
    employeeHours[record.employeeId] = { name, records: [] };
  }
  employeeHours[record.employeeId].records.push(record);
});

// 7. Calcola ore per dipendente
employeeStats = employeeHours.map(emp => ({
  name: emp.name,
  hours: calculateTotalHours(emp.records),
  days: uniqueDays(emp.records).length
}));

// 8. Ordina per ore decrescenti (ranking)
employeeStats.sort((a, b) => b.hours - a.hours);
```

---

## 🎨 Formattazione Excel

### Stili Applicati

#### Titolo Principale
```javascript
{
  font: { bold: true, size: 16, color: '#1F4E78' },
  alignment: { vertical: 'middle', horizontal: 'center' }
}
```

#### Intestazioni Tabella
```javascript
{
  font: { bold: true, color: 'FFFFFF' },
  fill: { type: 'pattern', pattern: 'solid', fgColor: '#4472C4' }, // Blu
  alignment: { vertical: 'middle', horizontal: 'center' },
  border: { all: 'thin' }
}
```

#### Totali
```javascript
{
  font: { bold: true, size: 12 },
  fill: { type: 'pattern', pattern: 'solid', fgColor: '#E2EFDA' }, // Verde chiaro
  border: { top: 'medium', others: 'thin' }
}
```

#### Info Cantiere
```javascript
{
  fill: { type: 'pattern', pattern: 'solid', fgColor: '#F2F2F2' }, // Grigio chiaro
  border: { all: 'thin' }
}
```

#### Ranking Dipendenti (Top 3)
```javascript
{
  1°: { fgColor: '#FFD700' }, // Oro
  2°: { fgColor: '#C0C0C0' }, // Argento
  3°: { fgColor: '#CD7F32' }  // Bronzo
}
```

---

## 📱 Frontend - Interfaccia Utente

### Pulsante Report Cantiere

**Posizione**: Tab Report, sotto pulsanti Timbrature e Ore Dipendente

**Caratteristiche**:
- 🟠 **Colore**: Arancione
- 🏗️ **Icona**: `Icons.construction`
- **Testo dinamico**:
  - Se cantiere selezionato: "Report Cantiere: {nome}"
  - Altrimenti: "Report Tutti i Cantieri"
- **Sempre attivo** (non richiede selezioni obbligatorie)

### Layout Pulsanti

```
┌─────────────────────┐ ┌──────────────────────┐
│ 📋 Report          │ │ ⏱️  Report Ore      │
│    Timbrature      │ │    Dipendente       │
└─────────────────────┘ └──────────────────────┘
┌──────────────────────────────────────────────┐
│ 🏗️  Report Cantiere: {nome cantiere}       │
└──────────────────────────────────────────────┘
```

### Info Box

Pannello informativo sotto i pulsanti che mostra:
- 📋 **Timbrature**: Lista completa con filtri
- ⏱️ **Ore Dipendente**: Calcolo ore (stato: abilitato/disabilitato)
- 🏗️ **Cantiere**: Statistiche cantiere (nome o "tutti")

---

## 🔌 API Endpoint

### Backend

```
GET /api/worksite/report
```

#### Parametri Query

| Parametro | Tipo | Obbligatorio | Descrizione |
|-----------|------|--------------|-------------|
| `workSiteId` | int | ❌ No | ID cantiere specifico |
| `employeeId` | int | ❌ No | Filtra solo dipendente |
| `startDate` | ISO 8601 | ❌ No | Data inizio (inclusa) |
| `endDate` | ISO 8601 | ❌ No | Data fine (inclusa) |

#### Esempi Richieste

**1. Report singolo cantiere (periodo 1 mese)**
```
GET /api/worksite/report?workSiteId=5&startDate=2025-10-01T00:00:00.000Z&endDate=2025-10-31T23:59:59.999Z
```

**2. Report tutti cantieri (periodo 7 giorni)**
```
GET /api/worksite/report?startDate=2025-10-08T00:00:00.000Z&endDate=2025-10-15T23:59:59.999Z
```

**3. Report cantiere filtrato per dipendente**
```
GET /api/worksite/report?workSiteId=5&employeeId=12&startDate=2025-10-01T00:00:00.000Z&endDate=2025-10-15T23:59:59.999Z
```

#### Risposte

- **200 OK**: File Excel in download
- **500 Internal Server Error**: 
  - `{ "error": "Nessuna timbratura trovata per il periodo selezionato" }`
  - `{ "error": "Database error message" }`

### Frontend API

**Funzione**: `ApiService.downloadWorkSiteReport()`

```dart
static Future<String?> downloadWorkSiteReport({
  int? workSiteId,
  int? employeeId,
  DateTime? startDate,
  DateTime? endDate,
}) async
```

**Utilizzo**:
```dart
final filePath = await ApiService.downloadWorkSiteReport(
  workSiteId: _selectedWorkSite?.id,
  employeeId: _selectedEmployee?.id,
  startDate: _startDate,
  endDate: _endDate,
);

if (filePath != null) {
  await OpenFile.open(filePath);
}
```

---

## 📊 Esempio Output Report

### Foglio 1: Riepilogo Cantiere

```
╔═══════════════════════════════════════════════════════════╗
║     REPORT CANTIERE - CANTIERE CENTRO STORICO            ║
║            Periodo: 01/10/2025 - 15/10/2025              ║
╚═══════════════════════════════════════════════════════════╝

INFORMAZIONI CANTIERE
┌─────────────────────┬──────────────────────────────────┐
│ Nome Cantiere:      │ Cantiere Centro Storico          │
│ Indirizzo:          │ Via Roma 123, Milano             │
│ Coordinate:         │ 45.464664, 9.188540              │
└─────────────────────┴──────────────────────────────────┘

STATISTICHE CANTIERE
┌────────────────────────┬─────────┬────────────────────────┬─────────┐
│ Metrica                │ Valore  │ Metrica                │ Valore  │
├────────────────────────┼─────────┼────────────────────────┼─────────┤
│ Dipendenti Totali      │ 8       │ Ore Totali Lavorate    │ 520h 30m│
│ Giorni di Apertura     │ 15      │ Media Ore per Giorno   │ 34h 42m │
│ Timbrature Totali      │ 240     │ Media Ore per Dipendente│ 65h 3m │
└────────────────────────┴─────────┴────────────────────────┴─────────┘

ORE LAVORATE PER DIPENDENTE
┌──────────────────────┬──────────────┬────────────────┬──────────────────┐
│ Dipendente           │ Ore Lavorate │ Giorni Presenti│ Media Ore/Giorno │
├──────────────────────┼──────────────┼────────────────┼──────────────────┤
│ 🥇 Mario Rossi       │ 98h 30m      │ 13             │ 7h 34m           │ (ORO)
│ 🥈 Luigi Verdi       │ 85h 15m      │ 12             │ 7h 6m            │ (ARGENTO)
│ 🥉 Anna Bianchi      │ 76h 45m      │ 11             │ 6h 58m           │ (BRONZO)
│ Paolo Neri           │ 72h 0m       │ 10             │ 7h 12m           │
│ ...                  │ ...          │ ...            │ ...              │
└──────────────────────┴──────────────┴────────────────┴──────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┓
┃ TOTALE GENERALE      ┃ 520h 30m     ┃ 15 giorni      ┃ 34h 42m          ┃
┗━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━┛
```

### Foglio 2: Dettaglio Giornaliero

```
┌────────────┬─────────────────┬─────────────┬─────────────┬──────────────┬──────────────────┐
│ Data       │ Dipendente      │ Ora Ingresso│ Ora Uscita  │ Ore Lavorate │ Totale Giorno    │
├────────────┼─────────────────┼─────────────┼─────────────┼──────────────┼──────────────────┤
│ 01/10/2025 │ Mario Rossi     │ 08:00       │ 12:30       │ 4h 30m       │ 34h 15m          │
│            │ Mario Rossi     │ 13:15       │ 17:00       │ 3h 45m       │                  │
│            │ Luigi Verdi     │ 08:30       │ 17:00       │ 8h 30m       │                  │
│            │ Anna Bianchi    │ 09:00       │ 18:00       │ 8h 0m        │                  │
│            │ ...             │ ...         │ ...         │ ...          │                  │
├────────────┼─────────────────┼─────────────┼─────────────┼──────────────┼──────────────────┤
│ 02/10/2025 │ Mario Rossi     │ 08:15       │ 17:30       │ 8h 15m       │ 32h 45m          │
│            │ ...             │ ...         │ ...         │ ...          │                  │
└────────────┴─────────────────┴─────────────┴─────────────┴──────────────┴──────────────────┘
```

### Foglio 3: Lista Dipendenti

```
┌────────────────────┬─────────────┬────────────────┬─────────────────────┬─────────────────────┐
│ Dipendente         │ Ore Totali  │ Giorni Presenti│ Prima Timbratura    │ Ultima Timbratura   │
├────────────────────┼─────────────┼────────────────┼─────────────────────┼─────────────────────┤
│ Mario Rossi        │ 98h 30m     │ 13             │ 01/10/2025 08:00:12 │ 15/10/2025 17:30:45 │ 🥇
│ Luigi Verdi        │ 85h 15m     │ 12             │ 01/10/2025 08:30:22 │ 15/10/2025 17:00:10 │ 🥈
│ Anna Bianchi       │ 76h 45m     │ 11             │ 01/10/2025 09:00:05 │ 14/10/2025 18:00:33 │ 🥉
│ Paolo Neri         │ 72h 0m      │ 10             │ 02/10/2025 08:15:44 │ 15/10/2025 17:15:20 │
└────────────────────┴─────────────┴────────────────┴─────────────────────┴─────────────────────┘
```

---

## 💡 Casi d'Uso

### 1️⃣ Rendiconto Cliente

**Scenario**: Fatturare ore lavorate al cliente per cantiere specifico

```dart
// Genera report cantiere per mese corrente
final filePath = await ApiService.downloadWorkSiteReport(
  workSiteId: 5,
  startDate: DateTime(2025, 10, 1),
  endDate: DateTime(2025, 10, 31),
);

// Output: Foglio "Riepilogo" mostra ore totali e dipendenti
```

### 2️⃣ Analisi Produttività

**Scenario**: Verificare quali dipendenti sono più produttivi

```dart
// Genera report tutti cantieri
final filePath = await ApiService.downloadWorkSiteReport(
  startDate: startDate,
  endDate: endDate,
);

// Output: Foglio "Lista Dipendenti" con ranking (Top 3 evidenziati)
```

### 3️⃣ Verifica Presenza Dipendente

**Scenario**: Controllare quando un dipendente ha lavorato su cantiere

```dart
// Filtra per cantiere + dipendente
final filePath = await ApiService.downloadWorkSiteReport(
  workSiteId: 5,
  employeeId: 12,
  startDate: startDate,
  endDate: endDate,
);

// Output: Solo timbrature del dipendente su quel cantiere
```

### 4️⃣ Statistiche Mensili

**Scenario**: Report mensile gestione cantiere

```dart
// Report cantiere ultimo mese
final filePath = await ApiService.downloadWorkSiteReport(
  workSiteId: cantiereId,
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

// Output: 
// - Giorni apertura
// - Ore totali
// - Media ore/giorno
// - Dipendenti coinvolti
```

---

## 🚀 Funzionalità Future

### Possibili Estensioni

- [ ] **Grafici Excel**: Chart.js integrato nei fogli
- [ ] **Comparazione Cantieri**: Report multi-cantiere comparativo
- [ ] **Costi Progetto**: Calcolo costo ore × tariffa oraria
- [ ] **Previsioni**: Stima ore necessarie per completamento
- [ ] **Export PDF**: Versione stampabile report
- [ ] **Dashboard Cantiere**: Visualizzazione web interattiva
- [ ] **Allert Anomalie**: Notifica se cantiere sotto-performante
- [ ] **Geo-heatmap**: Mappa concentrazione timbrature

---

## ✅ Testing

### Scenari di Test

1. **Test Base**
   - Cantiere con 5+ dipendenti
   - Periodo 2 settimane
   - Verifica calcoli ore corretti

2. **Test Tutti Cantieri**
   - No workSiteId
   - Verifica aggregazione tutti cantieri

3. **Test Filtro Dipendente**
   - workSiteId + employeeId
   - Verifica solo timbrature dipendente

4. **Test Periodo Vuoto**
   - Cantiere senza timbrature
   - Verifica messaggio errore

5. **Test Ranking**
   - Verifica Top 3 evidenziati
   - Verifica ordinamento decrescente

6. **Test Date Edge**
   - Timbrature a cavallo mezzanotte
   - Verifica calcolo giorni apertura

---

## 📞 Supporto

### Troubleshooting

**Problema**: "Nessuna timbratura trovata"
- **Causa**: Cantiere senza timbrature nel periodo
- **Soluzione**: Verificare date o selezionare cantiere diverso

**Problema**: Ore sembrano sbagliate
- **Causa**: Timbrature incomplete (IN senza OUT)
- **Soluzione**: Controllare foglio "Timbrature Originali"

**Problema**: Dipendenti mancanti
- **Causa**: Dipendenti senza coppie IN/OUT
- **Soluzione**: Correggere timbrature incomplete

---

**Data Implementazione**: 15 Ottobre 2025  
**Versione**: 1.0  
**Complessità**: Alta  
**Status**: ✅ Production Ready
