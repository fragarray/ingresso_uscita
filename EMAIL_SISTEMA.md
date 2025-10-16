# Sistema Invio Email Automatico

## Descrizione
Sistema per l'invio automatico giornaliero del report completo delle timbrature a tutti gli amministratori via email.

## Funzionalità Implementate

### 1. Invio Automatico Giornaliero
- **Orario**: Ogni giorno alle **00:05** (5 minuti dopo mezzanotte)
- **Destinatari**: Tutti gli amministratori attivi (`isAdmin = 1`, `isActive = 1`)
- **Report**: Comprende TUTTI i cantieri e TUTTI i dipendenti
- **Periodo**: Solo il giorno precedente (es: alle 00:05 del 16, invia report del 15)

### 2. Configurazione Email
File: `server/email_config.json`

```json
{
  "emailEnabled": false,              // Abilita/disabilita invio email
  "smtpHost": "smtp.gmail.com",       // Server SMTP
  "smtpPort": 587,                    // Porta SMTP
  "smtpSecure": false,                // TLS (true per porta 465)
  "smtpUser": "your-email@gmail.com", // Email mittente
  "smtpPassword": "your-app-password",// Password app Gmail
  "fromEmail": "your-email@gmail.com",// Email mittente
  "fromName": "Sistema Timbrature",   // Nome mittente
  "dailyReportEnabled": true,         // Abilita report giornaliero
  "dailyReportTime": "00:05"          // Orario invio (non usato, hardcoded in cron)
}
```

## Setup Configurazione

### Opzione 1: Gmail (Consigliato)

1. **Abilita verifica in 2 passaggi** sul tuo account Google
   - Vai su: https://myaccount.google.com/security
   - Abilita "Verifica in 2 passaggi"

2. **Crea una password per l'app**
   - Vai su: https://myaccount.google.com/apppasswords
   - Seleziona "App: Posta" e "Dispositivo: Altro"
   - Inserisci "Sistema Timbrature"
   - Copia la password generata (16 caratteri)

3. **Configura il file `email_config.json`**:
   ```json
   {
     "emailEnabled": true,
     "smtpHost": "smtp.gmail.com",
     "smtpPort": 587,
     "smtpSecure": false,
     "smtpUser": "tuaemail@gmail.com",
     "smtpPassword": "la-password-app-a-16-caratteri",
     "fromEmail": "tuaemail@gmail.com",
     "fromName": "Sistema Timbrature Aziendale",
     "dailyReportEnabled": true,
     "dailyReportTime": "00:05"
   }
   ```

### Opzione 2: Altri Provider SMTP

#### Outlook/Hotmail
```json
{
  "smtpHost": "smtp-mail.outlook.com",
  "smtpPort": 587,
  "smtpSecure": false
}
```

#### Yahoo Mail
```json
{
  "smtpHost": "smtp.mail.yahoo.com",
  "smtpPort": 587,
  "smtpSecure": false
}
```

#### SMTP Personalizzato
```json
{
  "smtpHost": "mail.tuodominio.com",
  "smtpPort": 465,
  "smtpSecure": true
}
```

## API Endpoints

### 1. GET `/api/email/config`
Ottiene la configurazione email (senza password).

**Query Parameters:**
- `adminId`: ID dell'amministratore

**Response:**
```json
{
  "emailEnabled": true,
  "smtpHost": "smtp.gmail.com",
  "smtpPort": 587,
  "fromEmail": "tuaemail@gmail.com",
  "fromName": "Sistema Timbrature",
  "dailyReportEnabled": true
}
```

### 2. PUT `/api/email/config`
Aggiorna la configurazione email.

**Body:**
```json
{
  "adminId": 1,
  "config": {
    "emailEnabled": true,
    "smtpHost": "smtp.gmail.com",
    "smtpPort": 587,
    "smtpSecure": false,
    "smtpUser": "tuaemail@gmail.com",
    "smtpPassword": "password-app",
    "fromEmail": "tuaemail@gmail.com",
    "fromName": "Sistema Timbrature",
    "dailyReportEnabled": true
  }
}
```

### 3. POST `/api/email/test`
Invia email di test per verificare la configurazione.

**Body:**
```json
{
  "adminId": 1,
  "testEmail": "test@example.com"  // Opzionale, default: email admin
}
```

### 4. POST `/api/email/send-daily-report`
Invia manualmente il report giornaliero (per test).

**Body:**
```json
{
  "adminId": 1
}
```

## Funzionamento Automatico

### Processo Giornaliero (00:05)

1. **Controllo configurazione**
   - Verifica `emailEnabled = true`
   - Verifica `dailyReportEnabled = true`

2. **Ricerca amministratori**
   - Query: `SELECT * FROM employees WHERE isAdmin = 1 AND isActive = 1`
   - Raccoglie email di tutti gli admin attivi

3. **Calcolo date**
   - Data inizio: `00:00:00` del giorno precedente
   - Data fine: `23:59:59` del giorno precedente

4. **Generazione report**
   - Chiama `generateWorkSiteReport(null, null, startDate, endDate)`
   - `null` per cantiere = TUTTI i cantieri
   - `null` per dipendente = TUTTI i dipendenti
   - File salvato in `/reports/`

5. **Invio email**
   - Per ogni amministratore:
     - Crea email HTML professionale
     - Allega file Excel del report
     - Invia tramite SMTP configurato
   - Log dettagliato su console

