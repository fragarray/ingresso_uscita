# 📊 Report Ore Lavorate - Documentazione

## 🎯 Descrizione Funzionalità

Il sistema di **Report Ore Lavorate** calcola automaticamente le ore effettive di lavoro di un dipendente basandosi sulle coppie di timbrature (ingresso/uscita).

## ✨ Caratteristiche

### 📈 Calcolo Automatico Ore
- **Accoppiamento intelligente**: Il sistema abbina automaticamente timbrature IN con OUT consecutive
- **Calcolo preciso**: Utilizza timestamp esatti per calcolare ore e minuti lavorati
- **Multi-cantiere**: Divide le ore per cantiere di lavoro
- **Statistiche giornaliere**: Calcola ore totali per ogni giorno

### 📑 Report Excel Multi-Foglio

Il report generato contiene **3 fogli Excel**:

#### 1. **Riepilogo Ore** 📊
- **Ore per Cantiere**: Tabella con ore totali lavorate per ogni cantiere
- **Totale Generale**: Somma di tutte le ore lavorate nel periodo
- **Statistiche**:
  - Giorni di lavoro
  - Media ore al giorno
  - Ore totali periodo

#### 2. **Dettaglio Giornaliero** 📅
- Ogni giorno viene mostrato con:
  - Data
  - Cantiere
  - Ora ingresso
  - Ora uscita
  - Ore lavorate per sessione
  - Totale ore giornaliere

#### 3. **Timbrature Originali** 🕐
- Lista completa di tutte le timbrature
- Data e ora esatta
- Tipo (Ingresso/Uscita)
- Cantiere
- Dispositivo utilizzato

## 🔧 Come Funziona

### Algoritmo di Calcolo

```javascript
1. Carica tutte le timbrature del dipendente per il periodo
2. Ordina per timestamp crescente
3. Per ogni coppia IN→OUT consecutiva:
   - Calcola differenza temporale
   - Accumula ore per cantiere
   - Registra sessione giornaliera
4. Genera statistiche aggregate
```

### Esempio di Calcolo

```
Timbrature:
- 08:00 IN  → Cantiere A
- 12:00 OUT → Cantiere A
- 13:00 IN  → Cantiere B
- 17:30 OUT → Cantiere B

Risultato:
- Cantiere A: 4h 0m
- Cantiere B: 4h 30m
- TOTALE: 8h 30m
```

## 📱 Utilizzo Frontend

### Interfaccia Utente

1. **Seleziona Dipendente** (obbligatorio)
   - Cerca per nome o email
   - Seleziona dalla lista

2. **Seleziona Periodo** (opzionale)
   - Data inizio e fine
   - Oppure usa periodi rapidi (7 giorni, 1 mese, ecc.)

3. **Genera Report**
   - Clicca su **"Report Ore Dipendente"** (pulsante verde)
   - Il file Excel si aprirà automaticamente

### Validazione

- ⚠️ **Dipendente obbligatorio**: Il pulsante è disabilitato se non è selezionato un dipendente
- ✅ **Periodo opzionale**: Se non specificato, considera tutte le timbrature
- 💡 **Tooltip informativo**: Appare se manca la selezione del dipendente

## 🎨 Formattazione Excel

### Stili Applicati

