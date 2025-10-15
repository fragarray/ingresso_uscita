# 📊 Guida Report Ore Lavorate

## Come Generare il Report Ore di un Dipendente

### 1️⃣ Accedi alla Sezione Report

- Apri l'applicazione come **Amministratore**
- Vai nella scheda **"Report"**

### 2️⃣ Seleziona il Dipendente

- **Cerca** il dipendente nella barra di ricerca (per nome o email)
- **Clicca** sul nome del dipendente nella lista che appare
- Il dipendente selezionato apparirà sotto la barra di ricerca

💡 **Nota**: Il report ore richiede **obbligatoriamente** la selezione di un dipendente specifico

### 3️⃣ Seleziona il Periodo (Opzionale)

Puoi scegliere il periodo in due modi:

#### **Periodi Rapidi** (consigliato)
- **7 Giorni**: Ultima settimana
- **1 Mese**: Ultimo mese
- **3 Mesi**: Ultimi 3 mesi
- **Personalizza**: Scegli un numero custom di mesi

#### **Date Manuali**
- Clicca sui campi **"Data Inizio"** e **"Data Fine"**
- Seleziona le date dal calendario

⚠️ Se non selezioni un periodo, il report includerà **tutte le timbrature** del dipendente

### 4️⃣ Genera il Report

- Clicca sul pulsante **verde** "Report Ore Dipendente"
- Attendi qualche secondo (apparirà un caricamento)
- Il file Excel si aprirà **automaticamente**

## 📑 Cosa Contiene il Report

Il report Excel ha **3 fogli**:

### 📊 Foglio 1: Riepilogo Ore

Mostra:
- **Ore per Cantiere**: Tabella con tutte le ore lavorate per ogni cantiere
  ```
  Cantiere A    →  120h 30m
  Cantiere B    →   85h 15m
  Cantiere C    →   42h 0m
  ────────────────────────────
  TOTALE        →  247h 45m
  ```

- **Statistiche**:
  - Giorni di lavoro effettivi
  - Media ore al giorno
  - Ore totali del periodo

### 📅 Foglio 2: Dettaglio Giornaliero

Per ogni giorno lavorato mostra:
- **Data**: 15/10/2025
- **Cantiere**: Dove ha lavorato
- **Ora Ingresso**: 08:00
- **Ora Uscita**: 17:30
- **Ore Lavorate**: 8h 30m
- **Totale Giorno**: Somma ore della giornata

### 🕐 Foglio 3: Timbrature Originali

Lista completa di tutte le timbrature:
- Data e ora esatta
- Tipo (Ingresso/Uscita)
- Cantiere
- Dispositivo usato

## 💡 Come Vengono Calcolate le Ore

Il sistema calcola automaticamente le ore abbinando:

```
INGRESSO  →  USCITA  =  ORE LAVORATE

Esempio:
08:00 IN (Cantiere A)
12:00 OUT (Cantiere A)  →  4h 0m lavorate su Cantiere A

13:00 IN (Cantiere B)
17:30 OUT (Cantiere B)  →  4h 30m lavorate su Cantiere B

TOTALE GIORNO: 8h 30m
```

### ⚠️ Importante: Timbrature Incomplete

Se un dipendente dimentica di timbrare l'uscita:
- ❌ Quelle ore **NON vengono conteggiate**
- ℹ️ La timbratura appare solo nel foglio "Timbrature Originali"
- 💡 Controlla sempre questo foglio per verificare eventuali dimenticanze

## 🎯 Casi d'Uso Pratici

### Esempio 1: Report Mensile
```
Obiettivo: Calcolare ore lavorate a settembre
1. Seleziona dipendente: Mario Rossi
2. Usa periodo rapido: "1 Mese"
3. Genera report
```

### Esempio 2: Report Trimestrale
```
Obiettivo: Rendiconto ore ultimo trimestre
1. Seleziona dipendente: Luigi Verdi
2. Usa periodo rapido: "3 Mesi"
3. Genera report
```

### Esempio 3: Report Custom
```
Obiettivo: Ore dal 1° al 15 ottobre
1. Seleziona dipendente: Anna Bianchi
2. Data Inizio: 01/10/2025
3. Data Fine: 15/10/2025
4. Genera report
```

## 🔍 Come Interpretare i Risultati

### ✅ Report OK
```
Ore Totali: 160h 0m (20 giorni lavorativi)
Media: 8h 0m al giorno
→ Dipendente regolare, 8 ore/giorno
```

### ⚠️ Report con Anomalie
```
Ore Totali: 85h 30m (20 giorni lavorativi)
Media: 4h 16m al giorno
→ Possibile problema: controllare timbrature incomplete
```

### 📈 Report Straordinari
```
Ore Totali: 195h 45m (20 giorni lavorativi)
Media: 9h 47m al giorno
→ Dipendente ha fatto straordinari
```

## 🛠️ Risoluzione Problemi

### Il pulsante è grigio/disabilitato
**Causa**: Nessun dipendente selezionato  
**Soluzione**: Cerca e seleziona un dipendente dalla lista

### Errore "Nessuna timbratura trovata"
**Causa**: Il dipendente non ha timbrature nel periodo  
**Soluzione**: 
- Verifica che le date siano corrette
- Controlla che il dipendente abbia effettivamente lavorato
- Prova ad allargare il periodo

### Ore calcolate sembrano sbagliate
**Causa**: Timbrature incomplete o errate  
**Soluzione**:
1. Apri il foglio "Timbrature Originali"
2. Controlla che ogni IN abbia un OUT
3. Verifica date/ore delle timbrature
4. Correggi timbrature errate dalla pagina "Personale"

### File non si apre automaticamente
**Causa**: Nessuna app Excel installata  
**Soluzione**:
- Il file è salvato in "Documenti"
- Aprilo manualmente con Excel/LibreOffice/Google Sheets

## 📊 Formati Ore

Il report mostra sempre ore in formato:

- **120h 30m** = 120 ore e 30 minuti
- **8h 0m** = 8 ore esatte
- **4h 15m** = 4 ore e 15 minuti

## 💼 Utilizzo per Paghe

Il report può essere usato per:
- ✅ Calcolo stipendi
- ✅ Verifica presenze mensili
- ✅ Rendicontazione clienti (ore per cantiere)
- ✅ Controllo straordinari
- ✅ Export verso software paghe

## 📞 Serve Aiuto?

Se hai problemi con il report:
1. Verifica che il server sia attivo
2. Controlla la connessione internet
3. Ricarica i dati (pulsante aggiorna)
4. Contatta l'assistenza tecnica

---

**Versione Guida**: 1.0  
**Data**: 15 Ottobre 2025
