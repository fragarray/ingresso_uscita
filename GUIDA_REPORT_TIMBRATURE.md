# 📊 REPORT TIMBRATURE - GUIDA UTENTE

## 📑 Indice
1. [Introduzione](#introduzione)
2. [Come Generare il Report](#come-generare-il-report)
3. [Struttura del Report](#struttura-del-report)
4. [Interpretare le Statistiche](#interpretare-le-statistiche)
5. [Esempi Pratici](#esempi-pratici)
6. [Domande Frequenti](#domande-frequenti)
7. [Risoluzione Problemi](#risoluzione-problemi)

---

## 🎯 Introduzione

### Cos'è il Report Timbrature?

Il **Report Timbrature** è un documento Excel professionale che raccoglie e analizza **tutte le timbrature** dei dipendenti, organizzandole in **5 fogli** con diverse visualizzazioni:

1. **Riepilogo Generale** - Vista d'insieme con statistiche totali
2. **Dettaglio Giornaliero** - Sessioni lavoro giorno per giorno
3. **Riepilogo Dipendenti** - Classifica dipendenti con Top 3
4. **Riepilogo Cantieri** - Statistiche per cantiere
5. **Timbrature Complete** - Lista completa con Google Maps

### A Cosa Serve?

✅ **Monitoraggio generale** - Quante timbrature, quanti dipendenti, quanti cantieri  
✅ **Analisi produttività** - Chi ha lavorato di più? Top 3 dipendenti  
✅ **Verifica cantieri** - Quali cantieri sono più attivi?  
✅ **Controllo ore** - Calcolo automatico ore lavorate  
✅ **Audit e compliance** - Lista completa per verifiche  

### Differenze con Altri Report

| Report | Scopo | Filtri Richiesti |
|--------|-------|------------------|
| **Timbrature** | Vista generale tutti | Nessuno (opzionali) |
| Ore Dipendente | Singolo dipendente | EmployeeId obbligatorio |
| Cantiere | Singolo cantiere | WorkSiteId opzionale |

---

## 🚀 Come Generare il Report

### Accesso

1. **Login** come amministratore
2. Vai su tab **"Reports"**
3. Trovi **3 pulsanti**:
   - 🔵 **Report Timbrature** ← Questo
   - 🟢 Report Ore Dipendente
   - 🟠 Report Cantiere

### Generazione Report Completo (Consigliato)

**Quando usarlo**: Vuoi vedere tutto il quadro generale

**Passi**:
1. **Non selezionare** dipendente né cantiere
2. Imposta **periodo** (es: ultimo mese)
   - Data Inizio: `01/10/2025`
   - Data Fine: `31/10/2025`
3. Clicca **"📋 Report Timbrature"** (blu)
4. Attendi 2-5 secondi
5. File Excel si apre automaticamente

**Risultato**:
- Report con **tutte le timbrature** del periodo
- Tutti i dipendenti inclusi
- Tutti i cantieri inclusi
- Top 3 dipendenti evidenziati

---

### Generazione Report Filtrato per Dipendente

**Quando usarlo**: Vuoi vedere solo le timbrature di un dipendente specifico

**Passi**:
1. Seleziona **dipendente** dal dropdown (es: "Mario Rossi")
2. Seleziona **periodo** (opzionale)
3. Clicca **"📋 Report Timbrature"**
4. File Excel si apre

**Risultato**:
- Solo timbrature di Mario Rossi
- Foglio 3: Solo Mario Rossi (evidenziato oro, unico)
- Foglio 4: Cantieri visitati da Mario Rossi

---

### Generazione Report Filtrato per Cantiere

**Quando usarlo**: Vuoi vedere chi ha lavorato su un cantiere specifico

**Passi**:
1. Seleziona **cantiere** dal dropdown (es: "Cantiere Milano Nord")
2. Seleziona **periodo** (opzionale)
3. Clicca **"📋 Report Timbrature"**
4. File Excel si apre

**Risultato**:
- Solo timbrature cantiere Milano Nord
- Foglio 3: Dipendenti che hanno lavorato lì
- Foglio 4: Solo cantiere Milano Nord

---

### Generazione Report Combinato

**Quando usarlo**: Vuoi vedere un dipendente specifico su un cantiere specifico

**Passi**:
1. Seleziona **dipendente** (es: "Luigi Bianchi")
2. Seleziona **cantiere** (es: "Cantiere Roma Sud")
3. Seleziona **periodo**
4. Clicca **"📋 Report Timbrature"**

**Risultato**:
- Solo timbrature di Luigi Bianchi su cantiere Roma Sud nel periodo

---

## 📊 Struttura del Report

### Foglio 1: Riepilogo Generale

**Cosa contiene**:

#### Sezione Statistiche Generali
```
📊 Totale Timbrature          │ 156
✅ Ingressi (IN)              │ 78
❌ Uscite (OUT)               │ 78
👥 Dipendenti Coinvolti       │ 12
🏗️ Cantieri Coinvolti         │ 4
📅 Giorni con Timbrature      │ 15
```

**Come leggere**:
- **Totale Timbrature**: Numero totale IN + OUT
- **Ingressi/Uscite**: Dovresti avere stesso numero (pareggio)
- **Dipendenti Coinvolti**: Dipendenti che hanno timbrato (senza duplicati)
- **Cantieri Coinvolti**: Cantieri con almeno 1 timbratura
- **Giorni con Timbrature**: Giorni lavorativi effettivi

#### Sezione Ore per Dipendente
```
Dipendente     │ Ore Totali │ Giorni │ Media Ore/Giorno
Mario Rossi    │ 120h 30m   │ 15     │ 8h 02m
Luigi Bianchi  │ 110h 15m   │ 14     │ 7h 52m
TOTALE GENERALE│ 950h 45m   │        │
```

**Come leggere**:
- **Ore Totali**: Somma tutte ore lavorate (IN → OUT)
- **Giorni**: Giorni in cui dipendente ha timbrato
- **Media/Giorno**: Ore totali ÷ Giorni

**Uso Pratico**:
- Verifica dipendenti più produttivi
- Controlla media ore (target: ~8h/giorno)
- Usa per calcolare stipendi variabili

---

### Foglio 2: Dettaglio Giornaliero

**Cosa contiene**:
Tutte le **sessioni lavoro** organizzate per giorno

**Esempio**:
```
Data      │Dipendente  │Cantiere   │Ingresso│Uscita│Ore
15/10/2025│Mario Rossi │Cantiere A │08:00   │12:30 │4h 30m
15/10/2025│Mario Rossi │Cantiere B │13:30   │17:00 │3h 30m
15/10/2025│Luigi B.    │Cantiere A │08:15   │12:00 │3h 45m
          │            │           │        │Totale│11h 45m
```

**Come leggere**:
- Ogni riga = 1 sessione lavoro (IN → OUT)
- Righe **raggruppate per data** (più recente prima)
- Riga **"Totale Giorno"** con sfondo azzurro
- Righe vuote separano i giorni

**Uso Pratico**:
- Verifica orari ingresso/uscita
- Controlla se dipendente ha lavorato su più cantieri stesso giorno
- Trova anomalie (es: uscita prima delle 12:00)

---

### Foglio 3: Riepilogo Dipendenti ⭐

**Cosa contiene**:
Classifica dipendenti per **ore lavorate** con Top 3 evidenziati

**Esempio**:
```
# │Dipendente     │Ore Totali│Giorni│Media/Gg│Cantieri Visitati
1 │🥇 Mario Rossi │120h 30m  │15    │8h 02m  │Cantiere A, B, C    [ORO]
2 │🥈 Luigi B.    │110h 15m  │14    │7h 52m  │Cantiere A, C       [ARGENTO]
3 │🥉 Paolo V.    │105h 00m  │15    │7h 00m  │Cantiere B, D       [BRONZO]
4 │ Anna N.       │98h 45m   │13    │7h 35m  │Cantiere A, B
```

**Come leggere**:
- **#**: Posizione classifica (1, 2, 3, ...)
- **Sfondo colorato**: 🥇 Oro, 🥈 Argento, 🥉 Bronzo
- **Cantieri Visitati**: Lista cantieri su cui dipendente ha lavorato

**Uso Pratico**:
- **Gamification**: Mostra Top 3 ai dipendenti per motivarli
- **Performance review**: Chi lavora di più?
- **Pianificazione**: Chi è più affidabile?
- **Premi produttività**: Basa premi su questa classifica

**⚠️ Nota**: Ore != Qualità lavoro. Usa questa classifica insieme a valutazione qualitativa.

---

### Foglio 4: Riepilogo Cantieri

**Cosa contiene**:
Statistiche per **ogni cantiere** (quanti dipendenti, quanti giorni, quante ore)

**Esempio**:
```
Cantiere    │Dip.Unici│Gg.Attività│Ore Totali│Timbrature
Cantiere A  │ 8       │ 15        │ 450h 30m │ 120
Cantiere B  │ 6       │ 12        │ 320h 15m │ 96
Cantiere C  │ 4       │ 10        │ 180h 00m │ 80
```

**Come leggere**:
- **Dip.Unici**: Dipendenti diversi che hanno lavorato su quel cantiere
- **Gg.Attività**: Giorni con almeno 1 timbratura
- **Ore Totali**: Somma ore tutti dipendenti
- **Timbrature**: Conta totale IN + OUT

**Uso Pratico**:
- **Fatturazione cliente**: Usa "Ore Totali" per calcolare costi lavoro
- **Stima durata**: Confronta ore stimate vs effettive
- **Pianificazione team**: Quanti dipendenti servono per cantiere?
- **Chiusura cantiere**: Controlla se giorni attività = giorni previsti

---

### Foglio 5: Timbrature Complete

**Cosa contiene**:
**Lista completa** di tutte le timbrature (dati raw)

**Esempio**:
```
Dipendente │Cantiere  │Tipo    │Data e Ora        │Dispositivo│Maps
Mario Rossi│Cantiere A│Ingresso│15/10/25 08:00:32 │OnePlus 9  │Apri...
Mario Rossi│Cantiere A│Uscita  │15/10/25 12:30:15 │OnePlus 9  │Apri...
Luigi B.   │Cantiere B│Ingresso│15/10/25 08:15:10 │iPhone 12  │Apri...
```

**Caratteristiche**:
- **Tipo**: Verde (Ingresso), Rosso (Uscita)
- **Google Maps**: Link cliccabile per vedere posizione GPS
- **Filtri Excel**: Attivi su tutte colonne (puoi filtrare)

**Uso Pratico**:
- **Audit**: Verifica ogni singola timbratura
- **GPS Verification**: Clicca "Apri in Maps" per vedere dove dipendente ha timbrato
- **Troubleshooting**: Trova timbrature mancanti (IN senza OUT)
- **Export**: Filtra ed esporta sottoinsiemi

---

## 📈 Interpretare le Statistiche

### Statistiche Generali

#### Totale Timbrature
**Formula**: Conta tutte timbrature (IN + OUT)

**Interpretazione**:
- **Pari**: Buono, ogni ingresso ha uscita
- **Dispari**: Attenzione, manca timbratura (IN senza OUT o viceversa)

**Azioni**:
- Se dispari → Vai su Foglio 5, ordina per dipendente, trova timbratura senza coppia

---

#### Ingressi vs Uscite
**Formula**: 
- Ingressi = Conta tipo "IN"
- Uscite = Conta tipo "OUT"

**Interpretazione**:
- **Uguali**: Perfetto, tutti hanno timbrato IN e OUT
- **Ingressi > Uscite**: Dipendente ha dimenticato uscita
- **Uscite > Ingressi**: Anomalia (impossibile, verificare)

**Azioni**:
- Confronta numeri
- Se diversi → Controlla Foglio 5 per dipendente con IN senza OUT

---

#### Dipendenti Coinvolti
**Formula**: Conta dipendenti unici (no duplicati)

**Interpretazione**:
- Quanti dipendenti hanno lavorato nel periodo
- Utile per capire dimensione team attivo

**Esempio**:
- Timbrature: 100
- Dipendenti: 10
- → Media 10 timbrature/dipendente (5 giorni lavorativi)

---

#### Cantieri Coinvolti
**Formula**: Conta cantieri con almeno 1 timbratura

**Interpretazione**:
- Quanti cantieri sono stati attivi
- Indica diversificazione lavoro

**Azioni**:
- Confronta con cantieri totali
- Se pochi cantieri → Concentrazione su progetti specifici
- Se molti cantieri → Frammentazione risorse

---

#### Giorni con Timbrature
**Formula**: Conta date uniche con almeno 1 timbratura

**Interpretazione**:
- Giorni lavorativi effettivi
- Diverso da "giorni nel periodo" (include weekend/festivi)

**Esempio**:
- Periodo: 01/10 - 31/10 (31 giorni)
- Giorni timbrature: 22
- → 22 giorni lavorativi (esclusi 9 giorni weekend/festivi)

---

### Ore Lavorate

#### Ore Totali per Dipendente
**Formula**: Somma ore di tutte sessioni IN → OUT

**Interpretazione**:
- Ore effettive lavorate (escluse pause)
- Base per calcolo stipendi orari

**Esempio**:
- Dipendente: Mario Rossi
- Ore Totali: 120h 30m
- Giorni: 15
- → Media 8h 02m/giorno

**⚠️ Nota**: 
- Ore NON includono pause non timbrate
- Se dipendente timbre IN 8:00, OUT 12:00, IN 13:00, OUT 17:00 → Conta 4h + 4h = 8h (pausa 1h esclusa)

---

#### Media Ore/Giorno
**Formula**: Ore Totali ÷ Giorni Lavorati

**Interpretazione**:
- Produttività media giornaliera
- Target tipico: 8h/giorno

**Classificazione**:
- **> 9h**: Straordinari frequenti
- **8-9h**: Normale
- **7-8h**: Sotto media (verificare motivi)
- **< 7h**: Anomalia (part-time o timbrature incomplete)

---

### Top 3 Dipendenti

#### Come Funziona
Sistema ordina dipendenti per **ore totali decrescenti** ed evidenzia primi 3:
- 🥇 **1° Oro**: Più ore lavorate
- 🥈 **2° Argento**: Secondo
- 🥉 **3° Bronzo**: Terzo

#### Uso Gamification
**Scopo**: Motivare dipendenti tramite competizione sana

**Come Comunicare**:
1. Stampa Foglio 3
2. Appendi in bacheca aziendale
3. Annuncia Top 3 in riunione settimanale
4. Premia 1° posto (es: bonus €50)

**⚠️ Attenzione**:
- **Non** usare solo ore come metrica (qualità > quantità)
- Considera anche: sicurezza, precisione, soddisfazione cliente
- Evita demotivazione ultimi in classifica

---

### Statistiche Cantieri

#### Dipendenti Unici per Cantiere
**Formula**: Conta dipendenti diversi che hanno timbrato su cantiere

**Interpretazione**:
- Dimensione team cantiere
- Turnover dipendenti

**Esempio**:
- Cantiere A: 8 dipendenti
- Cantiere B: 2 dipendenti
- → Cantiere A richiede team più grande

---

#### Giorni Attività Cantiere
**Formula**: Conta date uniche con timbrature su cantiere

**Interpretazione**:
- Durata effettiva cantiere
- Confronta con stima iniziale

**Esempio**:
- Preventivo: 20 giorni
- Effettivo: 25 giorni
- → Ritardo 5 giorni (analizzare cause)

---

#### Ore Totali Cantiere
**Formula**: Somma ore tutti dipendenti su cantiere

**Uso Pratico**:
- **Fatturazione**: Ore x Tariffa oraria = Costo lavoro
- **Budget**: Confronta ore preventivate vs effettive
- **Margine**: Verifica se rientri nei costi

**Esempio**:
```
Cantiere: Ristrutturazione Ufficio
Ore Totali: 450h 30m
Tariffa: €25/h
Costo Lavoro: 450.5 x 25 = €11,262.50
```

---

## 💡 Esempi Pratici

### Esempio 1: Verifica Mensile Produttività

**Obiettivo**: Controllare produttività team nel mese di Ottobre

**Passi**:
1. Genera report **senza filtri**
2. Periodo: `01/10/2025 - 31/10/2025`
3. Apri Excel
4. Vai su **Foglio 1: Riepilogo Generale**

**Analisi**:
```
📊 Totale Timbrature: 480
👥 Dipendenti: 12
📅 Giorni: 22

Calcolo:
- Media timbrature/dipendente: 480 / 12 = 40 timbrature
- Media giorni/dipendente: 22 (tutti hanno lavorato tutti giorni ✅)
- Ore totali: 1,760h
- Media ore/dipendente: 1760 / 12 = 146.66h/mese
- Media ore/giorno: 146.66 / 22 = 6.66h/giorno ⚠️
```

**Azione**:
- Media 6.66h/giorno è **sotto target** (8h)
- Verifica su Foglio 3 chi ha media bassa
- Controlla Foglio 5 per timbrature mancanti

---

### Esempio 2: Fatturazione Cliente per Cantiere

**Obiettivo**: Calcolare costo lavoro per fattura cliente

**Passi**:
1. Genera report **filtrato per cantiere** "Ristrutturazione Ufficio Roma"
2. Periodo: `01/09/2025 - 30/09/2025` (mese lavori)
3. Apri Excel
4. Vai su **Foglio 4: Riepilogo Cantieri**

**Dati**:
```
Cantiere: Ristrutturazione Ufficio Roma
Dipendenti Unici: 6
Giorni Attività: 18
Ore Totali: 850h 30m
```

**Calcolo Fattura**:
```
Ore Totali: 850.5h
Tariffa oraria: €30/h
Subtotale Lavoro: 850.5 x 30 = €25,515.00
IVA 22%: €5,613.30
TOTALE FATTURA: €31,128.30
```

**Allegato**:
- Stampa **Foglio 2: Dettaglio Giornaliero** per dettaglio ore/giorno
- Cliente può verificare ogni sessione lavoro

---

### Esempio 3: Analisi Dipendente per Stipendio Variabile

**Obiettivo**: Calcolare bonus produttività Mario Rossi

**Passi**:
1. Genera report **filtrato per dipendente** "Mario Rossi"
2. Periodo: `01/10/2025 - 31/10/2025`
3. Apri Excel
4. Vai su **Foglio 1: Riepilogo Generale**

**Dati**:
```
Dipendente: Mario Rossi
Ore Totali: 180h 45m
Giorni Lavorati: 22
Media Ore/Giorno: 8h 13m

Cantieri Visitati (Foglio 1, sezione ore per cantiere):
- Cantiere A: 100h
- Cantiere B: 50h
- Cantiere C: 30h 45m
```

**Calcolo Bonus**:
```
Policy aziendale: €5 bonus ogni ora sopra 160h/mese

Ore totali: 180.75h
Target: 160h
Ore extra: 180.75 - 160 = 20.75h
Bonus: 20.75 x 5 = €103.75
```

**Comunicazione**:
- Mostra Foglio 3: Mario Rossi è **1° in classifica** 🥇
- Stampa e consegna con busta paga

---

### Esempio 4: Controllo Qualità Timbrature

**Obiettivo**: Verificare se ci sono timbrature incomplete

**Passi**:
1. Genera report **senza filtri**
2. Apri Excel
3. Vai su **Foglio 1: Riepilogo Generale**

**Verifica Bilancio IN/OUT**:
```
✅ Ingressi (IN): 240
❌ Uscite (OUT): 238  ⚠️ PROBLEMA!
```

**Azione**:
1. Vai su **Foglio 5: Timbrature Complete**
2. Attiva filtro colonna "Tipo"
3. Filtra solo "Ingresso"
4. Conta righe: 240
5. Rimuovi filtro
6. Filtra solo "Uscita"
7. Conta righe: 238
8. Trova dipendente con IN senza OUT:
   - Ordina per "Dipendente" poi "Data e Ora"
   - Cerca sequenze: IN → IN (senza OUT tra mezzo)

**Esempio Trovato**:
```
Mario Rossi │ Cantiere A │ Ingresso │ 14/10/25 08:00 │ ...
Mario Rossi │ Cantiere A │ Ingresso │ 15/10/25 08:00 │ ... ← PROBLEMA
                                                         (manca OUT 14/10)
```

**Risoluzione**:
- Contatta Mario Rossi
- Chiedi orario uscita 14/10
- Aggiungi manualmente timbratura OUT da admin panel

---

## ❓ Domande Frequenti (FAQ)

### **Q1: Perché non vedo alcun dipendente su Foglio 3?**
**A**: Hai filtrato per cantiere/periodo senza timbrature. Genera report senza filtri oppure amplia periodo.

---

### **Q2: Top 3 ha solo 1 dipendente con sfondo oro, gli altri normali. Perché?**
**A**: Hai filtrato per 1 solo dipendente. Top 3 richiede almeno 3 dipendenti nel report.

---

### **Q3: Ore totali non tornano con calcolo manuale. Come mai?**
**A**: Sistema esclude timbrature incomplete (IN senza OUT). Controlla Foglio 5 per verificare.

---

### **Q4: Media ore/giorno è troppo bassa (es: 4h). Errore?**
**A**: Possibili cause:
- Dipendente lavora part-time
- Timbrature incomplete (mancano uscite)
- Doppia timbratura stesso giorno (conta 2 giorni invece di 1)

Verifica Foglio 2 per dettaglio sessioni.

---

### **Q5: Cantiere mostra 0 dipendenti. Come mai?**
**A**: Nessuna timbratura su quel cantiere nel periodo selezionato. Verifica:
- Periodo troppo ristretto
- Cantiere creato ma mai usato
- Dipendenti hanno selezionato cantiere diverso

---

### **Q6: Link Google Maps non funziona. Perché?**
**A**: Possibili cause:
- Timbratura senza GPS (coordinate mancanti)
- Link Excel non cliccabile (prova tasto destro → "Apri hyperlink")

---

### **Q7: Report richiede molto tempo (> 30 secondi). Normale?**
**A**: No, potrebbe indicare:
- Database molto grande (>10,000 timbrature)
- Server lento
- Filtri troppo ampi

Prova filtrare per cantiere o periodo più breve.

---

### **Q8: Posso stampare solo Foglio 3 (Top 3)?**
**A**: Sì!
1. Apri Excel
2. Clicca su tab "Riepilogo Dipendenti"
3. File → Stampa → Stampa foglio attivo

---

### **Q9: Come esporto solo Top 5 dipendenti?**
**A**:
1. Apri Foglio 3
2. Seleziona righe 1-8 (titolo + header + top 5)
3. Copia
4. Nuovo Excel → Incolla
5. Salva come "Top 5.xlsx"

---

### **Q10: Posso modificare Excel (es: aggiungere colonne)?**
**A**: Sì, Excel è completamente modificabile. Ma attenzione:
- ⚠️ Modifiche si perdono se rigeneri report
- ✅ Salva versione modificata con nome diverso

---

## 🔧 Risoluzione Problemi

### Problema: "Nessuna timbratura trovata"

**Sintomi**:
- Messaggio errore rosso
- File non si genera

**Cause**:
1. Periodo selezionato senza timbrature
2. Filtro dipendente/cantiere senza match
3. Database vuoto

**Soluzioni**:
1. Amplia periodo (es: ultimo anno invece di ultima settimana)
2. Rimuovi filtri dipendente/cantiere
3. Verifica che esistano timbrature nel database

---

### Problema: Ore calcolate sembrano sbagliate

**Sintomi**:
- Ore troppo alte (es: 25h/giorno)
- Ore troppo basse (es: 1h/giorno)

**Cause**:
1. **Ore alte**: Timbrature doppie (IN → IN senza OUT)
2. **Ore basse**: Timbrature incomplete (IN senza OUT)

**Soluzioni**:
1. Vai su **Foglio 5**
2. Filtra per dipendente con ore anomale
3. Ordina per "Data e Ora"
4. Cerca pattern:
   - `IN → IN` (manca OUT tra mezzo)
   - `OUT → OUT` (manca IN tra mezzo)
   - `IN` (fine lista senza OUT successivo)
5. Correggi manualmente da admin panel

---

### Problema: Excel non si apre automaticamente

**Sintomi**:
- Report generato (messaggio verde)
- File non si apre

**Cause**:
1. Excel non installato
2. Permessi file mancanti
3. Antivirus blocca apertura

**Soluzioni**:
1. Vai manualmente in `Documenti/` → cerca file `attendance_report_XXX.xlsx`
2. Clicca per aprire
3. Se Excel non installato: installa LibreOffice (gratuito)

---

### Problema: Google Maps link non cliccabili

**Sintomi**:
- Colonna "Google Maps" mostra testo "Apri in Maps" ma non è link

**Cause**:
1. Excel non riconosce hyperlink
2. Protezione visualizzazione Excel

**Soluzioni**:
1. Excel → File → Opzioni → Centro protezione → Impostazioni centro protezione → Visualizzazione protetta → Disabilita "Abilita visualizzazione protetta file da percorsi Internet"
2. Oppure: Tasto destro su cella → "Apri hyperlink"

---

### Problema: Top 3 non colorato

**Sintomi**:
- Foglio 3 senza sfondo oro/argento/bronzo

**Cause**:
1. Meno di 3 dipendenti nel report
2. Excel non mostra colori (modalità compatibilità)

**Soluzioni**:
1. Genera report con più dipendenti (rimuovi filtro dipendente)
2. Excel → File → Opzioni → Impostazioni avanzate → Mostra → Mostra colori

---

### Problema: Periodo errato visualizzato

**Sintomi**:
- Riga 2 Foglio 1 mostra periodo diverso da quello selezionato

**Causa**:
- Report usa **data effettiva** timbrature, non periodo filtro

**Esempio**:
```
Filtro impostato: 01/10/2025 - 31/10/2025
Timbrature effettive: 05/10/2025 - 28/10/2025
Periodo visualizzato: 05/10/2025 - 28/10/2025 ✅ CORRETTO
```

---

## 📞 Supporto

### Hai ancora problemi?

1. **Controlla Foglio 5** (Timbrature Complete) per dati raw
2. **Verifica filtri** (rimuovi tutti e riprova)
3. **Testa con periodo breve** (es: ultimi 7 giorni)
4. **Contatta supporto tecnico** con screenshot errore

---

## 🎓 Best Practices

### ✅ Consigli Uso Quotidiano

1. **Genera report settimanale** (ogni venerdì)
2. **Verifica bilancio IN/OUT** (devono essere uguali)
3. **Stampa Top 3** e appendi in bacheca
4. **Archivia report mensili** per storico

### ✅ Consigli Fatturazione

1. **Usa Foglio 4** per calcolo costi cantiere
2. **Allega Foglio 2** (dettaglio giornaliero) a fattura
3. **Salva report con nome cliente** (es: "Report_Cliente_Rossi_Ottobre.xlsx")

### ✅ Consigli Performance Review

1. **Confronta Top 3 mensile** per trend
2. **Analizza media ore/giorno** per individuo
3. **Verifica cantieri visitati** (versatilità dipendente)

---

**Fine Guida Utente** 📊

**Versione**: 1.0  
**Ultimo aggiornamento**: 15 Ottobre 2025