- **Intestazioni**: Blu (#4472C4) con testo bianco e grassetto
- **Totali**: Verde chiaro (#E2EFDA) con grassetto
- **Date**: Grassetto con sfondo grigio (#F2F2F2)
- **Colori testo**:
  - Ingresso: Verde (#00B050)
  - Uscita: Rosso (#E74C3C)

### Larghezze Colonne Ottimizzate

- Cantiere: 30-35 caratteri
- Ore/Minuti: 12-15 caratteri
- Date: 15-20 caratteri
- Dispositivo: 35 caratteri

## 🔌 API Backend

### Endpoint

```
GET /api/attendance/hours-report
```

### Parametri Query

| Parametro | Tipo | Obbligatorio | Descrizione |
|-----------|------|--------------|-------------|
| `employeeId` | int | ✅ Sì | ID del dipendente |
| `startDate` | ISO 8601 | ❌ No | Data inizio (inclusa) |
| `endDate` | ISO 8601 | ❌ No | Data fine (inclusa) |

### Esempio Richiesta

```
GET /api/attendance/hours-report?employeeId=5&startDate=2025-10-01T00:00:00.000Z&endDate=2025-10-15T23:59:59.999Z
```

### Risposta

- **200 OK**: File Excel in download
- **400 Bad Request**: `employeeId` mancante
- **500 Internal Server Error**: Errore durante generazione

## 📊 Struttura Dati

### Calcolo Sessioni Lavorative

```javascript
{
  workSessions: {
    "Cantiere A": 12.5,      // ore totali
    "Cantiere B": 8.25,      // ore totali
    "Non specificato": 2.0   // ore senza cantiere
  },
  dailySessions: {
    "2025-10-15": [
      {
        workSite: "Cantiere A",
        timeIn: Date,
        timeOut: Date,
        hours: 4.5
      }
    ]
  }
}
```

### Formato Ore

```javascript
formatHoursMinutes(totalHours) {
  hours: Math.floor(totalHours),       // 8
  minutes: round((totalHours % 1) * 60), // 30
  formatted: "8h 30m"
}
```

## 🚀 Funzionalità Future (Opzionali)

### Possibili Estensioni

- [ ] **Ore Straordinarie**: Calcolo automatico se supera 8h/giorno
- [ ] **Pause Pranzo**: Configurazione pause automatiche
- [ ] **Festività**: Rilevamento giorni festivi
- [ ] **Export PDF**: Versione stampabile del report
- [ ] **Invio Email**: Invio automatico report al dipendente
- [ ] **Grafici**: Visualizzazione grafica ore per cantiere/giorno
- [ ] **Confronto Periodi**: Comparazione mese corrente vs precedente
- [ ] **Allert Anomalie**: Notifica se manca timbratura OUT

## 💡 Note Tecniche

### Gestione Timbrature Incomplete

Se un dipendente dimentica di timbrare l'uscita:
- La timbratura IN viene **ignorata** (non accoppiata)
- Non contribuisce al calcolo ore
- Appare solo nel foglio "Timbrature Originali"

### Precisione Calcoli

- **Unità base**: Ore decimali (es: 8.5 ore = 8h 30m)
- **Arrotondamento minuti**: Al minuto più vicino
- **Fuso orario**: Utilizza timezone locale del server

### Performance

- **Query ottimizzata**: Singola query con LEFT JOIN
- **Ordinamento DB**: ORDER BY timestamp ASC (indice DB)
- **Memoria**: Elaborazione in-memory (adatto fino a ~10.000 record)

## 📚 Codice Correlato

### File Modificati

1. **Backend**: `server/server.js`
   - `calculateWorkedHours()` - Logica calcolo ore
   - `formatHoursMinutes()` - Formattazione ore/minuti
   - `generateEmployeeHoursReport()` - Generazione Excel
   - Endpoint: `GET /api/attendance/hours-report`

2. **Frontend API**: `lib/services/api_service.dart`
   - `downloadEmployeeHoursReport()` - Chiamata API

3. **Frontend UI**: `lib/widgets/reports_tab.dart`
   - `_generateHoursReport()` - Gestione UI
   - Pulsante "Report Ore Dipendente"
   - Validazione selezione dipendente

## ✅ Testing

### Scenari di Test

1. **Test Base**
   - Dipendente con timbrature complete (coppie IN/OUT)
   - Verifica calcolo ore corretto

2. **Test Multi-Cantiere**
   - Timbrature su 3+ cantieri diversi
   - Verifica separazione ore per cantiere

3. **Test Timbrature Incomplete**
   - IN senza OUT consecutivo
   - Verifica che venga ignorato

4. **Test Periodo Vuoto**
   - Dipendente senza timbrature nel periodo
   - Verifica messaggio errore

5. **Test Cambio Giorno**
   - Timbrature a cavallo mezzanotte
   - Verifica calcolo ore corretto

### Comandi Test

```bash
# Avvia server
cd server
node server.js

# Test API manuale
curl "http://localhost:3000/api/attendance/hours-report?employeeId=1"
```

## 📞 Supporto

Per problemi o domande:
- **Bug**: Controllare console backend per errori SQL
- **Calcoli errati**: Verificare timbrature nel foglio "Timbrature Originali"
- **File non scaricato**: Verificare permessi cartella `server/reports/`

---

**Data Implementazione**: 15 Ottobre 2025  
**Versione**: 1.0  
**Autore**: Sistema Ingresso/Uscita
