# Nuove Funzionalità - Aggiornamento

## 📡 Verifica Server dalla Pagina di Login

### Descrizione
È stato aggiunto un pulsante discreto nella pagina di login per verificare la connessione al server predefinito.

### Come Funziona

#### Pulsante "Verifica Server"
- **Posizione**: In basso nella pagina di login, sotto il pulsante di login principale
- **Aspetto**: Testo grigio piccolo con icona cloud, molto discreto
- **Funzione**: Verifica se il server predefinito è raggiungibile

#### Flusso di Verifica

1. **Server Raggiungibile**
   - Messaggio verde: "Server raggiungibile: [messaggio del server]"
   - Nessuna azione richiesta

2. **Server NON Raggiungibile**
   - Si apre automaticamente un dialog per configurare un nuovo IP
   - L'utente può inserire un nuovo indirizzo IP o hostname
   - Esempio: `192.168.1.100` o `server.local` o `fragarray.freeddns.it`

3. **Verifica Nuovo Server**
   - Cliccando "Verifica", il sistema testa il nuovo indirizzo
   - Se raggiungibile: l'IP viene salvato automaticamente come predefinito
   - Se non raggiungibile: messaggio di errore con dettagli

### Vantaggi

✅ **Prima Installazione Semplificata**
- Non serve più accedere alle Impostazioni per configurare il server
- Tutto dalla schermata di login

✅ **Diagnostica Rapida**
- Verifica immediata dello stato del server
- Messaggi di errore dettagliati

✅ **Configurazione Automatica**
- Una volta verificato, il nuovo IP viene salvato automaticamente
- Non serve riavviare l'app

### Messaggi Possibili

| Situazione | Messaggio |
|------------|-----------|
| ✅ Server OK | "Server raggiungibile: Ingresso/Uscita Server" |
| ❌ Connessione rifiutata | "Impossibile raggiungere il server (connessione rifiutata)" |
| ⏱️ Timeout | "Timeout: il server non risponde entro 5 secondi" |
| 🔍 Server sbagliato | "Server non riconosciuto (identità non valida)" |

---

## 🗺️ Ricerca Indirizzo nella Mappa

### Descrizione
Aggiunta una barra di ricerca nella pagina dei cantieri per trovare e centrare la mappa su un indirizzo specifico.

### Posizione
- **Top della mappa**: Barra bianca con ombra in alto
- **Sempre visibile**: Non interferisce con altre funzionalità

### Come Utilizzare

#### Metodo 1: Ricerca con Enter
1. Clicca nella barra di ricerca
2. Digita un indirizzo (es. "Via Roma 10, Milano")
3. Premi **Enter**
4. La mappa si centra sull'indirizzo con zoom 15

#### Metodo 2: Ricerca con Pulsante
1. Digita l'indirizzo nella barra
2. Clicca il pulsante **"Vai all'indirizzo"** (icona navigazione)
3. La mappa si centra sull'indirizzo

### Esempi di Indirizzi Validi

✅ **Indirizzo Completo**
```
Via Roma 10, 20100 Milano, Italy
```

✅ **Indirizzo Parziale**
```
Piazza del Duomo, Milano
```

✅ **Solo Città**
```
Roma, Italy
```

✅ **Coordinate**
```
41.9028, 12.4964
```

✅ **Luogo Famoso**
```
Colosseo, Roma
```

### Livello di Zoom

Quando un indirizzo viene trovato, la mappa si centra con:
- **Zoom 15**: Livello ideale per vedere edifici e strade
- Abbastanza vicino per identificare la posizione esatta
- Abbastanza lontano per vedere il contesto circostante

### Feedback Visivo

#### Durante la Ricerca
- 🔄 Indicatore di caricamento circolare al posto del pulsante

