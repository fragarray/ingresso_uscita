# 🏗️ Guida Report Cantiere

## Come Generare il Report Statistiche Cantiere

### 1️⃣ Accedi alla Sezione Report

- Apri l'applicazione come **Amministratore**
- Vai nella scheda **"Report"**

### 2️⃣ Seleziona il Cantiere (Opzionale)

Hai **due opzioni**:

#### **Opzione A: Singolo Cantiere**
- Seleziona un cantiere dal menu a tendina "Cantiere"
- Il pulsante mostrerà: "Report Cantiere: {Nome Cantiere}"

#### **Opzione B: Tutti i Cantieri**
- Lascia "Tutti i cantieri" selezionato
- Il pulsante mostrerà: "Report Tutti i Cantieri"

### 3️⃣ Seleziona il Periodo (Opzionale)

Come per gli altri report:
- **Periodi Rapidi**: 7 Giorni, 1 Mese, 3 Mesi
- **Date Manuali**: Seleziona data inizio e fine

⚠️ Se non selezioni un periodo, il report includerà **tutte le timbrature**

### 4️⃣ Filtra per Dipendente (Opzionale)

- Se vuoi vedere solo le ore di un dipendente specifico su quel cantiere:
  - Cerca e seleziona il dipendente
  - Il report mostrerà solo le sue timbrature

### 5️⃣ Genera il Report

- Clicca sul pulsante **arancione** "🏗️ Report Cantiere"
- Attendi qualche secondo
- Il file Excel si aprirà **automaticamente**

---

## 📑 Cosa Contiene il Report

Il report cantiere Excel ha **4 fogli**:

### 📊 Foglio 1: Riepilogo Cantiere

#### Informazioni Cantiere
- **Nome**: Nome del cantiere
- **Indirizzo**: Ubicazione
- **Coordinate GPS**: Latitudine e longitudine

#### Statistiche Principali
```
┌────────────────────────────────┬───────────────────────┐
│ 👥 Dipendenti Totali           │ 8 persone             │
│ 📅 Giorni di Apertura          │ 15 giorni             │
│ ⏱️  Ore Totali Lavorate        │ 520h 30m              │
│ 📊 Media Ore per Giorno        │ 34h 42m               │
│ 👤 Media Ore per Dipendente    │ 65h 3m                │
│ 🔢 Timbrature Totali           │ 240                   │
└────────────────────────────────┴───────────────────────┘
```

#### Ore per Dipendente (con Ranking)
```
┌──────────────────┬──────────────┬────────────────┬──────────────┐
│ Dipendente       │ Ore Lavorate │ Giorni Presenti│ Media/Giorno │
├──────────────────┼──────────────┼────────────────┼──────────────┤
│ 🥇 Mario Rossi   │ 98h 30m      │ 13 giorni      │ 7h 34m       │ ← 1° (ORO)
│ 🥈 Luigi Verdi   │ 85h 15m      │ 12 giorni      │ 7h 6m        │ ← 2° (ARGENTO)
│ 🥉 Anna Bianchi  │ 76h 45m      │ 11 giorni      │ 6h 58m       │ ← 3° (BRONZO)
│ Paolo Neri       │ 72h 0m       │ 10 giorni      │ 7h 12m       │
│ ...              │ ...          │ ...            │ ...          │
├──────────────────┼──────────────┼────────────────┼──────────────┤
│ TOTALE GENERALE  │ 520h 30m     │ 15 giorni      │ 34h 42m      │
└──────────────────┴──────────────┴────────────────┴──────────────┘
```

💡 **I top 3 dipendenti sono evidenziati con colori oro/argento/bronzo!**

---

### 📅 Foglio 2: Dettaglio Giornaliero

Per ogni giorno mostra:
- **Data**: Es. 01/10/2025
- **Dipendente**: Chi ha lavorato
- **Ora Ingresso**: Es. 08:00
- **Ora Uscita**: Es. 17:30
- **Ore Lavorate**: Ore della sessione
- **Totale Giorno**: Somma ore di quel giorno (tutti dipendenti)

```
01/10/2025
├─ Mario Rossi:    08:00 → 12:30 (4h 30m)
├─ Mario Rossi:    13:15 → 17:00 (3h 45m)
├─ Luigi Verdi:    08:30 → 17:00 (8h 30m)
└─ Anna Bianchi:   09:00 → 18:00 (8h 0m)
   TOTALE GIORNO: 34h 15m

02/10/2025
├─ Mario Rossi:    08:15 → 17:30 (8h 15m)
└─ ...
```

