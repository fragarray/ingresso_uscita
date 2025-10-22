# 🔍 DEBUG AUTO-CHECKOUT MEZZANOTTE

## Problema Riscontrato
L'auto-checkout automatico alle 00:01 **non si è attivato** ieri notte per i dipendenti non autorizzati ai turni notturni.

## Modifiche Applicate

### 1. **Correzione Timestamp** ✅
- **Problema**: Il timestamp usava millisecondi (`.999`) invece di secondi interi
- **Soluzione**: Cambiato da `setHours(23, 59, 59, 0)` a `setHours(23, 59, 59, 999)`

### 2. **Endpoint di Debug Aggiunto** ✅
Nuovo endpoint: `POST /api/admin/debug-auto-checkout`

**Risposta JSON**:
```json
{
  "success": true,
  "debug": {
    "totalActiveEmployees": 10,
    "employeesWithLastIN": 3,
    "employeesWithNightShiftEnabled": 1,
    "eligibleForAutoCheckout": 2,
    "details": [
      {
        "name": "Mario Rossi",
        "lastType": "in",
        "lastTimestamp": "2025-10-21T17:30:00",
        "allowNightShift": 0,
        "eligibleForCheckout": true
      },
      ...
    ]
  }
}
```

### 3. **Log Migliorati** ✅
- Log dettagliato all'avvio del cron con prossima esecuzione prevista
- Log con timestamp locale italiano (Europe/Rome)

---

## 🚨 Checklist di Verifica

### PASSO 1: Verifica Timezone Server
Collegati al Raspberry via SSH e verifica:

```bash
# 1. Controlla data e ora corrente
date

# 2. Verifica timezone
timedatectl

# 3. Verifica che sia impostato Europe/Rome
timedatectl | grep "Time zone"
```

**Output atteso**: `Time zone: Europe/Rome (CEST, +0200)`

**Se non corretto**:
```bash
sudo timedatectl set-timezone Europe/Rome
sudo systemctl restart ingresso-uscita
```

---

### PASSO 2: Verifica Server in Esecuzione
```bash
# Controlla status del servizio
sudo systemctl status ingresso-uscita

# Verifica che il processo sia attivo
ps aux | grep node
```

---

### PASSO 3: Controlla Log del Server
```bash
# Visualizza log in tempo reale
sudo journalctl -u ingresso-uscita -f

# Oppure gli ultimi 100 log
sudo journalctl -u ingresso-uscita -n 100
```

**Cerca nei log**:
- ✅ `✓ Scheduler auto-checkout attivato`
- ✅ `→ Prossima esecuzione prevista: ...`
- ✅ `⏰ [CRON] Job auto-checkout avviato alle ...` (alle 00:01)

---

### PASSO 4: Test Manuale Debug
Usa l'endpoint di debug per vedere quali dipendenti verrebbero processati:

**Da Postman o dalla tua app admin**:
```http
POST http://TUO_IP:3000/api/admin/debug-auto-checkout
Content-Type: application/json

{
  "adminId": 1
}
```

**Analizza la risposta**:
- `totalActiveEmployees`: Totale dipendenti attivi
- `employeesWithLastIN`: Dipendenti con ultima timbratura = IN
- `employeesWithNightShiftEnabled`: Dipendenti con turni notturni autorizzati
- `eligibleForAutoCheckout`: **Quanti verranno processati** (deve essere > 0)

---

### PASSO 5: Test Manuale Forzato
Forza l'esecuzione manuale dell'auto-checkout:

```http
POST http://TUO_IP:3000/api/admin/force-auto-checkout
Content-Type: application/json

{
  "adminId": 1
}
```

**Verifica la risposta**:
```json
{
  "success": true,
  "message": "Auto-checkout completato: 2 dipendenti processati",
  "processedCount": 2
}
```

**Controlla i log del server** per vedere:
```
⚠️  [AUTO-CHECKOUT] Trovati 2 dipendenti ancora IN:
   ✓ Mario Rossi - Cantiere A - OUT automatico alle 23:59:59
   ✓ Luigi Verdi - Cantiere B - OUT automatico alle 23:59:59

📊 [AUTO-CHECKOUT] Riepilogo:
   ✓ Processati: 2
   ❌ Falliti: 0
   📅 Timestamp: 2025-10-21T23:59:59.999
```

---

## 🐛 Possibili Cause del Problema

### 1. **Server non in esecuzione alle 00:01**
- Il Raspberry si è riavviato?
- Il servizio è crashato?
- **Verifica**: `sudo systemctl status ingresso-uscita`

### 2. **Timezone non corretta**
- Il cron usa `timezone: "Europe/Rome"`
- Se il sistema è impostato su UTC, il cron si attiva alle 22:01 (ora italiana)
- **Verifica**: `timedatectl`

### 3. **Nessun dipendente idoneo**
- Tutti i dipendenti avevano `allowNightShift = 1`?
- Tutti avevano già timbrato OUT?
- **Verifica**: Usa endpoint debug

### 4. **Query SQL non funzionante**
- Errore nel database?
- Tabelle corrotte?
- **Verifica**: Controlla log per errori SQL

### 5. **node-cron non attivo**
- Libreria non installata correttamente?
- **Verifica**: `npm list node-cron` nel server

---

## 📋 Procedura Completa di Test OGGI

**Alle 23:55 di stasera**:

1. Assicurati che ci sia almeno 1 dipendente con:
   - Ultima timbratura = IN
   - `allowNightShift = 0` o `NULL`
   - `isActive = 1`

2. Tieni aperto il terminale sul Raspberry con:
   ```bash
   sudo journalctl -u ingresso-uscita -f
   ```

3. **Alle 00:01** dovresti vedere:
   ```
   ⏰ [CRON] Job auto-checkout avviato alle 22/10/2025, 00:01:00
   🕐 [AUTO-CHECKOUT] Avvio controllo timbrature aperte...
   ⚠️  [AUTO-CHECKOUT] Trovati X dipendenti ancora IN:
   ...
   ```

4. **Alle 00:02** verifica nel database:
   ```bash
   sqlite3 /percorso/database.db
   SELECT * FROM attendance_records WHERE isForced = 1 AND timestamp LIKE '2025-10-21%23:59:59%' ORDER BY id DESC LIMIT 5;
   ```

---

## 🔧 Riavvio Server con Modifiche

Dopo aver aggiornato il codice:

```bash
cd ~/ingresso-uscita/server
sudo systemctl restart ingresso-uscita
sudo systemctl status ingresso-uscita
sudo journalctl -u ingresso-uscita -n 50
```

---

## 📞 Se il Problema Persiste

Fornisci questi dati per diagnosi:

1. Output di `timedatectl`
2. Output di `sudo systemctl status ingresso-uscita`
3. Log completo: `sudo journalctl -u ingresso-uscita --since "00:00" --until "00:10"`
4. Risposta dell'endpoint debug: `/api/admin/debug-auto-checkout`
5. Numero di dipendenti che dovevano essere processati (ultima timbratura IN + no night shift)

---

## ✅ Codice Aggiornato

- `server/server.js` - Linea 206-209: Timestamp corretto con millisecondi
- `server/server.js` - Linea 492-533: Nuovo endpoint debug
- `server/server.js` - Linea 269-283: Log migliorati con prossima esecuzione

**Prossimi passi**: Riavvia il server e testa stanotte!