#### Ricerca Completata
- ✅ **Successo**: Snackbar verde "Indirizzo trovato!"
- ⚠️ **Indirizzo non trovato**: Snackbar arancione "Indirizzo non trovato"
- ❌ **Errore**: Snackbar rosso con dettagli dell'errore

### Casi d'Uso

#### 1. Aggiungere un Nuovo Cantiere in Posizione Specifica
```
1. Digita l'indirizzo del cantiere nella barra di ricerca
2. Clicca il pulsante di navigazione
3. La mappa si centra sull'indirizzo
4. Clicca il pulsante "+" per aggiungere un cantiere
5. Tocca la posizione esatta sulla mappa
6. Salva il cantiere
```

#### 2. Verificare la Posizione di un Indirizzo
```
1. Inserisci l'indirizzo da verificare
2. La mappa mostra la posizione esatta
3. Verifica che sia corretta osservando i dintorni
```

#### 3. Navigare Rapidamente tra Diverse Zone
```
1. Cerca "Milano Centro"
2. Aggiungi un cantiere
3. Cerca "Roma Termini"
4. Aggiungi un altro cantiere
5. Tutti i cantieri rimangono visibili sulla mappa
```

### Integrazione con Altre Funzionalità

#### Modalità Aggiunta Cantiere
- La barra di ricerca è **sempre disponibile**
- Anche in modalità "Aggiungi Cantiere", puoi cercare un indirizzo
- Il messaggio di istruzioni viene spostato più in basso per non sovrapporsi

#### Lista Cantieri Esistenti
- I marker dei cantieri esistenti rimangono visibili
- Puoi cercare un indirizzo e confrontarlo con i cantieri esistenti
- Utile per verificare se un nuovo cantiere è troppo vicino ad uno esistente

---

## 🔧 Modifiche Tecniche

### File Modificati

#### `lib/services/api_service.dart`
- **Nuovo metodo**: `getDefaultServerIp()`
  - Estrae l'IP/hostname dalla costante `_defaultBaseUrl`
  - Usato dal pulsante "Verifica Server"

#### `lib/pages/login_page.dart`
- **Nuova variabile**: `_isCheckingServer`
  - Traccia lo stato della verifica server
  
- **Nuovo metodo**: `_checkServerConnection()`
  - Verifica il server predefinito
  - Apre il dialog di configurazione se non raggiungibile

- **Nuovo metodo**: `_showServerConfigDialog()`
  - Dialog per inserire un nuovo IP server
  - Include validazione input

- **Nuovo metodo**: `_testAndSaveServer(String ip)`
  - Testa la connessione al nuovo IP
  - Salva automaticamente se raggiungibile

- **Nuovo widget**: Pulsante "Verifica Server"
  - TextButton discreto in grigio
  - Icona cloud outline
  - Loading indicator durante la verifica

#### `lib/widgets/work_sites_tab.dart`
- **Nuova variabile**: `_addressSearchController`
  - Controller per il campo di ricerca indirizzo

- **Nuova variabile**: `_isSearchingAddress`
  - Traccia lo stato della ricerca

- **Nuovo metodo**: `_searchAndCenterAddress()`
  - Cerca l'indirizzo usando geocoding
  - Centra la mappa con zoom 15
  - Gestisce errori e feedback

- **Nuovo widget**: Barra di ricerca
  - Card con elevation 4
  - TextField per input indirizzo
  - IconButton per trigger ricerca
  - Loading indicator durante ricerca

### Dipendenze Utilizzate

#### Già Presenti
- `geocoding: ^3.0.0` - Conversione indirizzo → coordinate
- `latlong2` - Gestione coordinate geografiche
- `flutter_map` - Visualizzazione mappa
- `shared_preferences` - Salvataggio configurazioni

---

## 📊 Testing

### Test Login - Verifica Server

#### Test 1: Server Predefinito Raggiungibile
```
1. Avvia l'app
2. Clicca "Verifica Server"
3. Attendi 1-2 secondi
4. ✅ Dovresti vedere: "Server raggiungibile: Ingresso/Uscita Server"
```

