# Configurazione Indirizzo Server

## Funzionalità

L'applicazione permette di configurare dinamicamente l'indirizzo IP del server dall'interfaccia utente, senza dover ricompilare l'app.

## Come Cambiare l'Indirizzo del Server

1. **Accedi come Admin** all'applicazione
2. Vai al tab **Impostazioni**
3. Nella sezione "Indirizzo Server" in alto:
   - Inserisci il nuovo indirizzo IP nel campo di testo (solo IP, non includere `http://` o la porta)
   - Esempio: `192.168.1.100` o `10.0.0.5`
4. Clicca su **"Testa e Salva"**
5. Il sistema eseguirà un test di connessione:
   - Se il server risponde correttamente, l'indirizzo verrà salvato
   - Altrimenti verrà mostrato un messaggio di errore specifico

## Test di Connessione

Il test verifica:
- ✅ **Raggiungibilità**: Il server è accessibile dalla rete
- ✅ **Identità**: Il server risponde con l'identificativo corretto `ingresso-uscita-server`
- ✅ **Versione**: Mostra la versione del server (informativa)
- ✅ **Timeout**: Se il server non risponde entro 5 secondi, viene segnalato

## Messaggi di Errore

| Errore | Significato | Soluzione |
|--------|-------------|-----------|
| "Impossibile raggiungere il server" | Il server non è accessibile dalla rete | Verifica che il server sia in esecuzione e che l'IP sia corretto |
| "Timeout: il server non risponde entro 5 secondi" | Il server è troppo lento o non risponde | Verifica la connessione di rete e lo stato del server |
| "Server non riconosciuto (identità non valida)" | L'IP punta a un server diverso | Assicurati di inserire l'IP del server Ingresso/Uscita |
| "Server risponde con codice XXX" | Errore HTTP | Controlla i log del server per dettagli |

## Persistenza

- L'indirizzo IP viene salvato in **SharedPreferences**
- Rimane memorizzato anche dopo il riavvio dell'app
- Il valore predefinito è `192.168.1.2` se non è stato configurato alcun IP

## Endpoint di Validazione

Il server espone l'endpoint `/api/ping` che restituisce:

```json
{
  "success": true,
  "message": "Ingresso/Uscita Server",
  "version": "1.0.0",
  "timestamp": "2025-10-14T18:30:00.000Z",
  "serverIdentity": "ingresso-uscita-server"
}
```

Questo garantisce che l'app si connetta solo al server corretto.

## Note Tecniche

- **Porta fissa**: La porta è hardcoded a `3000` (non modificabile dall'UI)
- **Protocollo**: Usa sempre `http://` (non HTTPS per reti locali)
- **Cache**: L'URL viene cachato in memoria per evitare letture continue da SharedPreferences
- **Dinamico**: Tutte le chiamate API usano `await getBaseUrl()` per ottenere l'URL corrente

## Sicurezza

- Il test di connessione non invia credenziali
- Verifica solo l'identità del server tramite un campo specifico (`serverIdentity`)
- Non è possibile connettersi accidentalmente a server non autorizzati

## Utilizzo

Questa funzionalità è utile quando:
- Il server cambia indirizzo IP sulla rete locale
- Si vuole testare con un server di sviluppo diverso
- Si migra il server su una nuova macchina
- Si hanno più server in ambienti diversi (produzione/test)
