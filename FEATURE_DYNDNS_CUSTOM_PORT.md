# 🌐 Supporto DynDNS e Porta Configurabile - Settings Tab

## 📋 **PANORAMICA**

Aggiornamento della tab Impostazioni per supportare:
1. **Nomi di dominio DynDNS** (oltre agli indirizzi IP)
2. **Porta del server configurabile** (non più hardcoded a 3000)

### **Problema Precedente**
- Il campo indirizzo server accettava **solo numeri** (`TextInputType.numberWithOptions`)
- Impossibile inserire domini DynDNS (es: `example.ddns.net`)
- La porta era **hardcoded** a `:3000` e non modificabile

### **Soluzione Implementata**
- Campo indirizzo server ora accetta **testo libero** (`TextInputType.text`)
- Aggiunto **campo porta separato** con validazione (1-65535)
- Supporto completo per IP locali, IP pubblici e domini DynDNS

---

## 🔧 **MODIFICHE TECNICHE**

### **1. File: `lib/pages/admin_page.dart`**

#### **Variabili di Stato Aggiunte**
```dart
// Prima (riga ~326)
final TextEditingController _serverIpController = TextEditingController();
String _currentServerIp = '192.168.1.2';

// Dopo
final TextEditingController _serverIpController = TextEditingController();
final TextEditingController _serverPortController = TextEditingController(); // NUOVO
String _currentServerIp = '192.168.1.2';
int _currentServerPort = 3000; // NUOVO
```

#### **Caricamento Settings (metodo `_loadServerIp`)**
```dart
// Prima (riga ~345)
Future<void> _loadServerIp() async {
  final prefs = await SharedPreferences.getInstance();
  final savedIp = prefs.getString('serverIp') ?? '192.168.1.2';
  setState(() {
    _currentServerIp = savedIp;
    _serverIpController.text = savedIp;
  });
}

// Dopo
Future<void> _loadServerIp() async {
  final prefs = await SharedPreferences.getInstance();
  final savedIp = prefs.getString('serverIp') ?? '192.168.1.2';
  final savedPort = prefs.getInt('serverPort') ?? 3000; // NUOVO
  setState(() {
    _currentServerIp = savedIp;
    _currentServerPort = savedPort; // NUOVO
    _serverIpController.text = savedIp;
    _serverPortController.text = savedPort.toString(); // NUOVO
  });
}
```

#### **Test e Salvataggio (metodo `_testAndSaveServerIp`)**

**Validazione Porta Aggiunta:**
```dart
// Valida porta (NUOVO)
final newPort = int.tryParse(portText);
if (newPort == null || newPort < 1 || newPort > 65535) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Porta non valida (deve essere tra 1 e 65535)'),
      backgroundColor: Colors.orange,
    ),
  );
  return;
}
```

**Test Connessione con Porta:**
```dart
// Prima
final result = await ApiService.pingServer(newIp);

// Dopo
final result = await ApiService.pingServer(newIp, newPort);
```

**Salvataggio IP e Porta:**
```dart
// Prima
await ApiService.setServerIp(newIp);
setState(() {
  _currentServerIp = newIp;
});

// Dopo
await ApiService.setServerIp(newIp);
await ApiService.setServerPort(newPort); // NUOVO
setState(() {
  _currentServerIp = newIp;
  _currentServerPort = newPort; // NUOVO
});
```

#### **UI - TextField Indirizzo Server**
```dart
// Prima (riga ~847)
TextField(
  controller: _serverIpController,
  decoration: InputDecoration(
    labelText: 'Indirizzo IP',
    hintText: '192.168.1.2',
    suffixText: ':3000', // Porta hardcoded
  ),
  keyboardType: TextInputType.numberWithOptions(decimal: true), // Solo numeri!
)

// Dopo
TextField(
  controller: _serverIpController,
  decoration: const InputDecoration(
    labelText: 'Indirizzo Server',
    hintText: 'es: 192.168.1.2 o example.ddns.net', // NUOVO esempio
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.dns), // Icona DNS
    helperText: 'IP o nome dominio', // NUOVO helper
  ),
  keyboardType: TextInputType.text, // ✅ Testo libero!
  autocorrect: false,
)
```

#### **UI - Campo Porta (NUOVO)**
```dart
TextField(
  controller: _serverPortController,
  decoration: const InputDecoration(
    labelText: 'Porta',
    hintText: '3000',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.power),
  ),
  keyboardType: TextInputType.number,
)
```