---

### 👥 Foglio 3: Lista Dipendenti

Classifica completa con:
- **Dipendente**: Nome
- **Ore Totali**: Somma ore lavorate
- **Giorni Presenti**: Numero giorni lavorati
- **Prima Timbratura**: Data/ora prima volta
- **Ultima Timbratura**: Data/ora ultima volta

🏆 **Top 3 evidenziati**:
- 🥇 **1° posto**: Sfondo ORO
- 🥈 **2° posto**: Sfondo ARGENTO
- 🥉 **3° posto**: Sfondo BRONZO

---

### 🕐 Foglio 4: Timbrature Originali

Lista completa di **tutte le timbrature**:
- Data e ora esatta
- Dipendente
- Tipo (Ingresso/Uscita)
  - 🟢 **VERDE**: Ingresso
  - 🔴 **ROSSO**: Uscita
- Dispositivo usato

---

## 🎯 Casi d'Uso Pratici

### Esempio 1: Report Mensile Cantiere
```
Obiettivo: Statistiche cantiere per ottobre
1. Seleziona cantiere: "Cantiere Centro Storico"
2. Periodo: "1 Mese"
3. Clicca "Report Cantiere"

Output:
- Giorni apertura: 22
- Ore totali: 654h 30m
- 12 dipendenti
- Top 3 performer evidenziati
```

### Esempio 2: Confronto Tutti i Cantieri
```
Obiettivo: Vedere statistiche aggregate
1. Cantiere: "Tutti i cantieri"
2. Periodo: "3 Mesi"
3. Clicca "Report Cantiere"

Output:
- Ore totali tutti cantieri
- Dipendenti totali (senza duplicati)
- Media ore per cantiere
```

### Esempio 3: Verifica Lavoro Dipendente su Cantiere
```
Obiettivo: Quanto ha lavorato Mario su Cantiere A?
1. Seleziona cantiere: "Cantiere A"
2. Seleziona dipendente: "Mario Rossi"
3. Periodo: "1 Mese"
4. Clicca "Report Cantiere"

Output:
- Solo timbrature Mario su Cantiere A
- Ore lavorate da Mario
- Giorni presenza Mario
```

---

## 📊 Come Leggere le Statistiche

### Dipendenti Totali
**Cosa indica**: Numero di persone **diverse** che hanno lavorato sul cantiere

Esempio:
```
Mario timbra 10 volte
Luigi timbra 5 volte
Anna timbra 8 volte
→ Dipendenti Totali: 3 (non 23!)
```

### Giorni di Apertura
**Cosa indica**: Quanti giorni il cantiere ha avuto **almeno una timbratura**

Esempio:
```
Lunedì: 10 timbrature
Martedì: 0 timbrature
Mercoledì: 5 timbrature
→ Giorni Apertura: 2 (lunedì + mercoledì)
```

### Ore Totali Lavorate
**Cosa indica**: Somma di **tutte le ore** lavorate da **tutti i dipendenti**

Esempio:
```
Mario: 45h
Luigi: 38h
Anna: 42h
→ Ore Totali: 125h
```

### Media Ore per Giorno
**Cosa indica**: Quante ore **in media** sono state lavorate ogni giorno di apertura

Calcolo: `Ore Totali / Giorni Apertura`

Esempio:
```
Ore Totali: 520h 30m
Giorni Apertura: 15
→ Media: 34h 42m/giorno
```

💡 **Utile per**: Capire se il cantiere è produttivo

### Media Ore per Dipendente
**Cosa indica**: Quante ore **in media** ha lavorato ogni dipendente

Calcolo: `Ore Totali / Dipendenti Totali`

Esempio:
```
Ore Totali: 520h 30m
Dipendenti: 8
→ Media: 65h 3m/dipendente
```

💡 **Utile per**: Vedere distribuzione carico lavoro

---

## 🏆 Ranking Dipendenti

Il report ordina i dipendenti per **ore lavorate decrescenti**:

```
Posizione  Dipendente     Ore        Badge
─────────────────────────────────────────
   1°      Mario Rossi    98h 30m   🥇 ORO
   2°      Luigi Verdi    85h 15m   🥈 ARGENTO
   3°      Anna Bianchi   76h 45m   🥉 BRONZO
   4°      Paolo Neri     72h 0m    
   5°      ...            ...       
```

💡 **I top 3 sono evidenziati con sfondo colorato nel file Excel!**

---

## 💼 Utilizzo per Gestione

