# 🗑️ Guida Eliminazione Dipendenti

## 🎯 Comportamento Automatico Intelligente

Quando elimini un dipendente, il sistema decide **automaticamente** il tipo di eliminazione più appropriato:

### 📊 Regola di Decisione

```
HA TIMBRATURE?
│
├─ NO  → 🔴 HARD DELETE (eliminazione completa)
│        ├─ Rimosso dal database
│        ├─ Non appare in nessun report
│        └─ Come se non fosse mai esistito
│
└─ SÌ  → 🟡 SOFT DELETE (disattivazione)
         ├─ Marcato come inattivo (isActive = 0)
         ├─ Rimane nel database
         ├─ Timbrature storiche preservate
         └─ Appare nei report come [DIPENDENTE ELIMINATO #ID]
```

## 💡 Casi d'Uso

### Caso 1: Dipendente Creato per Errore
**Situazione**: Hai creato "Mario Rossi" invece di "Marco Rossi"

**Azione**: Elimina subito "Mario Rossi" PRIMA che timbri

**Risultato**: 
- ✅ HARD DELETE automatico
- ✅ Database pulito
- ✅ Nessuna traccia nei report

---

### Caso 2: Dipendente che Lascia l'Azienda
**Situazione**: "Luigi Verdi" ha lavorato 6 mesi, ora si dimette

**Azione**: Elimina "Luigi Verdi"

**Risultato**:
- ✅ SOFT DELETE automatico (ha timbrature storiche)
- ✅ Storico ore lavorate preservato
- ✅ Appare nei report passati
- ✅ Non può più effettuare nuove timbrature
- ✅ Non appare nella lista dipendenti attivi

---

### Caso 3: Dipendente di Test
**Situazione**: Hai creato "TEST USER" per provare l'app

**Azione**: Elimina "TEST USER" senza farlo timbrare

**Risultato**:
- ✅ HARD DELETE automatico
- ✅ Nessuna traccia nel sistema

## 🔍 Come Verificare il Tipo di Eliminazione

### Risposta API

Quando elimini un dipendente, l'API risponde con:

#### HARD DELETE (nessuna timbratura)
```json
{
  "success": true,
  "deleted": true,
  "message": "Dipendente eliminato completamente (nessuna timbratura)"
}
```

#### SOFT DELETE (con timbrature)
```json
{
  "success": true,
  "deleted": false,
  "message": "Dipendente disattivato (15 timbrature preservate)"
}
```

## 📋 Report e Dipendenti Eliminati (Soft Delete)

### Come Appaiono nei Report

I dipendenti con SOFT DELETE appaiono come:
```
[DIPENDENTE ELIMINATO #4]
[DIPENDENTE ELIMINATO #7]
```

Il numero è l'ID del dipendente nel database.

### Quali Report Li Includono

✅ **Inclusi** in:
- Report Generale Timbrature
- Report Ore Dipendente (se richiedi il suo ID)
- Report Cantiere (se ha lavorato lì)
- Report Timbrature Forzate (se ha timbrature forzate)

❌ **NON inclusi** in:
- Lista dipendenti attivi
- Selezione dipendente per nuove timbrature
- Dashboard dipendenti attivi

## ⚖️ Conformità Legale

### Perché Preserviamo i Dati?

In Italia, i dati lavorativi devono essere conservati per:
- 📜 **Obblighi fiscali**: 10 anni
- 📜 **Contributi INPS**: Fino a prescrizione diritti
- 📜 **Sicurezza lavoro**: 10 anni (D.Lgs. 81/2008)

Il SOFT DELETE automatico garantisce:
- ✅ Conformità normativa
- ✅ Audit trail completo
- ✅ Calcoli ore retroattivi corretti

## 🛡️ Sicurezza

### Controlli Lato Client (già implementati)

L'app Flutter impedisce:
- ❌ Eliminare se stessi
- ❌ Eliminare l'unico admin rimasto

### Controlli Lato Server

Il server gestisce:
- ✅ Decisione automatica HARD vs SOFT DELETE
- ✅ Logging dettagliato per audit
- ✅ Preservazione integrità referenziale

## 🔧 Pulizia Database (Opzionale)

Se vuoi **forzare** l'eliminazione completa di un dipendente con timbrature (non raccomandato):

```sql
-- ⚠️  ATTENZIONE: Questo elimina anche le timbrature!
DELETE FROM attendance_records WHERE employeeId = ?;
DELETE FROM employees WHERE id = ?;
```

**⚠️ Rischi**:
- Perdita storico ore lavorate
- Report storici incompleti
- Possibili problemi legali/fiscali

## 📞 Domande Frequenti

### Q: Posso recuperare un dipendente soft-deleted?
**A**: Sì, basta eseguire:
```sql
UPDATE employees SET isActive = 1, deletedAt = NULL WHERE id = ?;
```

### Q: I dipendenti soft-deleted contano nel limite licenze?
**A**: Dipende dalla licenza. Solitamente no, perché `isActive = 0`.

### Q: Posso vedere QUANDO un dipendente è stato eliminato?
**A**: Sì, guarda il campo `deletedAt` nella tabella `employees`.

### Q: Cosa succede se ricreo un dipendente con lo stesso nome?
**A**: Viene creato un nuovo record con nuovo ID. Non interferisce con quello eliminato.

---

**Versione**: 2.0  
**Data**: 15 Ottobre 2025  
**Sistema**: Ingresso/Uscita Cantieri