#### **UI - Layout Responsive**
```dart
Row(
  children: [
    Expanded(
      flex: 3, // 75% larghezza per indirizzo
      child: TextField(...), // Campo indirizzo
    ),
    const SizedBox(width: 12),
    Expanded(
      flex: 1, // 25% larghezza per porta
      child: TextField(...), // Campo porta
    ),
  ],
)
```

#### **UI - Pulsante Testa e Salva**
```dart
// Prima: inline nella Row
ElevatedButton.icon(...)

// Dopo: full-width sotto i campi
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    label: Text(_testingConnection 
      ? 'Test in corso...' 
      : 'Testa e Salva Configurazione'),
    ...
  ),
)
```

#### **UI - Info Server Corrente**
```dart
// Prima
Text('IP corrente: $_currentServerIp:3000')

// Dopo
Text('Server corrente: $_currentServerIp:$_currentServerPort')
```

---

## 🎯 **CASI D'USO**

### **1. Server su Rete Locale**
```
Indirizzo: 192.168.1.2
Porta: 3000
```
✅ Funziona come prima

### **2. Server con Porta Custom**
```
Indirizzo: 192.168.1.2
Porta: 8080
```
✅ Ora possibile modificare la porta

### **3. Server su IP Pubblico**
```
Indirizzo: 203.0.113.42
Porta: 3000
```
✅ Funziona con IP pubblici

### **4. Server con DynDNS**
```
Indirizzo: mioserver.ddns.net
Porta: 3000
```
✅ **NUOVO** - Supporto completo per domini

### **5. DynDNS con Porta Custom**
```
Indirizzo: example.freeddns.org
Porta: 8888
```
✅ **NUOVO** - Combinazione dominio + porta custom

---

## 🔒 **VALIDAZIONE**

### **Validazione Indirizzo**
```dart
if (newIp.isEmpty) {
  // Errore: campo vuoto
}
```
- Non viene fatta validazione di formato IP/dominio
- Accetta qualsiasi testo (IPv4, IPv6, domini, localhost)
- La validazione vera avviene nel test di connessione

### **Validazione Porta**
```dart
final newPort = int.tryParse(portText);
if (newPort == null || newPort < 1 || newPort > 65535) {
  // Errore: porta non valida
}
```
- Deve essere un numero intero
- Range valido: **1-65535** (range porte TCP/UDP)
- Porte comuni:
  - `3000` - Node.js/Express default
  - `8080` - HTTP alternativo
  - `80` - HTTP standard (richiede root su Linux)
  - `443` - HTTPS (richiede root su Linux)

### **Test Connessione**
```dart
final result = await ApiService.pingServer(newIp, newPort);

if (result['success'] == true) {
  // Verifica identità server
  if (data['serverIdentity'] == 'ingresso-uscita-server') {
    // ✅ Server valido
  } else {
    // ❌ Server non riconosciuto
  }
}
```

---

## 📱 **ESPERIENZA UTENTE**

### **Schermata Impostazioni**

```
┌─────────────────────────────────────────────┐
│ 🌐 Indirizzo Server                         │
│                                             │
│ Configura l'indirizzo del server (IP       │
│ locale, IP pubblico o nome dominio DynDNS)  │
│ e la porta. Il test verificherà che sia    │
│ raggiungibile.                              │
│                                             │
│ ┌─────────────────────┐ ┌────────────────┐ │
│ │ 🌐 Indirizzo Server │ │ ⚡ Porta       │ │
│ │ example.ddns.net    │ │ 3000          │ │
│ │ IP o nome dominio   │ └────────────────┘ │
│ └─────────────────────┘                     │
│                                             │
│ ┌───────────────────────────────────────┐   │
│ │ ✓ Testa e Salva Configurazione       │   │
│ └───────────────────────────────────────┘   │
│                                             │
│ ℹ️ Server corrente: example.ddns.net:3000  │
└─────────────────────────────────────────────┘
```

### **Feedback Visivo**

**Durante il test:**
- Pulsante mostra `CircularProgressIndicator`
- Label cambia in "Test in corso..."
- Pulsante disabilitato

**Test riuscito:**
```
✅ Connessione riuscita

Server: Ingresso/Uscita Server
Versione: 1.1.3

L'indirizzo del server è stato aggiornato.

[ OK ]
```

**Test fallito:**
```
❌ Connessione fallita

Impossibile raggiungere il server 
(connessione rifiutata)

[ OK ]
```

**Porta non valida:**
```
⚠️ Porta non valida (deve essere tra 1 e 65535)
```

---

## 🧪 **TESTING**

