# 🚀 Guida Rapida Configurazione Email

## 📝 Passo 1: Cambiare Orario Invio Report

**File**: `server/server.js` (riga 15)

```javascript
const DAILY_REPORT_TIME = "00:05";  // ← MODIFICA QUI
```

**Esempi**:
- `"00:05"` → Mezzanotte e 5 minuti (default)
- `"08:00"` → 8 di mattina
- `"18:30"` → 6 e mezza di sera
- `"23:59"` → 1 minuto prima di mezzanotte

**Nota**: Usa sempre formato 24 ore con zero iniziale (es: `"08:00"` non `"8:00"`)

---

## 📧 Passo 2: Configurare Gmail

### A. Abilita Verifica in 2 Passaggi
1. Vai su: https://myaccount.google.com/security
2. Abilita "Verifica in 2 passaggi"

### B. Crea App Password
1. Vai su: https://myaccount.google.com/apppasswords
2. Seleziona:
   - **App**: Posta
   - **Dispositivo**: Altro (inserisci "Sistema Timbrature")
3. Clicca "Genera"
4. **Copia la password di 16 caratteri** (es: `abcd efgh ijkl mnop`)

### C. Configura email_config.json

**File**: `server/email_config.json`

```json
{
  "emailEnabled": true,
  "smtpHost": "smtp.gmail.com",
  "smtpPort": 587,
  "smtpSecure": false,
  "smtpUser": "tuaemail@gmail.com",           // ← LA TUA EMAIL GMAIL
  "smtpPassword": "abcd efgh ijkl mnop",       // ← APP PASSWORD (16 caratteri)
  "fromEmail": "tuaemail@gmail.com",           // ← STESSA EMAIL
  "fromName": "Sistema Timbrature Aziendale",  // ← Nome che vedranno i destinatari
  "dailyReportEnabled": true,
  "dailyReportTime": "00:05"
}
```

⚠️ **IMPORTANTE**: 
- Usa la **App Password** (16 caratteri), NON la password del tuo account Gmail
- Puoi copiare la password con o senza spazi (funzionano entrambi)

---

## 🧪 Passo 3: Test Configurazione

### A. Riavvia il Server

Se il server è già avviato, fermalo (Ctrl+C) e riavvialo:

```bash
cd server
node server.js
```

Dovresti vedere:
```
✓ Scheduler report giornaliero attivato (esegue alle 00:05 ogni giorno)
```

### B. Test Email Immediato

Apri un nuovo terminale PowerShell:

```powershell
# Test configurazione SMTP (invia email di test)
curl -X POST http://localhost:3000/api/email/test -H "Content-Type: application/json" -d '{\"adminId\": 1}'

# Test report giornaliero (invia report del giorno precedente)
curl -X POST http://localhost:3000/api/email/send-daily-report -H "Content-Type: application/json" -d '{\"adminId\": 1}'
```

### C. Verifica Email Ricevuta

Controlla la casella di posta degli admin. Dovresti ricevere:
- ✅ Email di test (con il primo comando)
- ✅ Email con report Excel allegato (con il secondo comando)

---

## 🔍 Troubleshooting

### ❌ "Error: Invalid login"
- Verifica che l'email sia corretta
- Assicurati di usare **App Password**, non password account
- Controlla di aver abilitato "Verifica in 2 passaggi"

### ❌ Email non arrivano
- Controlla la cartella Spam/Posta indesiderata
- Verifica che `emailEnabled: true` in `email_config.json`
- Controlla i log del server per errori

### ❌ "No admin found"
- Assicurati che nel database ci sia almeno un utente con `isAdmin = 1`
- Verifica che `adminId: 1` corrisponda a un admin valido

### ❌ Report non generato
- Controlla che ci siano timbrature nel giorno precedente
- Verifica permessi scrittura cartella `/reports/`

---

## 📅 Quando Vengono Inviate le Email?

**Automaticamente**: Ogni giorno all'orario configurato in `DAILY_REPORT_TIME`

**Cosa viene inviato**:
- Report Excel completo
- Tutti i cantieri
- Tutti i dipendenti
- Solo giorno precedente

**A chi viene inviato**:
- Tutti gli amministratori attivi (`isAdmin = 1`, `isActive = 1`)

---

## 🎯 Esempio Configurazione Completa

**server.js (riga 15)**:
```javascript
const DAILY_REPORT_TIME = "08:00";  // Invio alle 8 di mattina
```

**email_config.json**:
```json
{
  "emailEnabled": true,
  "smtpHost": "smtp.gmail.com",
  "smtpPort": 587,
  "smtpSecure": false,
  "smtpUser": "timbrature@company.com",
  "smtpPassword": "abcd efgh ijkl mnop",
  "fromEmail": "timbrature@company.com",
  "fromName": "Sistema Presenze Aziendali",
  "dailyReportEnabled": true,
  "dailyReportTime": "08:00"
}
```

Con questa configurazione:
- ✅ Email abilitate
- ✅ Invio automatico alle **08:00** ogni mattina
- ✅ Report del giorno precedente
- ✅ Inviato a tutti gli admin

---

## 🛡️ Sicurezza

⚠️ **NON committare** `email_config.json` su Git (è già in `.gitignore`)

✅ La App Password è sicura:
- Non dà accesso completo al tuo account
- Può essere revocata in qualsiasi momento
- Funziona solo per SMTP

---

## 📞 Supporto

Per problemi o domande, consulta la documentazione completa in `EMAIL_SISTEMA.md`.
