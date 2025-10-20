# 🔑 Credenziali Post-Migrazione

**Data Migrazione**: 20 Ottobre 2025

## ⚠️ IMPORTANTE: NUOVE MODALITÀ DI ACCESSO

A partire da oggi, **tutti gli utenti devono effettuare il login con USERNAME invece dell'email**.

La password rimane **invariata**.

---

## 👥 Elenco Username Generati

### Amministratori

| Email Precedente | Nuovo Username | Password | Ruolo |
|-----------------|----------------|----------|-------|
| `admin@admin.it` | **`admin`** | *invariata* | Amministratore |
| `admin@example.com` | **`admin_1`** | *invariata* | Amministratore |
| `morgan98@libero.it` | **`morgan98`** | *invariata* | Amministratore |

### Dipendenti

| Email Precedente | Nuovo Username | Password | Ruolo |
|-----------------|----------------|----------|-------|
| `pippo@pippo.it` | **`pippo`** | *invariata* | Dipendente |
| `tommaso@tommaso.it` | **`tommaso`** | *invariata* | Dipendente |
| `marco@marco.it` | **`marco`** | *invariata* | Dipendente |
| `g@g.g` | **`g`** | *invariata* | Dipendente |

---

## 📱 Come Effettuare il Login

### Prima (OBSOLETO ❌)
```
Campo: Email
Valore: admin@admin.it
Password: [la tua password]
```

### Adesso (CORRETTO ✅)
```
Campo: Username
Valore: admin
Password: [la stessa password di prima]
```

---

## 🆕 Nuove Funzionalità

### Ruolo Capocantiere
È stato aggiunto un nuovo tipo di account: **Capocantiere** (Foreman).

I capicantiere possono:
- ✅ Visualizzare tutti i cantieri attivi
- ✅ Vedere i dipendenti attualmente timbrati IN su ogni cantiere
- ✅ Scaricare report storici per cantiere con filtro date
- ✅ Generare file Excel con le timbrature

**Pagina dedicata**: Dopo il login, i capicantiere vedranno una pagina di report cantieri invece della pagina di timbratura normale.

### Email Opzionale
- L'email **non è più obbligatoria** per dipendenti e capicantiere
- L'email **rimane obbligatoria SOLO per gli amministratori** (serve per l'invio dei report)

---

## 🔐 Gestione Account

### Creazione Nuovo Dipendente

Gli amministratori possono creare nuovi account specificando:

1. **Nome**: Nome completo del dipendente
2. **Username**: Login univoco (alfanumerico + underscore)
3. **Email**: Opzionale per dipendenti/capicantiere, obbligatoria per admin
4. **Password**: Password iniziale
5. **Ruolo**: Dipendente / Capocantiere / Amministratore
6. **Turni notturni**: Autorizzazione per timbrare in orari notturni

### Modifica Account Esistente

- Lo **username può essere modificato** (deve rimanere univoco)
- Il **ruolo può essere cambiato** (dipendente ↔ capocantiere ↔ admin)
- L'**email può essere aggiunta/modificata/rimossa** (tranne per admin)
- La **password può essere cambiata** opzionalmente

---

## ❓ FAQ - Domande Frequenti

### Q: Ho dimenticato il mio username, come faccio?
**R**: Contatta un amministratore che può consultare la lista completa nel sistema.

### Q: Posso ancora usare l'email per il login?
**R**: Temporaneamente sì (per retrocompatibilità), ma è **sconsigliato**. Il fallback email verrà rimosso nelle prossime versioni. Inizia subito ad usare il tuo username.

### Q: La mia password è cambiata?
**R**: **NO!** La password è rimasta identica. Cambia solo il campo "username" invece di "email".

### Q: Cosa succede se ci sono due persone con lo stesso username potenziale?
**R**: Il sistema aggiunge automaticamente un numero progressivo. Ad esempio:
- `admin@admin.it` → `admin`
- `admin@example.com` → `admin_1`
- `admin@altro.it` → `admin_2`

### Q: Posso cambiare il mio username?
**R**: Sì, un amministratore può modificare il tuo username dalla sezione "Gestione Personale".

### Q: Come faccio a diventare capocantiere?
**R**: Un amministratore può cambiare il tuo ruolo da "Dipendente" a "Capocantiere" modificando il tuo account.

### Q: Cosa vede un capocantiere dopo il login?
**R**: Una pagina con la lista di tutti i cantieri. Cliccando su un cantiere, vede:
- Dipendenti attualmente IN sul cantiere
- Orari di timbratura IN
- Possibilità di scaricare report storico per quel cantiere

---

## 🆘 Supporto

In caso di problemi con il login:

1. ✅ Verifica di usare il campo **Username** e non Email
2. ✅ Controlla di aver digitato correttamente il tuo username (vedi tabella sopra)
3. ✅ Verifica che la password sia corretta (è la stessa di prima)
4. ✅ Assicurati che il tuo account sia attivo (non disabilitato da un admin)

Se il problema persiste, contatta un amministratore.

---

## 🔄 Backup

In caso di problemi critici, è stato creato un backup automatico del database pre-migrazione:

**Percorso**: `server/database_backup_1760953474453.db`

**ATTENZIONE**: Il ripristino del backup riporterà il sistema al vecchio sistema di login via email. Da usare solo in emergenza.

---

## 📊 Statistiche Migrazione

- **Dipendenti migrati**: 7
- **Amministratori**: 3 (`admin`, `admin_1`, `morgan98`)
- **Dipendenti**: 4 (`pippo`, `tommaso`, `marco`, `g`)
- **Capicantiere**: 0 (da creare manualmente se necessario)
- **Username duplicati gestiti**: 1 (`admin_1`)

---

## 📅 Timeline

- **20 Ottobre 2025**: Migrazione database completata
- **20 Ottobre 2025**: Deployment nuovo sistema
- **20 Ottobre 2025 - In poi**: Sistema username attivo
- **Dicembre 2025 (previsto)**: Rimozione fallback login via email

---

**Documento generato automaticamente dallo script di migrazione**  
*Per domande tecniche, consultare `CHANGELOG_USERNAME_AUTH.md`*