### 📋 Rendiconto Cliente

**Quando**: Fine mese, devi fatturare ore lavorate

**Come usare**:
1. Genera report cantiere per il mese
2. Vai su foglio "Riepilogo"
3. Prendi "Ore Totali Lavorate"
4. Moltiplica per tariffa oraria
5. Allega report come documentazione

### 📊 Analisi Produttività

**Quando**: Vuoi capire se cantiere va bene

**Indicatori**:
- ✅ **Buono**: Media ore/giorno stabile (~30-40h)
- ⚠️ **Attenzione**: Media ore/giorno bassa (<20h)
- 🔴 **Problema**: Giorni apertura < giorni lavorativi

### 👥 Gestione Risorse

**Quando**: Devi assegnare dipendenti

**Come usare**:
1. Guarda "Lista Dipendenti"
2. Verifica chi ha lavorato meno
3. Riequilibra assegnazioni

### 📈 Pianificazione

**Quando**: Devi stimare tempi completamento

**Come usare**:
1. Calcola "Media Ore per Giorno"
2. Stima giorni rimanenti necessari
3. Moltiplica: `Giorni × Media = Ore previste`

---

## 🔍 Interpretazione Risultati

### ✅ Cantiere Sano
```
Statistiche:
- Giorni apertura: 20/22 giorni lavorativi
- Media ore/giorno: 35h
- Dipendenti: 8-10
- Distribuzione: Top 3 non troppo distanziati

Significato: Cantiere regolare, buona organizzazione
```

### ⚠️ Cantiere da Monitorare
```
Statistiche:
- Giorni apertura: 12/22 giorni lavorativi
- Media ore/giorno: 18h
- Dipendenti: 3-4
- Distribuzione: 1° dipendente fa 70% ore

Significato: Sotto-staffato, rischio ritardi
```

### 🔴 Cantiere Problematico
```
Statistiche:
- Giorni apertura: 5/22 giorni lavorativi
- Media ore/giorno: 8h
- Dipendenti: 1-2
- Distribuzione: Molto disomogenea

Significato: Quasi fermo, serve intervento
```

---

## 🛠️ Risoluzione Problemi

### Il pulsante è disabilitato
**Causa**: Server non disponibile  
**Soluzione**: Verifica connessione, riavvia server

### Errore "Nessuna timbratura trovata"
**Causa**: Cantiere senza timbrature nel periodo  
**Soluzione**:
- Verifica che il cantiere abbia effettivamente avuto lavori
- Prova ad allargare il periodo
- Controlla di aver selezionato il cantiere giusto

### Ore sembrano sbagliate
**Causa**: Timbrature incomplete (IN senza OUT)  
**Soluzione**:
1. Apri foglio "Timbrature Originali"
2. Controlla che ogni IN abbia un OUT
3. Verifica eventuali timbrature mancanti
4. Correggi da pagina "Personale"

### Dipendente mancante nel report
**Causa**: Dipendente non ha coppie IN/OUT complete  
**Soluzione**:
1. Controlla foglio "Timbrature Originali"
2. Verifica se appare nelle timbrature
3. Se mancano OUT, aggiungi timbrature forzate

### File non si apre
**Causa**: Nessuna app Excel installata  
**Soluzione**:
- File salvato in "Documenti"
- Aprilo con Excel, LibreOffice o Google Sheets

---

## 💡 Suggerimenti Utili

### 📅 Frequenza Consigliata

- **Report Settimanale**: Controllo produttività
- **Report Mensile**: Fatturazione cliente
- **Report Trimestrale**: Analisi trend

### 🎯 Focus Metriche

**Per gestione quotidiana**:
- Giorni apertura
- Media ore/giorno

**Per fatturazione**:
- Ore totali lavorate
- Lista dipendenti

**Per analisi**:
- Ranking dipendenti
- Dettaglio giornaliero

### 📊 Esportazione Dati

Il report Excel può essere:
- ✅ Inviato via email al cliente
- ✅ Importato in software contabilità
- ✅ Stampato per archivio cartaceo
- ✅ Convertito in PDF

---

## 📞 Serve Aiuto?

Se hai problemi con il report cantiere:
1. Verifica che il server sia attivo
2. Controlla la connessione internet
3. Ricarica i dati (pulsante aggiorna)
4. Verifica che il cantiere abbia timbrature
5. Contatta l'assistenza tecnica

---

**Versione Guida**: 1.0  
**Data**: 15 Ottobre 2025  
**Report Cantiere**: 4 fogli Excel con statistiche complete
