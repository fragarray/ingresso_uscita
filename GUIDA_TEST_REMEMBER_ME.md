# Guida Test: Funzionalità "Ricorda Credenziali"

## Test da eseguire

### Test 1: Login con "Ricorda credenziali" attivo

**Passi:**
1. Avvia l'app
2. Inserisci email e password valide
3. Attiva la checkbox "Ricorda le credenziali"
4. Clicca "Login"
5. Verifica che l'accesso avvenga correttamente
6. Chiudi completamente l'app
7. Riavvia l'app

**Risultato atteso:**
- All'apertura dell'app dovrebbe apparire solo il logo e un indicatore di caricamento circolare
- Dopo pochi secondi, dovresti essere automaticamente loggato senza dover inserire le credenziali

---

### Test 2: Logout e riapertura

**Passi:**
1. Dopo aver effettuato il login con "Ricorda credenziali" attivo (Test 1)
2. Clicca il pulsante di logout
3. Verifica di essere tornato alla pagina di login
4. I campi email e password dovrebbero essere pre-compilati
5. Chiudi completamente l'app
6. Riavvia l'app

**Risultato atteso:**
- NON dovrebbe avvenire l'auto-login
- Dovrebbe apparire la pagina di login normale
- I campi email e password dovrebbero essere pre-compilati con le credenziali salvate
- La checkbox "Ricorda le credenziali" dovrebbe essere attiva

---

### Test 3: Login senza "Ricorda credenziali"

**Passi:**
1. Assicurati di aver eseguito un logout (se necessario)
2. Cancella il contenuto dei campi email e password
3. Inserisci email e password valide
4. NON attivare la checkbox "Ricorda le credenziali"
5. Clicca "Login"
6. Verifica che l'accesso avvenga correttamente
7. Chiudi completamente l'app
8. Riavvia l'app

**Risultato atteso:**
- All'apertura dell'app dovrebbe apparire immediatamente la pagina di login normale
- I campi email e password dovrebbero essere vuoti
- La checkbox "Ricorda le credenziali" dovrebbe essere disattivata

---

### Test 4: Credenziali non più valide

**Passi:**
1. Effettua login con "Ricorda credenziali" attivo
2. Chiudi l'app
3. Vai nel database del server e cambia la password dell'utente
4. Riavvia l'app

**Risultato atteso:**
- L'app tenta l'auto-login (mostra logo e caricamento)
- L'auto-login fallisce
- Viene mostrata la pagina di login normale
- I campi email e password dovrebbero essere pre-compilati
- L'auto-login è disabilitato per i successivi avvii fino a un nuovo login manuale

---

### Test 5: Server non raggiungibile all'avvio

**Passi:**
1. Effettua login con "Ricorda credenziali" attivo
2. Chiudi l'app
3. Spegni il server o disconnetti la rete
4. Riavvia l'app

**Risultato atteso:**
- L'app tenta l'auto-login (mostra logo e caricamento)
- Dopo un timeout, viene mostrata la pagina di login normale
- I campi sono pre-compilati
- L'utente può riprovare manualmente quando la connessione è ripristinata

---

### Test 6: Cambia stato checkbox durante il login

**Passi:**
1. Effettua login con "Ricorda credenziali" attivo
2. Esegui logout
3. I campi sono pre-compilati
4. Disattiva la checkbox "Ricorda le credenziali"
5. Clicca "Login"
6. Chiudi l'app
7. Riavvia l'app

**Risultato atteso:**
- All'apertura dell'app dovrebbe apparire la pagina di login normale
- I campi email e password dovrebbero essere VUOTI
- Le credenziali precedentemente salvate sono state eliminate

---

### Test 7: Click sul testo "Ricorda le credenziali"

**Passi:**
1. Nella pagina di login, clicca sul testo "Ricorda le credenziali" (non sulla checkbox)

**Risultato atteso:**
- La checkbox dovrebbe attivarsi/disattivarsi come se si fosse cliccato sulla checkbox stessa

---

### Test 8: Disabilita checkbox durante il caricamento

**Passi:**
1. Inserisci credenziali valide
2. Clicca "Login"
3. Mentre l'indicatore di caricamento è visibile, prova a cliccare sulla checkbox

**Risultato atteso:**
- La checkbox non dovrebbe essere cliccabile durante il caricamento
- Anche il testo "Ricorda le credenziali" non dovrebbe essere cliccabile

---

## Verifica dati salvati

Per verificare che i dati siano correttamente salvati, puoi:

1. **Android**: Usa Device File Explorer in Android Studio
   - Percorso: `/data/data/com.yourapp.package/shared_prefs/FlutterSharedPreferences.xml`

2. **Windows**: Cerca il file delle preferenze in:
   - `%APPDATA%\com.yourapp\shared_preferences\`

3. **Controlla i seguenti valori**:
   - `flutter.saved_email`: email salvata
   - `flutter.saved_password`: password salvata
   - `flutter.remember_me`: true/false
   - `flutter.auto_login`: true/false

---

## Comportamento atteso in sintesi

| Azione | remember_me | auto_login | Email/Password salvate |
|--------|-------------|------------|------------------------|
| Login con checkbox ON | ✅ true | ✅ true | ✅ Salvate |
| Login con checkbox OFF | ❌ false | ❌ false | ❌ Cancellate |
| Logout manuale | ✅ (invariato) | ❌ false | ✅ (invariate) |
| Auto-login fallito | ✅ (invariato) | ❌ false | ✅ (invariate) |

---

## Note

- L'auto-login viene disabilitato SOLO in caso di logout manuale o credenziali non valide
- Le credenziali rimangono salvate anche dopo il logout (per pre-compilare i campi)
- Per cancellare completamente le credenziali salvate, devi fare login con checkbox disattivata
