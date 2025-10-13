# 📱 Sistema Timbratura - Guida Rapida

## 🚀 Avvio del Sistema

### 1. Avviare il Server
```bash
cd server
npm install
npm start
```
Il server sarà disponibile su `http://localhost:3000`

### 2. Avviare l'App Flutter
```bash
flutter pub get
flutter run
```

## 👤 Credenziali Default

**Admin:**
- Email: `admin@example.com`
- Password: `admin123`

## 📍 Funzionalità Principali

### Per i Dipendenti

#### Timbratura Ingresso/Uscita
1. **Login** con le tue credenziali
2. **Seleziona il cantiere** dal menu a tendina
3. Verifica la distanza dal cantiere:
   - ✅ **Verde**: Sei nel raggio consentito (entro 100m)
   - ⚠️ **Arancione**: Sei fuori dal raggio (verrà richiesta conferma)
4. Premi **"TIMBRA INGRESSO"** o **"TIMBRA USCITA"**
5. Visualizza le tue **ultime 5 timbrature**

#### Info Utili
- L'app suggerisce automaticamente il cantiere più vicino
- Puoi vedere la distanza in tempo reale dal cantiere selezionato
- Le timbrature mostrano il cantiere associato nello storico

---

### Per gli Amministratori

L'area admin è organizzata in **4 tab**:

#### 1️⃣ Tab **Personale**
- **Visualizza** tutti i dipendenti registrati
- **Aggiungi** nuovo dipendente con pulsante "+"
- **Elimina** dipendenti (tranne admin)
- **Clicca** su un dipendente per vedere il suo storico completo

**Come aggiungere un dipendente:**
1. Premi il pulsante "Nuovo Dipendente"
2. Inserisci Nome, Email e Password (min 6 caratteri)
3. Conferma

#### 2️⃣ Tab **Presenze Oggi**
Dashboard con **statistiche in tempo reale**:
- 📊 Contatore ingressi di oggi
- 📊 Contatore uscite di oggi
- 📋 Lista completa timbrature ordinate per ora
- 🔄 Pull-to-refresh per aggiornare

#### 3️⃣ Tab **Cantieri**
**Mappa interattiva** per gestire i cantieri:

**Aggiungere un nuovo cantiere:**
1. Premi il pulsante **+ (blu)** in basso a destra
2. Tocca un punto sulla mappa per posizionare il marker
3. Il sistema recupera automaticamente l'indirizzo
4. Inserisci il nome del cantiere
5. Conferma con il pulsante verde **💾**

**Visualizzare cantieri esistenti:**
- 🟢 **Marker verde**: Cantiere attivo
- ⚫ **Marker grigio**: Cantiere disattivato

#### 4️⃣ Tab **Report**
**Genera report Excel** con filtri avanzati:

**Opzioni di filtro:**
- 👤 **Dipendente**: Seleziona un dipendente specifico o "Tutti"
- 🏗️ **Cantiere**: Seleziona un cantiere specifico o "Tutti"
- 📅 **Data Inizio**: Filtra da una data specifica
- 📅 **Data Fine**: Filtra fino a una data specifica

**Contenuto del Report:**
- ID e Nome Dipendente
- Nome Cantiere
- Tipo (Ingresso/Uscita) **colorato**
- Data e Ora in formato italiano
- Informazioni dispositivo
- Coordinate GPS (6 decimali di precisione)
- **Filtri automatici** su tutte le colonne

**Come generare un report:**
1. Scegli i filtri desiderati (opzionale)
2. Premi "Genera Report"
3. Il file si aprirà automaticamente

---

## 🗺️ Geofencing

### Come Funziona
Il sistema verifica automaticamente se il dipendente si trova nel raggio del cantiere selezionato.

### Raggio Consentito
- **100 metri** dal centro del cantiere
- Configurabile in `lib/services/location_service.dart` (variabile `maxDistanceMeters`)

### Comportamento
1. **Dentro il raggio**: ✅ Timbratura immediata
2. **Fuori dal raggio**: ⚠️ Dialog di conferma con distanza esatta
3. **Piattaforme Desktop/Web**: Sempre consentito (per testing)

---

## 📊 Report Excel - Dettagli

### Formato
- **Lingua**: Italiano
- **Intestazioni**: Formattate e colorate
- **Bordi**: Su tutte le celle
- **Filtri**: Automatici su tutte le colonne

### Colonne
1. **ID Dipendente**
2. **Nome Dipendente**
3. **Cantiere** (o "Non specificato")
4. **Tipo** (Ingresso in verde, Uscita in rosso)
5. **Data e Ora** (formato italiano)
6. **Dispositivo** (Sistema operativo)
7. **Latitudine** (6 decimali)
8. **Longitudine** (6 decimali)

### Salvataggio
- **Percorso**: `server/reports/`
- **Nome file**: 
  - Senza filtri: `attendance_report.xlsx`
  - Con filtri: `attendance_report_[timestamp].xlsx`

---

## 🔧 Risoluzione Problemi

### Il server non si avvia
```bash
cd server
rm -rf node_modules
npm install
npm start
```

### L'app non si connette al server
Verifica che il server sia avviato e che l'URL in `lib/services/api_service.dart` sia:
```dart
static const String baseUrl = 'http://localhost:3000/api';
```

### GPS non funziona
- **Android**: Abilita permessi posizione nelle impostazioni
- **iOS**: Abilita permessi posizione nelle impostazioni
- **Windows/Web**: Il GPS è simulato (sempre 0,0)

### Errore "Cantiere non trovato"
Assicurati di aver creato almeno un cantiere nella tab "Cantieri" dell'area admin.

### Report Excel non si apre
Verifica di avere un'app per aprire file `.xlsx` installata sul dispositivo.

---

## 📱 Compatibilità

- ✅ **Android** 5.0+ (API 21+)
- ✅ **iOS** 11.0+
- ✅ **Windows** (Desktop)
- ✅ **Web** (Browser moderni)

---

## 💾 Database

### Backup
Il database è in `server/attendance.db`. Per fare un backup:
```bash
cp server/attendance.db server/attendance.db.backup
```

### Reset
Per resettare il database:
```bash
rm server/attendance.db
npm start  # Ricreerà il database con l'admin default
```

---

## 📞 Supporto

Per problemi o domande:
1. Verifica il CHANGELOG.md per vedere le ultime modifiche
2. Controlla i log del server nella console
3. Verifica i log dell'app Flutter

---

## 🎨 Personalizzazione

### Modificare il raggio geofencing
Modifica in `lib/services/location_service.dart`:
```dart
static const double maxDistanceMeters = 100.0; // Cambia qui
```

### Cambiare numero timbrature recenti
Modifica in `lib/pages/employee_page.dart`:
```dart
_recentRecords = records.take(5).toList(); // Cambia 5 con il numero desiderato
```

### Modificare colori tema
Modifica in `lib/main.dart`:
```dart
theme: ThemeData(
  primarySwatch: Colors.blue, // Cambia colore principale
  useMaterial3: true,
),
```