### Log Console

```
⏰ [CRON] Job report giornaliero avviato alle 00:05
📧 [EMAIL] Avvio invio report giornaliero agli admin...
📋 [EMAIL] Trovati 3 amministratori
📅 [EMAIL] Generazione report per: 15/10/2025
✓ [EMAIL] Report generato: worksite_report_20251016_000500.xlsx (245.67 KB)
   ✓ Mario Rossi (mario.rossi@company.com)
   ✓ Laura Bianchi (laura.bianchi@company.com)
   ✓ Giovanni Verdi (giovanni.verdi@company.com)

📊 [EMAIL] Riepilogo invio:
   ✓ Inviati: 3
   ❌ Falliti: 0
   📎 Report: worksite_report_20251016_000500.xlsx
```

## Formato Email

### Oggetto
```
Report Giornaliero Timbrature - 15/10/2025
```

### Corpo (HTML)
- Header con gradiente viola/blu
- Saluto personalizzato con nome admin
- Descrizione del report
- Box informativo con dettagli:
  - 📅 Data
  - 📍 Cantieri: Tutti
  - 👥 Dipendenti: Tutti
  - 📎 Nome file allegato
- Footer con timestamp generazione

### Allegato
File Excel completo con:
- Riepilogo Cantiere
- Dettaglio Timbrature
- Statistiche Dipendenti
- Analisi Orari

## Test e Debug

### Test Manuale Completo

1. **Installa nodemailer**
   ```bash
   cd server
   npm install
   ```

2. **Configura email** (modifica `email_config.json`)

3. **Riavvia server**
   ```bash
   node server.js
   ```

4. **Test configurazione**
   ```bash
   curl -X POST http://localhost:3000/api/email/test \
     -H "Content-Type: application/json" \
     -d '{"adminId": 1}'
   ```

5. **Test invio report manuale**
   ```bash
   curl -X POST http://localhost:3000/api/email/send-daily-report \
     -H "Content-Type: application/json" \
     -d '{"adminId": 1}'
   ```

### Verifica Cron Job

Il cron job è attivo se vedi nel log:
```
✓ Scheduler report giornaliero attivato (esegue alle 00:05 ogni giorno)
```

### Troubleshooting

#### Email non inviate
1. Verifica `emailEnabled: true` in `email_config.json`
2. Verifica `dailyReportEnabled: true`
3. Controlla username/password SMTP corretti
4. Gmail: usa password app, non password account
5. Controlla log console per errori dettagliati

#### Report non generato
1. Verifica che ci siano timbrature nel giorno precedente
2. Controlla permessi scrittura cartella `/reports/`
3. Verifica database accessibile

#### Email ricevuta ma senza allegato
1. Controlla dimensione file (alcuni server hanno limiti)
2. Verifica path file report esistente
3. Controlla log per errori specifici

## Sicurezza

### Best Practices

1. **Mai committare password**
   - Aggiungi `email_config.json` a `.gitignore`
   - Usa variabili d'ambiente in produzione

2. **Protezione API**
   - Tutti gli endpoint richiedono `adminId`
   - Verifica `isAdmin = 1` su database
   - Password non ritornata in GET `/api/email/config`

3. **Gmail App Password**
   - Non usare password account principale
   - Usa password app dedicata
   - Revoca password se compromessa

### Esempio .gitignore
```
server/email_config.json
server/database.db
server/reports/*.xlsx
server/backups/*.db
```

## Monitoraggio

### Metriche da Monitorare

1. **Invii giornalieri**
   - Numero admin che ricevono email
   - Numero email fallite
   - Dimensione report

2. **Performance**
   - Tempo generazione report
   - Tempo invio email
   - Banda utilizzata

3. **Errori**
   - Errori SMTP
   - Report non generati
   - Email non consegnate

### Log Errors Comuni

```
❌ [EMAIL] Impossibile creare transporter (verifica configurazione SMTP)
→ Controlla email_config.json

⚠️  [EMAIL] Invio email disabilitato nella configurazione
→ Imposta emailEnabled: true

❌ [EMAIL] Nessun admin trovato
→ Crea almeno un utente amministratore

❌ [EMAIL] File report non trovato
→ Controlla generazione report e permessi cartella
```

## Estensioni Future

### Funzionalità Suggerite

1. **Email personalizzate**
   - Report per singolo cantiere
   - Report per responsabile di cantiere
   - Alert su anomalie specifiche

2. **Notifiche real-time**
   - Alert timbrature fuori orario
   - Notifica dipendenti che dimenticano OUT
   - Alert superamento ore straordinario

3. **Dashboard email**
   - Statistiche invii mensili
   - Tasso apertura email
   - Log storico invii

4. **Multi-template**
   - Template personalizzabili
   - Logo aziendale
   - Footer personalizzato

## Costi e Limiti

### Gmail
- **Gratuito**: 500 email/giorno
- **Workspace**: 2000 email/giorno
- **Dimensione allegati**: Max 25 MB

### Outlook
- **Gratuito**: 300 email/giorno
- **Dimensione allegati**: Max 20 MB

### SMTP Personalizzato
- Dipende dal provider
- Controllare limiti specifici

---
**Data implementazione**: 16 Ottobre 2025  
**Versione**: 1.0.0  
**Dipendenze**: nodemailer ^6.9.7