### **Test Case 1: IP Locale + Porta Default**
```
Input:
  Indirizzo: 192.168.1.2
  Porta: 3000

Expected:
  ✅ Test connessione riuscito
  ✅ Salvataggio in SharedPreferences
  ✅ ApiService.baseUrl aggiornato a http://192.168.1.2:3000/api
```

### **Test Case 2: DynDNS + Porta Default**
```
Input:
  Indirizzo: fragarray.freeddns.it
  Porta: 3000

Expected:
  ✅ Test connessione riuscito
  ✅ ApiService.baseUrl aggiornato a http://fragarray.freeddns.it:3000/api
```

### **Test Case 3: IP Locale + Porta Custom**
```
Input:
  Indirizzo: 192.168.1.2
  Porta: 8080

Expected:
  ✅ Test connessione riuscito
  ✅ ApiService.baseUrl aggiornato a http://192.168.1.2:8080/api
```

### **Test Case 4: DynDNS + Porta Custom**
```
Input:
  Indirizzo: example.ddns.net
  Porta: 5000

Expected:
  ✅ Test connessione riuscito
  ✅ ApiService.baseUrl aggiornato a http://example.ddns.net:5000/api
```

### **Test Case 5: Porta Non Valida**
```
Input:
  Indirizzo: 192.168.1.2
  Porta: abc

Expected:
  ❌ Errore: "Porta non valida"
  ❌ Nessun salvataggio
```

### **Test Case 6: Porta Fuori Range**
```
Input:
  Indirizzo: 192.168.1.2
  Porta: 99999

Expected:
  ❌ Errore: "Porta non valida"
```

### **Test Case 7: Indirizzo Vuoto**
```
Input:
  Indirizzo: (vuoto)
  Porta: 3000

Expected:
  ❌ Errore: "Inserisci un indirizzo server valido"
```

### **Test Case 8: Server Non Raggiungibile**
```
Input:
  Indirizzo: 10.0.0.99 (non esiste)
  Porta: 3000

Expected:
  ❌ Dialog errore: "Impossibile raggiungere il server"
```

---

## 🔄 **COMPATIBILITÀ CON CODICE ESISTENTE**

### **ApiService (lib/services/api_service.dart)**

Il servizio API **aveva già** supporto per porta configurabile:

```dart
// Metodo getBaseUrl (esistente)
static Future<String> getBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final savedIp = prefs.getString('serverIp');
  final savedPort = prefs.getInt('serverPort') ?? 3000; // ✅ Già presente
  
  _cachedBaseUrl = savedIp != null
      ? 'http://$savedIp:$savedPort/api'
      : _defaultBaseUrl;
  return _cachedBaseUrl!;
}

// Metodo setServerPort (esistente)
static Future<void> setServerPort(int port) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('serverPort', port);
  
  final savedIp = prefs.getString('serverIp');
  if (savedIp != null) {
    _cachedBaseUrl = 'http://$savedIp:$port/api';
  }
}

// Metodo pingServer (esistente)
static Future<Map<String, dynamic>> pingServer(String ip, [int? port]) async {
  final prefs = await SharedPreferences.getInstance();
  final serverPort = port ?? prefs.getInt('serverPort') ?? 3000; // ✅ Già presente
  
  final testUrl = 'http://$ip:$serverPort/api/ping';
  ...
}
```

✅ **Nessuna modifica necessaria** in ApiService - già pronto!

### **Login Page (lib/pages/login_page.dart)**

Il dialog di inserimento server nella login page **ancora usa solo IP**.

**TODO Futuro (opzionale):**
- Aggiornare anche il dialog nella login per accettare DynDNS
- Per ora funziona perché:
  1. La maggior parte degli utenti configura il server dalle Impostazioni
  2. Il dialog login è per setup iniziale (tipicamente IP locale)

---

## 📊 **MIGRAZIONE DATI**

### **Utenti Esistenti**

Gli utenti che già usano l'app:

**Dati in SharedPreferences:**
```dart
'serverIp': '192.168.1.2'
'serverPort': null // Mai salvato prima
```

**Comportamento Automatico:**
```dart
final savedPort = prefs.getInt('serverPort') ?? 3000; // Fallback a 3000
```

✅ **Nessuna migrazione necessaria** - porta default 3000 applicata automaticamente

### **Nuove Installazioni**

```dart
'serverIp': null
'serverPort': null
```

**Comportamento:**
- Usa `_defaultBaseUrl` che contiene già `fragarray.freeddns.it:3000`
- Al primo salvataggio, scrive sia IP che porta

---

## 🚀 **DEPLOY**

### **Checklist Pre-Deploy**

