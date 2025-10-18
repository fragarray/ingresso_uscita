# Feature: Ricorda Credenziali e Auto-Login

## Descrizione

Questa funzionalità permette all'utente di salvare le credenziali di login e di effettuare l'accesso automatico all'avvio dell'app.

## Modifiche Implementate

### 1. Pagina di Login (`lib/pages/login_page.dart`)

#### Nuovi campi di stato:
- `_rememberMe`: booleano per lo stato della checkbox "Ricorda credenziali"
- `_isAutoLoggingIn`: booleano per indicare quando è in corso un tentativo di auto-login

#### Nuovi metodi:

**`_loadSavedCredentials()`**
- Carica le credenziali salvate da SharedPreferences all'avvio
- Se "Ricorda credenziali" era attivo, pre-compila i campi email e password

**`_attemptAutoLogin()`**
- Tenta l'auto-login all'avvio dell'app
- Se le credenziali sono salvate e `auto_login` è abilitato:
  - Mostra solo il logo e un indicatore di caricamento circolare
  - Tenta il login automatico
  - Se fallisce (credenziali non valide o errore di rete), disabilita l'auto-login e mostra la pagina di login normale

**`_login()` (modificato)**
- Salva le credenziali e abilita l'auto-login se la checkbox "Ricorda credenziali" è attiva
- Rimuove le credenziali salvate se la checkbox non è attiva

#### UI modificata:

1. **Schermata di auto-login**:
   - Mostra solo il logo e un CircularProgressIndicator
   - Nessun campo di input visibile durante l'auto-login

2. **Checkbox "Ricorda le credenziali"**:
   - Posizionata sotto il campo password
   - Permette all'utente di scegliere se salvare le credenziali

### 2. State Management (`lib/main.dart`)

**Metodo `logout()` (modificato)**:
- Reso asincrono (`Future<void>`)
- Disabilita automaticamente l'auto-login quando si esegue un logout manuale
- Aggiorna SharedPreferences impostando `auto_login` a `false`

### 3. Chiamate al logout (aggiornate)

Aggiornate tutte le chiamate a `logout()` per gestire correttamente l'asincronicità:

- **`lib/pages/admin_page.dart`**:
  - Pulsante logout nell'AppBar
  - Dialog di conferma ripristino database
  - Dialog dopo ripristino database completato

- **`lib/pages/employee_page.dart`**:
  - Pulsante logout nell'AppBar

## Dati salvati in SharedPreferences

| Chiave | Tipo | Descrizione |
|--------|------|-------------|
| `saved_email` | String | Email dell'utente |
| `saved_password` | String | Password dell'utente (in chiaro) |
| `remember_me` | bool | Stato della checkbox "Ricorda credenziali" |
| `auto_login` | bool | Flag per abilitare/disabilitare l'auto-login |

## Comportamento

### Scenario 1: Login con "Ricorda credenziali" attivo
1. L'utente inserisce email e password
2. L'utente attiva la checkbox "Ricorda credenziali"
3. L'utente clicca "Login"
4. Le credenziali vengono salvate e `auto_login` viene impostato a `true`

### Scenario 2: Apertura app con credenziali salvate
1. L'app si apre
2. Mostra solo il logo e un indicatore di caricamento
3. Tenta l'auto-login con le credenziali salvate
4. Se ha successo: accede direttamente alla pagina principale
5. Se fallisce: disabilita auto-login e mostra la pagina di login

### Scenario 3: Logout manuale
1. L'utente clicca il pulsante di logout
2. Il flag `auto_login` viene impostato a `false`
3. Le credenziali rimangono salvate (ma non verrà effettuato auto-login)
4. Al prossimo accesso, i campi email/password saranno pre-compilati se "Ricorda credenziali" era attivo

### Scenario 4: Login senza "Ricorda credenziali"
1. L'utente inserisce email e password
2. La checkbox "Ricorda credenziali" rimane disattivata
3. L'utente clicca "Login"
4. Le credenziali NON vengono salvate
5. Al prossimo avvio, verrà mostrata la pagina di login normale

## Note di sicurezza

⚠️ **IMPORTANTE**: Le password sono salvate in chiaro in SharedPreferences. Questo è accettabile per un'app aziendale interna, ma per un'app pubblica si dovrebbe considerare:
- Utilizzo di `flutter_secure_storage` per cifrare le credenziali
- Implementazione di token JWT con refresh token
- Utilizzo di biometria (fingerprint/face ID) invece di salvare la password

## Test

Per testare la funzionalità:

1. **Test "Ricorda credenziali"**:
   - Effettua login con checkbox attiva
   - Riavvia l'app
   - Verifica che venga effettuato l'auto-login

2. **Test logout**:
   - Effettua auto-login
   - Esegui logout
   - Riavvia l'app
   - Verifica che NON venga effettuato l'auto-login (ma i campi sono pre-compilati)

3. **Test credenziali non valide**:
   - Effettua login con checkbox attiva
   - Cambia la password nel database
   - Riavvia l'app
   - Verifica che l'auto-login fallisca e mostri la pagina di login normale

4. **Test senza "Ricorda credenziali"**:
   - Effettua login con checkbox disattivata
   - Riavvia l'app
   - Verifica che venga mostrata la pagina di login con campi vuoti