#### Test 2: Server Predefinito Non Raggiungibile
```
1. Spegni il server (o cambia IP predefinito a uno invalido)
2. Avvia l'app
3. Clicca "Verifica Server"
4. ✅ Dovresti vedere: Dialog "Configura Server"
5. Inserisci IP corretto (es. 192.168.1.100)
6. Clicca "Verifica"
7. ✅ Dovresti vedere: "Server configurato: Ingresso/Uscita Server"
```

#### Test 3: IP Non Valido
```
1. Clicca "Verifica Server"
2. Inserisci IP sbagliato (es. 192.168.1.999)
3. Clicca "Verifica"
4. ✅ Dovresti vedere errore rosso con dettagli
```

### Test Mappa - Ricerca Indirizzo

#### Test 1: Ricerca Indirizzo Valido
```
1. Vai alla pagina Cantieri
2. Digita "Colosseo, Roma" nella barra di ricerca
3. Premi Enter (o clicca pulsante navigazione)
4. ✅ La mappa dovrebbe centrarsi sul Colosseo con zoom 15
5. ✅ Snackbar verde: "Indirizzo trovato!"
```

#### Test 2: Ricerca Indirizzo Non Trovato
```
1. Digita "indirizzo che non esiste xyz123"
2. Premi Enter
3. ✅ Snackbar arancione: "Indirizzo non trovato"
4. ✅ La mappa NON dovrebbe muoversi
```

#### Test 3: Ricerca Durante Aggiunta Cantiere
```
1. Clicca il pulsante "+" per aggiungere un cantiere
2. Digita un indirizzo nella barra di ricerca
3. Premi Enter
4. ✅ La mappa si centra sull'indirizzo
5. ✅ Il messaggio "Tocca un punto sulla mappa..." è visibile più in basso
6. Tocca la mappa per posizionare il cantiere
```

#### Test 4: Ricerche Multiple
```
1. Cerca "Milano"
2. Attendi che la mappa si centri
3. Cerca "Roma"
4. Attendi che la mappa si centri
5. ✅ Ogni ricerca dovrebbe centrare correttamente la mappa
```

---

## 🎨 UI/UX

### Login Page

#### Prima
```
┌─────────────────────────────┐
│   Sistema Timbratura         │
├─────────────────────────────┤
│                              │
│        Benvenuto             │
│                              │
│   ┌──────────────────────┐  │
│   │ Email                │  │
│   └──────────────────────┘  │
│                              │
│   ┌──────────────────────┐  │
│   │ Password             │  │
│   └──────────────────────┘  │
│                              │
│   ┌──────────────────────┐  │
│   │       Login          │  │
│   └──────────────────────┘  │
│                              │
└─────────────────────────────┘
```

#### Dopo
```
┌─────────────────────────────┐
│   Sistema Timbratura         │
├─────────────────────────────┤
│                              │
│        Benvenuto             │
│                              │
│   ┌──────────────────────┐  │
│   │ Email                │  │
│   └──────────────────────┘  │
│                              │
│   ┌──────────────────────┐  │
│   │ Password             │  │
│   └──────────────────────┘  │
│                              │
│   ┌──────────────────────┐  │
│   │       Login          │  │
│   └──────────────────────┘  │
│                              │
│   🌐 Verifica Server         │ ← NUOVO (discreto)
│                              │
└─────────────────────────────┘
```

### Work Sites Map

#### Prima
```
┌─────────────────────────────────────┐
│ [Mappa con cantieri]                 │
│                                      │
│  📍 Cantiere A                       │
│     📍 Cantiere B                    │
│                                      │
│                         [+] Aggiungi │
└─────────────────────────────────────┘
```

