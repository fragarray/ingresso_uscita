# Aggiornamenti Sistema Cantieri - Descrizioni e Info Complete

## 📝 Modifiche Implementate

### 1. **Model WorkSite** ✅
**File**: `lib/models/work_site.dart`

- ✅ Aggiunto campo `description` (String? nullable)
- ✅ Aggiornato `toMap()` per includere description
- ✅ Aggiornato `fromMap()` per leggere description

```dart
class WorkSite {
  final String? description;  // NUOVO CAMPO
  
  WorkSite({
    // ... altri campi
    this.description,
  });
}
```

---

### 2. **Backend - Database** ✅
**File**: `server/db.js`

- ✅ Aggiunta colonna `description TEXT` alla tabella `work_sites`
- ✅ Migrazione automatica al riavvio del server

```javascript
db.run(`ALTER TABLE work_sites ADD COLUMN description TEXT`, (err) => {
  if (!err) {
    console.log('✓ Column description added to work_sites');
  }
});
```

---

### 3. **Backend - API Routes** ✅
**File**: `server/routes/worksites.js`

#### GET /api/worksites
- ✅ Ora restituisce anche `description` in tutti i cantieri

#### POST /api/worksites
- ✅ Accetta campo `description` in creazione
- ✅ Salva description nel database (o NULL se vuoto)

#### PUT /api/worksites/:id
- ✅ Accetta campo `description` in modifica
- ✅ Aggiorna description sul database

---

### 4. **UI Admin - Creazione Cantiere** ✅
**File**: `lib/widgets/work_sites_tab.dart`

#### Dialog "Nuovo Cantiere"
- ✅ Aggiunto campo `TextFormField` per descrizione
- ✅ Max 200 caratteri, 3 righe
- ✅ Opzionale (non richiesto)
- ✅ Helper text: "Info aggiuntive visibili ai dipendenti"
- ✅ Indirizzo e coordinate mostrati in container colorato per chiarezza
- ✅ Controller `_descriptionController` aggiunto e dispose correttamente

```dart
TextFormField(
  controller: _descriptionController,
  decoration: const InputDecoration(
    labelText: 'Descrizione (opzionale)',
    prefixIcon: Icon(Icons.description),
    helperText: 'Info aggiuntive visibili ai dipendenti',
  ),
  maxLines: 3,
  maxLength: 200,
),
```

---

### 5. **UI Admin - Dettagli/Modifica Cantiere** ✅
**File**: `lib/widgets/work_sites_tab.dart`

#### Dialog Dettagli Cantiere
- ✅ **Nome modificabile**: IconButton edit nel title
- ✅ **Descrizione modificabile**: Sezione dedicata con IconButton edit
- ✅ Mostra descrizione in container colorato (viola) se presente
- ✅ Mostra "Nessuna descrizione" in grigio italic se vuota
- ✅ Aggiornamento realtime nel dialog dopo modifica

#### Nuovi Metodi
```dart
Future<String?> _editWorkSiteNameDialog(String currentName)
Future<String?> _editWorkSiteDescriptionDialog(String? currentDescription)
```

#### Funzionalità
1. **Modifica Nome**:
   - Click su icona edit nel titolo
   - Dialog con campo testo pre-compilato
   - Validazione: non può essere vuoto
   - Aggiornamento immediato sul server

2. **Modifica Descrizione**:
   - Click su icona edit nella sezione Descrizione
   - Dialog con textarea 4 righe, max 200 caratteri
   - Può essere svuotata (diventa NULL sul server)
   - Helper: "Lascia vuoto per rimuovere"
   - Aggiornamento immediato sul server

---

### 6. **UI Dipendente - Card Cantieri** ✅
**File**: `lib/pages/employee_page.dart`

#### Card Moderna
- ✅ **Descrizione breve**: Mostrata sotto il nome (1 riga, ellipsis)
- ✅ Stile: fontSize 10, grigio, italic
- ✅ Solo se descrizione presente e non vuota

```dart
if (workSite.description != null && workSite.description!.isNotEmpty) ...[
  Text(
    workSite.description!,
    style: TextStyle(
      fontSize: 10,
      color: Colors.grey[600],
      fontStyle: FontStyle.italic,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
],
```

---

### 7. **UI Dipendente - Long Press Info** ✅
**File**: `lib/pages/employee_page.dart`

#### Nuovo Metodo: `_showWorkSiteInfo(WorkSite)`
- ✅ Attivato con **long press** sulla card cantiere
- ✅ Mostra dialog informativo completo

#### Informazioni Mostrate:
1. **Indirizzo** 
   - Icona: `place_rounded` (blu)
   - Testo completo indirizzo

2. **Coordinate GPS**
   - Icona: `gps_fixed` (arancione)
   - Lat/Lng con 6 decimali
   - Font monospace per allineamento

3. **Distanza**
   - Icona: `navigation_rounded` (verde)
   - Calcolata dalla posizione attuale
   - Formato: metri se < 1km, km con 2 decimali altrimenti

