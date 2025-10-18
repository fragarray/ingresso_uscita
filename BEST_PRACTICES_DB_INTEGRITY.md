# Best Practices - Database Integrity

**Data:** 18 ottobre 2025  
**Versione:** 1.0

## 🎯 Obiettivo

Garantire che il database rimanga sempre integro e corretto, evitando:
- ❌ Record OUT orfani
- ❌ Timestamp invertiti (OUT prima di IN)
- ❌ Bilanciamento negativo (più OUT che IN)

## ✅ Con un Nuovo Database

**SÌ, partendo da zero NON avrai problemi SE segui queste regole:**

### 1. ✅ USA SEMPRE L'APP

**✅ CORRETTO:**
```
App → Timbratura IN → Server → Database ✅
App → Timbratura OUT → Server → Database ✅
App → Forza Timbratura → Server → Database ✅
App → Modifica → Server → Database ✅
App → Elimina → Server → Database ✅
```

**❌ EVITA:**
```
SQLite Browser → Modifica Diretta DB ❌
Query SQL Manuale → INSERT/UPDATE/DELETE ❌
Script Personalizzati → Bypass Validazioni ❌
```

### 2. ✅ VALIDAZIONI AUTOMATICHE

L'app implementa validazioni che prevengono errori:

#### Timbratura Normale
- ✅ IN registrato con timestamp corrente
- ✅ OUT possibile solo se dipendente IN
- ✅ OUT timestamp sempre >= IN timestamp

#### Timbratura Forzata
- ✅ Overlap detection (±1 ora)
- ✅ IN >8h richiede OUT obbligatorio
- ✅ OUT solo se dipendente attualmente IN

#### Modifica Timbratura
- ✅ Validazione OUT >= IN nel dialog
- ✅ Picker data/ora previene timestamp futuri irrealistici
- ✅ Admin ID verificato server-side

#### Eliminazione Timbratura
- ✅ `deleteOutToo` trova OUT più vicino
- ✅ Elimina anche OUT con timestamp precedente (fix v1.1)
- ✅ Limite 24 ore per evitare eliminazioni errate

## 🚫 Scenari Problematici (e come evitarli)

### Scenario 1: Forza IN quando dipendente ha già OUT

**Problema:**
```
15:00 - IN normale
17:00 - OUT normale
14:00 - Forza IN (timestamp passato) ← OUT è DOPO ma timestamp è PRIMA!
```

**Soluzione Implementata:**
- ✅ Overlap detection (±1h) previene questo caso
- ✅ Dialog mostra conflitto e blocca operazione

**Come verificare:**
```bash
node verify_db_integrity.js
```

---

### Scenario 2: Modifica IN a timestamp DOPO l'OUT

**Problema:**
```
Originale:
  08:00 - IN
  17:00 - OUT

Modifica IN → 18:00 ← DOPO l'OUT!
```

**Soluzione Implementata:**
- ✅ Validazione nel dialog: `if (OUT < IN) → Errore`
- ✅ Salvataggio bloccato

**Log Atteso:**
```
❌ L'uscita deve essere successiva all'ingresso
```

---

### Scenario 3: Elimina IN lasciando OUT orfano

**Problema:**
```
Originale:
  08:00 - IN  [ID: 100]
  14:00 - OUT [ID: 101] ← timestamp PRECEDENTE (errore pre-esistente)
  17:00 - OUT [ID: 102]

Elimina IN [100] con deleteOutToo=true
Query cerca: OUT con timestamp > 08:00
Trova: OUT [102] → ELIMINA
Problema: OUT [101] rimane ORFANO!
```

**Soluzione Implementata (v1.1):**
```javascript
// 1. Cerca OUT DOPO (caso normale)
SELECT id FROM attendance_records 
WHERE employeeId = ? AND type = 'out' AND timestamp > ?

// 2. Se non trovato, cerca OUT PIÙ VICINO in assoluto
SELECT id FROM attendance_records 
WHERE employeeId = ? AND type = 'out'
ORDER BY ABS(timestamp_diff) ASC LIMIT 1

// 3. Elimina solo se < 24 ore di distanza
if (timeDiff < 1440 minutes) → DELETE
```

**Log Atteso:**
```
⚠️  [ELIMINA TIMBRATURA] OUT più vicino ha timestamp PRECEDENTE
   Differenza: 360 minuti
🗑️ [ELIMINA TIMBRATURA] Eliminato OUT [ID: 101] più vicino
```

---

### Scenario 4: Doppio IN consecutivo

**Problema:**
```
08:00 - IN
09:00 - IN  ← SENZA OUT intermedio
17:00 - OUT
```

**Soluzione Implementata:**
- ✅ App impedisce IN se dipendente già IN
- ⚠️  Forza timbratura può bypassare (con avviso admin)

**Come rilevare:**
```bash
node verify_db_integrity.js
# Output: "IN doppio consecutivo"
```

**Come correggere:**
```bash
node clean_db.js
# Elimina il doppio IN automaticamente
```

---

## 🔧 Strumenti di Manutenzione

### 1. Verifica Integrità (Settimanale)