#### Dopo
```
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │ ← NUOVO
│ │ 🔍 Cerca indirizzo... | ➤       │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Mappa con cantieri]                 │
│                                      │
│  📍 Cantiere A                       │
│     📍 Cantiere B                    │
│                                      │
│                         [+] Aggiungi │
└─────────────────────────────────────┘
```

---

## 💡 Suggerimenti d'Uso

### Scenario 1: Prima Installazione su Nuovo Dispositivo
```
1. Installa l'app
2. Apri l'app
3. Nella pagina di login, clicca "Verifica Server"
4. Se il server predefinito non è raggiungibile:
   - Inserisci l'IP corretto del tuo server
   - Clicca "Verifica"
5. Login normale con le tue credenziali
6. ✅ Pronto all'uso!
```

### Scenario 2: Aggiungere Cantiere da Indirizzo Conosciuto
```
1. Vai alla pagina Cantieri
2. Cerca l'indirizzo del nuovo cantiere
3. La mappa si centra sulla posizione
4. Clicca "+" per entrare in modalità aggiunta
5. Tocca la posizione esatta
6. Salva con nome e raggio
7. ✅ Cantiere aggiunto alla posizione corretta!
```

### Scenario 3: Server Cambia IP
```
1. Il server è stato spostato su un nuovo IP
2. L'app non riesce più a connettersi
3. Nella pagina di login, clicca "Verifica Server"
4. Inserisci il nuovo IP
5. Clicca "Verifica"
6. ✅ IP salvato automaticamente, login funziona di nuovo
```

---

## 🔮 Possibili Sviluppi Futuri

### Login Page
- [ ] Memorizzare ultimi 3 IP usati per selezione rapida
- [ ] QR Code per configurazione server (scansiona invece di digitare)
- [ ] Auto-discovery del server nella rete locale (mDNS/Bonjour)

### Mappa
- [ ] Suggerimenti automatici durante la digitazione (autocomplete)
- [ ] Cronologia delle ricerche recenti
- [ ] Bookmark degli indirizzi usati frequentemente
- [ ] Routing: calcolare percorso tra cantieri
- [ ] Visualizzare traffico in tempo reale

---

## 📝 Note per Sviluppatori

### Modificare l'IP Predefinito

In `lib/services/api_service.dart`, linea 13:
```dart
static const String _defaultBaseUrl = 'http://INDIRIZZO:3000/api';
```

Cambia `INDIRIZZO` con:
- IP locale: `192.168.1.100`
- Hostname: `server.local`
- DDNS: `fragarray.freeddns.it`
- Localhost: `localhost` (solo per testing locale)

### Modificare il Livello di Zoom della Ricerca

In `lib/widgets/work_sites_tab.dart`, metodo `_searchAndCenterAddress()`:
```dart
_mapController.move(position, 15.0); // Cambia 15.0 con il valore desiderato
```

Valori suggeriti:
- `13.0` - Zoom città (veduta ampia)
- `15.0` - Zoom quartiere (default)
- `17.0` - Zoom strada (veduta stretta)
- `19.0` - Zoom edificio (massimo dettaglio)

### Timeout Verifica Server

In `lib/services/api_service.dart`, metodo `pingServer()`:
```dart
).timeout(const Duration(seconds: 5)); // Cambia 5 per aumentare/diminuire timeout
```

---

## ✅ Checklist Pre-Release

- [x] Pulsante verifica server nella login page
- [x] Dialog configurazione IP server
- [x] Validazione e test connessione server
- [x] Salvataggio automatico IP valido
- [x] Barra ricerca indirizzo nella mappa
- [x] Geocoding indirizzo → coordinate
- [x] Centratura automatica mappa
- [x] Zoom adeguato (15.0)
- [x] Feedback visivo (loading, snackbar)
- [x] Gestione errori
- [x] Testing completo
- [x] Documentazione aggiornata

---

**Data Implementazione**: 15 Ottobre 2025  
**Versione**: 2.1.0  
**Autore**: GitHub Copilot