4. **Descrizione**
   - Icona: `description_rounded` (viola)
   - Container colorato viola con bordo
   - Testo completo multilinea
   - Solo se presente

5. **Raggio Validità**
   - Icona: `radar` (deepOrange)
   - Metri richiesti per timbratura valida

```dart
void _showWorkSiteInfo(WorkSite workSite) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row with icon and name,
      content: SingleChildScrollView with all details,
      actions: [TextButton CHIUDI],
    ),
  );
}
```

---

## 🎯 User Experience

### Per l'Amministratore:
1. **Creazione Cantiere**:
   - Click sulla mappa → seleziona posizione
   - Dialog: Nome + Descrizione + Raggio
   - Indirizzo e coordinate mostrate automaticamente

2. **Modifica Cantiere**:
   - Click su marker → Dialog dettagli
   - Edit nome: click icona edit nel title
   - Edit descrizione: click icona edit nella sezione
   - Edit raggio: click icona edit nella riga raggio
   - Delete: pulsante rosso in fondo

### Per il Dipendente:
1. **Vista Griglia**:
   - Card moderne 3 colonne (responsive)
   - Nome cantiere in grassetto
   - Descrizione sotto in corsivo (se presente)
   - Badge distanza
   - Badge "QUI" se timbrato lì

2. **Dettagli Completi**:
   - **Long press** sulla card
   - Dialog con tutte le info:
     - Indirizzo completo
     - Coordinate GPS precise
     - Distanza calcolata
     - Descrizione completa (se presente)
     - Raggio validità

3. **Timbratura**:
   - **Tap normale** sulla card → Timbratura (come prima)
   - **Long press** → Info dettagliate

---

## 🗄️ Struttura Database

### Tabella `work_sites`
```sql
CREATE TABLE work_sites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  address TEXT NOT NULL,
  isActive INTEGER DEFAULT 1,
  radiusMeters REAL DEFAULT 100.0,
  description TEXT,              -- NUOVO CAMPO
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔄 Compatibilità

### Database Esistenti:
- ✅ **Migrazione automatica**: colonna aggiunta al primo avvio
- ✅ **Backward compatible**: cantieri senza descrizione funzionano normalmente
- ✅ **NULL handling**: descrizione può essere NULL o stringa vuota

### UI Esistente:
- ✅ **Card responsive**: descrizione mostrata solo se presente
- ✅ **Long press aggiuntivo**: non interferisce con tap normale
- ✅ **Admin dialog**: sezioni chiare e separate

---

## 📱 Testing

### Da Testare:
1. **Backend**:
   ```bash
   cd server
   node server.js
   # Verifica log: "✓ Column description added to work_sites"
   ```

2. **Admin UI**:
   - [ ] Crea cantiere con descrizione
   - [ ] Crea cantiere senza descrizione
   - [ ] Modifica nome cantiere esistente
   - [ ] Modifica descrizione cantiere esistente
   - [ ] Svuota descrizione (diventa NULL)

3. **Dipendente UI**:
   - [ ] Card mostra descrizione se presente
   - [ ] Long press su card mostra tutti i dettagli
   - [ ] Tap normale continua a timbrare
   - [ ] Indirizzo e coordinate corretti nel dialog

---

## 🎨 Design System

### Colori Icone:
- 🔵 **Blu** - Indirizzo (place)
- 🟠 **Arancione** - GPS (gps_fixed)
- 🟢 **Verde** - Distanza (navigation)
- 🟣 **Viola** - Descrizione (description)
- 🔶 **DeepOrange** - Raggio (radar)

### Container Descrizione:
- **Background**: `Colors.purple[50]`
- **Border**: `Colors.purple[200]`, width 1
- **BorderRadius**: 8
- **Padding**: 12
- **TextStyle**: `Colors.grey[800]`, fontSize 14

---

## 📊 Statistiche Modifiche

- **Files modificati**: 5
  - `lib/models/work_site.dart`
  - `server/db.js`
  - `server/routes/worksites.js`
  - `lib/widgets/work_sites_tab.dart`
  - `lib/pages/employee_page.dart`

- **Nuovi metodi**: 3
  - `_showWorkSiteInfo()` - employee_page
  - `_editWorkSiteNameDialog()` - work_sites_tab
  - `_editWorkSiteDescriptionDialog()` - work_sites_tab

- **Nuovi campi**: 1
  - `description` in WorkSite model

- **Nuove colonne DB**: 1
  - `description TEXT` in work_sites table

---

## ✨ Benefici

1. **Più informazioni**: Dipendenti vedono indirizzo completo + coordinate + descrizione
2. **Flessibilità**: Admin può aggiungere note/istruzioni specifiche per ogni cantiere
3. **UX migliorata**: Long press intuitivo per dettagli, tap per azione
4. **Manutenibilità**: Nome e descrizione modificabili senza ricreare cantiere
5. **Scalabilità**: Campo description può contenere fino a 200 caratteri

---

**Data implementazione**: 16 Ottobre 2025
**Versione**: 2.0.0
**Status**: ✅ Completato e testabile