```bash
cd server
node verify_db_integrity.js
```

**Output OK:**
```
✅ VERIFICA COMPLETATA: Database integro e corretto
   I calcoli delle ore lavorate risulteranno corretti.
```

**Output Problemi:**
```
⚠️  VERIFICA COMPLETATA: Rilevate anomalie
   Raccomandazioni:
   1. Verificare manualmente i record segnalati
   2. Correggere le anomalie prima di generare report
```

---

### 2. Pulizia Automatica (Al Bisogno)

```bash
cd server
node clean_db.js
```

**Cosa fa:**
- 🗑️ Elimina record OUT orfani (con conferma)
- 📋 Identifica coppie con timestamp invertito
- ⚠️ Suggerisce correzioni manuali

**Interattivo:**
```
Vuoi eliminare questi record? (s/n): s
✅ Eliminati 1 record orfani
```

---

### 3. Backup Prima di Operazioni Critiche

```bash
# Backup manuale
cp server/attendance.db server/attendance.db.backup

# Con data
cp server/attendance.db "server/attendance_$(date +%Y%m%d_%H%M%S).db"
```

**Quando fare backup:**
- Prima di pulizia massiva
- Prima di modifiche multiple
- Prima di aggiornamenti server
- Settimanalmente (automatico)

---

## 📊 Monitoraggio Continuo

### Log Server da Controllare

**✅ Operazioni Normali:**
```
✅ [ELIMINA TIMBRATURA] Record ID 123 eliminato con successo
🗑️ [ELIMINA TIMBRATURA] Eliminato OUT [ID: 124] successivo
📊 [ELIMINA TIMBRATURA] Report Excel aggiornato
```

**⚠️  Warning da Investigare:**
```
⚠️  [ELIMINA TIMBRATURA] OUT più vicino ha timestamp PRECEDENTE
⚠️  [ELIMINA TIMBRATURA] OUT troppo distante (1500 min), non eliminato
⚠️  [ELIMINA TIMBRATURA] Nessun OUT trovato per dipendente X
```

**❌ Errori da Risolvere:**
```
❌ [ELIMINA TIMBRATURA] Errore eliminazione: ...
❌ [MODIFICA TIMBRATURA] Admin ID X non autorizzato
```

### Metriche da Monitorare

**Giornaliere:**
- Rapporto IN/OUT (deve essere ~1.00)
- Numero record orfani (deve essere 0)
- Durate negative nei report (devono essere 0)

**Settimanali:**
- Esegui `verify_db_integrity.js`
- Controlla log server per warning
- Backup database

**Mensili:**
- Revisione completa dati
- Controllo report Excel storici
- Aggiornamento documentazione

---

## 🎓 Training Amministratori

### Cosa Insegnare agli Admin

**✅ Operazioni Sicure:**
1. Timbrature normali via app
2. Forza timbratura con timestamp recenti (<24h)
3. Modifica con validazione timestamp
4. Elimina con `deleteOutToo=true`

**⚠️  Operazioni Rischiose:**
1. Forza timbratura con timestamp vecchi (>7 giorni)
2. Modifica massiva di timestamp
3. Eliminazione record molto vecchi
4. Operazioni su più dipendenti contemporaneamente

**❌ Operazioni Vietate:**
1. Modifica diretta database con SQLite Browser
2. Script SQL custom senza test
3. Bypass validazioni app
4. Eliminazione manuale file .db

### Checklist Pre-Operazione Critica

Prima di operazioni rischiose, verifica:
- [ ] Backup database fatto
- [ ] Integrità DB verificata (script)
- [ ] Nessun report in generazione
- [ ] Admin ha compreso impatto operazione
- [ ] Piano rollback pronto

---

## 📚 Documentazione Correlata

- `FIX_DATABASE_ANOMALIES.md` - Risoluzione problemi esistenti
- `FEATURE_EDIT_DELETE_ATTENDANCE.md` - Funzionalità modifica/elimina
- `FIX_FORCE_ATTENDANCE_VALIDATION.md` - Validazioni forza timbratura
- `server/verify_db_integrity.js` - Script verifica
- `server/clean_db.js` - Script pulizia

---

## 🎯 Conclusione

### ✅ Con Database Nuovo

**Partendo da zero, il database rimarrà SEMPRE integro SE:**

1. ✅ Usi SOLO l'app per tutte le operazioni
2. ✅ Segui le best practices indicate
3. ✅ Verifichi integrità settimanalmente
4. ✅ Fai backup regolari
5. ✅ Monitori log server

### 🔒 Garanzia Integrità

Le validazioni implementate prevengono:
- ✅ Timestamp invertiti (validazione dialog)
- ✅ Record orfani (deleteOutToo migliorato)
- ✅ Overlap timbrature (±1h detection)
- ✅ OUT senza IN (validazione app)
- ✅ Modifiche non autorizzate (admin check)

**Risultato:**
Database sempre pulito, calcoli sempre corretti, report affidabili.

---

**Creato:** 18 ottobre 2025  
**Ultima Revisione:** Dopo fix v1.1 eliminazione OUT  
**Stato:** ✅ Produzione
