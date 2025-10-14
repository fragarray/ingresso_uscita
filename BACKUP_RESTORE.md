# Sistema Backup e Restore Database

## Funzionalità

### Backup Automatico
- Configurabile da 3, 7, 15 o 30 giorni
- Il server controlla ogni 24 ore se è necessario un nuovo backup
- I backup vengono salvati nella cartella `server/backups/`

### Backup Manuale
- Crea backup immediato tramite pulsante "Crea Backup Ora"
- Dopo la creazione, l'app chiede se scaricare il backup localmente
- I backup scaricati vengono salvati nella cartella Documenti del dispositivo

### Ripristino Database
- **ATTENZIONE**: Sostituisce TUTTI i dati correnti
- Accetta qualsiasi file con estensione `.db`
- Validazione automatica della struttura del database

## Come Ripristinare un Backup

1. **Accedi come Admin** all'applicazione
2. Vai al tab **Impostazioni**
3. Scorri fino alla sezione "Backup Database"
4. Clicca su **"Ripristina da Backup"** (pulsante arancione)
5. Seleziona il file `.db` dal tuo computer
6. Conferma l'operazione (leggi attentamente l'avviso)
7. Attendi il completamento del ripristino
8. Il server si riavvierà automaticamente
9. L'app tornerà alla schermata di login

## Validazione Database

Il server verifica automaticamente che il file caricato:
- Sia un database SQLite valido
- Contenga le tabelle richieste: `employees`, `work_sites`, `attendance`
- Abbia le colonne necessarie nella tabella `employees`

Se la validazione fallisce, il file viene rifiutato e viene mostrato un messaggio di errore specifico.

## Sicurezza

- **Backup automatico pre-restore**: Prima di sostituire il database corrente, viene creato automaticamente un backup con nome `pre_restore_backup_[timestamp].db`
- Questo backup è accessibile dalla lista "Backup Esistenti" e può essere scaricato o utilizzato per annullare un restore

## Gestione Backup Esistenti

Ogni backup nella lista mostra:
- Nome file (con timestamp)
- Dimensione
- Data di creazione
- Azioni:
  - **Download**: Scarica il backup localmente
  - **Elimina**: Rimuove il backup dal server

## Posizione File

- **Server**: `server/backups/`
- **Download locali**: Cartella Documenti del dispositivo
- **Database corrente**: `server/database.db`

## Limitazioni

- Dimensione massima file upload: 100MB
- Solo file con estensione `.db` sono accettati
- Il server deve essere riavviato dopo il restore (automatico)

## Note Tecniche

- Il restore chiude la connessione corrente al database
- Il processo Node.js esce con codice 0 dopo il restore
- Assicurati di avere un process manager (nodemon/pm2) che riavvii automaticamente il server
- L'UI dell'app viene automaticamente aggiornata tramite logout dopo il restore