- [x] Modifiche codice completate
- [x] Validazione porta implementata (1-65535)
- [x] UI responsive (Row con Expanded flex: 3,1)
- [x] Test connessione con porta custom
- [x] Messaggio errore porta non valida
- [x] Info server corrente mostra porta
- [x] Documentazione creata
- [ ] Test su dispositivo Android
- [ ] Test con DynDNS reale
- [ ] Test con porta custom (es: 8080)

### **Istruzioni Build**

```bash
# Build APK release
flutter build apk --release

# Versione da aggiornare in pubspec.yaml
version: 1.1.4+4  # Incrementa per questa feature
```

---

## 📝 **NOTE IMPLEMENTATIVE**

### **Perché TextInputType.text e non URL?**

```dart
keyboardType: TextInputType.text,  // ✅ Scelta fatta
// keyboardType: TextInputType.url, // ❌ Non usato
```

**Motivazioni:**
- `TextInputType.url` su Android aggiunge tasti `.com`, `/`, `:` non sempre utili
- `TextInputType.text` è più versatile (IP, domini, localhost)
- Validazione vera avviene nel test connessione

### **Perché Non Validare Formato IP/Dominio?**

```dart
// Non facciamo questo:
if (!RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(newIp)) { ... }
if (!RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(newIp)) { ... }
```

**Motivazioni:**
- IPv4, IPv6, domini, localhost - troppi formati
- Regex complesse facilmente bypassabili
- `pingServer()` fa la validazione vera (può raggiungere il server?)
- Migliore UX: se funziona, va bene

### **Dispose Controllers**

```dart
@override
void dispose() {
  _serverIpController.dispose();
  _serverPortController.dispose(); // ⚠️ IMPORTANTE
  super.dispose();
}
```

⚠️ **Ricorda sempre di fare dispose dei TextEditingController** per evitare memory leak!

---

## 🎓 **ESEMPI CONFIGURAZIONE**

### **Scenario 1: Uso Domestico (Rete Locale)**

**Setup:**
- Raspberry Pi su rete locale: `192.168.1.10`
- Porta default: `3000`
- Dispositivi Android sulla stessa rete Wi-Fi

**Configurazione App:**
```
Indirizzo: 192.168.1.10
Porta: 3000
```

### **Scenario 2: Uso Aziendale (Rete Interna)**

**Setup:**
- Server aziendale: `10.0.5.20`
- Porta custom per sicurezza: `8888`
- Dipendenti su rete aziendale

**Configurazione App:**
```
Indirizzo: 10.0.5.20
Porta: 8888
```

### **Scenario 3: Accesso Remoto (DynDNS)**

**Setup:**
- Raspberry Pi a casa con DynDNS: `fragarray.freeddns.it`
- Router con port forwarding: `3000 -> 192.168.1.10:3000`
- Dipendenti in trasferta

**Configurazione App:**
```
Indirizzo: fragarray.freeddns.it
Porta: 3000
```

**Configurazione Router:**
```
External Port: 3000
Internal IP: 192.168.1.10
Internal Port: 3000
Protocol: TCP
```

### **Scenario 4: Server Cloud (VPS)**

**Setup:**
- VPS su cloud provider: `vps.example.com`
- Reverse proxy nginx porta 80 → 3000
- Accesso pubblico

**Configurazione App:**
```
Indirizzo: vps.example.com
Porta: 80
```

**Nginx Config:**
```nginx
server {
    listen 80;
    server_name vps.example.com;
    
    location /api {
        proxy_pass http://localhost:3000;
    }
}
```

---

## 🔐 **SICUREZZA**

### **Considerazioni**

1. **No HTTPS Validation**
   - Attualmente usa `http://` hardcoded
   - TODO futuro: supporto HTTPS per connessioni sicure

2. **Port Forwarding**
   - Se usi DynDNS, assicurati che il port forwarding sia configurato correttamente
   - Usa porte non standard per ridurre scan automatici (es: 8888 invece di 3000)

3. **Firewall**
   - Apri solo la porta necessaria sul server
   - Considera whitelist IP se possibile

4. **Validazione Server Identity**
   - Il ping verifica `serverIdentity === 'ingresso-uscita-server'`
   - Previene connessioni accidentali a server sbagliati

---

## ✅ **CONCLUSIONE**

Questa modifica porta il supporto completo per:
- ✅ DynDNS e nomi di dominio personalizzati
- ✅ Porte configurabili (non più hardcoded a 3000)
- ✅ Validazione robusta con feedback chiaro
- ✅ UI responsive e intuitiva
- ✅ Retrocompatibilità con configurazioni esistenti

**Nessuna breaking change** - le configurazioni esistenti continuano a funzionare con porta default 3000.
