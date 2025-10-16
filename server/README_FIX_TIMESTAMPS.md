# 🔧 Script di Correzione Timestamp

## Problema Identificato

Quando si forzavano timbrature di **uscita dopo mezzanotte** (turni notturni), il sistema salvava la data dell'**ingresso** invece del giorno successivo.

### Esempio del Bug:
```
✅ CORRETTO:
01/10 19:57 IN → 02/10 03:57 OUT = 8 ore

❌ ERRATO (vecchio comportamento):
01/10 19:57 IN → 01/10 03:57 OUT = -16 ore (OUT prima di IN!)
```

## Soluzione Implementata

Lo script `fix_timestamps.js` corregge automaticamente i timestamp errati:

1. **Analizza** tutte le coppie IN/OUT
2. **Rileva** quando OUT < IN (errore temporale)
3. **Corregge** aggiungendo +1 giorno al timestamp OUT
4. **Verifica** che la correzione produca un turno ragionevole (< 18h)

## Come Usare

### 1. Backup del Database (OBBLIGATORIO)
```bash
cd server
copy database.db database.db.backup
```

### 2. Esegui lo Script
```bash
node fix_timestamps.js
```

### 3. Rivedi le Correzioni
Lo script mostrerà tutte le correzioni proposte:
```
⚠️  Trovate 7 timbrature da correggere:

1. Mario Rossi - SPV
   IN:  01/10/2025, 19:57:00
   OUT: 01/10/2025, 03:57:00 → 02/10/2025, 03:57:00
   ORE: -16.00h → 8.00h
```

### 4. Conferma
Digita `s` per applicare le correzioni.

### 5. Rigenera i Report
Dopo la correzione, **rigenera tutti i report** per vedere i calcoli corretti.

## Verifiche Post-Correzione

### Nel Foglio "⚠️ Validazione"
Dovresti vedere:
```
✅ NESSUN ERRORE RILEVATO - TUTTE LE SESSIONI SONO VALIDE
```

### Nel Foglio "Dettaglio Giornaliero"
Le ore dovrebbero essere corrette:
```
01/10/2025  SPV  19:57  03:57 (02/10)  8h 0m  ✅
```

## Prevenzione Futura

✅ **Il bug è stato corretto nel codice!**

Dalla prossima timbratura forzata:
- Il date picker permette di selezionare la data dell'uscita
- Il calcolo delle 8 ore considera automaticamente il cambio giorno
- L'ora di uscita mostra la data se diversa dall'ingresso

## Ripristino in Caso di Problemi

Se qualcosa va storto:
```bash
cd server
del database.db
copy database.db.backup database.db
```

## Note Tecniche

Lo script applica queste regole:
- Corregge solo se: `timeOut <= timeIn` per lo stesso dipendente
- Aggiunge +1 giorno solo se la differenza è tra -18h e 0h
- Non tocca sessioni già corrette o con errori diversi
- Preserva tutti gli altri campi (isForced, notes, etc.)

## Supporto

Se hai dubbi o problemi:
1. Controlla il backup esiste
2. Leggi attentamente le correzioni proposte
3. Non confermare se qualcosa sembra strano
4. Contatta il supporto con gli screenshot
