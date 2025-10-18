# Ridenominazione Applicazione: "Sinergy Work"

## 📝 Modifiche Applicate

L'applicazione è stata completamente rinominata da **"ingresso_uscita"** / **"Sistema Timbratura"** a **"Sinergy Work"**.

---

## ✅ File Modificati

### 1. **lib/main.dart**
**Modifica:** Titolo dell'applicazione
```dart
// PRIMA:
title: 'Sistema Timbratura',

// ORA:
title: 'Sinergy Work',
```

**Impatto:** Nome visualizzato nella barra delle applicazioni e task manager

---

### 2. **lib/pages/login_page.dart**
**Modifica:** Titolo AppBar
```dart
// PRIMA:
title: const Text('Sistema Timbratura'),

// ORA:
title: const Text('Sinergy Work'),
```

**Impatto:** Nome visualizzato nella barra superiore della schermata di login

---

### 3. **pubspec.yaml**
**Modifiche multiple:**

#### a) Descrizione del progetto
```yaml
# PRIMA:
description: "A new Flutter project."

# ORA:
description: "Sinergy Work - Sistema di gestione timbrature e presenze"
```

#### b) Configurazione MSIX (Windows)
```yaml
# PRIMA:
msix_config:
  display_name: Ingresso Uscita
  publisher_display_name: FragArray
  identity_name: com.fragarray.ingressouscita

# ORA:
msix_config:
  display_name: Sinergy Work
  publisher_display_name: FragArray
  identity_name: com.fragarray.sinergywork
```

**Impatto:** 
- Nome visualizzato nel menu Start di Windows
- Nome dell'installer MSIX
- Package identifier univoco

---

### 4. **android/app/src/main/AndroidManifest.xml**
**Modifica:** Label dell'applicazione Android
```xml
<!-- PRIMA: -->
<application android:label="ingresso_uscita" ...>

<!-- ORA: -->
<application android:label="Sinergy Work" ...>
```

**Impatto:** 
- Nome visualizzato nell'app drawer Android
- Nome visualizzato nelle impostazioni del telefono
- Nome visualizzato nel task switcher

---

### 5. **windows/runner/Runner.rc**
**Modifica:** Metadati eseguibile Windows
```rc
// PRIMA:
VALUE "CompanyName", "com.example" "\0"
VALUE "FileDescription", "ingresso_uscita" "\0"
VALUE "InternalName", "ingresso_uscita" "\0"
VALUE "OriginalFilename", "ingresso_uscita.exe" "\0"
VALUE "ProductName", "ingresso_uscita" "\0"

// ORA:
VALUE "CompanyName", "FragArray" "\0"
VALUE "FileDescription", "Sinergy Work" "\0"
VALUE "InternalName", "Sinergy Work" "\0"
VALUE "OriginalFilename", "sinergy_work.exe" "\0"
VALUE "ProductName", "Sinergy Work" "\0"
```

**Impatto:**
- Nome visualizzato nelle proprietà dell'eseguibile
- Nome del file .exe generato
- Informazioni azienda (da "com.example" a "FragArray")

---

### 6. **windows/runner/main.cpp**
**Modifica:** Titolo finestra Windows
```cpp
// PRIMA:
if (!window.Create(L"ingresso_uscita", origin, size)) {

// ORA:
if (!window.Create(L"Sinergy Work", origin, size)) {
```

**Impatto:** Nome visualizzato nella barra del titolo della finestra Windows

---

### 7. **windows/CMakeLists.txt**
**Modifica:** Nome progetto e binario
```cmake
# PRIMA:
project(ingresso_uscita LANGUAGES CXX)
set(BINARY_NAME "ingresso_uscita")

# ORA:
project(sinergy_work LANGUAGES CXX)
set(BINARY_NAME "sinergy_work")
```

**Impatto:** 
- Nome del file eseguibile generato: `sinergy_work.exe`
- Nome interno del progetto CMake

---

## 📱 Risultati Visibili

### **Android (APK)**
- ✅ Nome icona: **"Sinergy Work"**
- ✅ App drawer: **"Sinergy Work"**
- ✅ Impostazioni → App: **"Sinergy Work"**
- ✅ Task switcher: **"Sinergy Work"**
- ✅ Barra titolo login: **"Sinergy Work"**

### **Windows (EXE/MSIX)**
- ✅ Nome eseguibile: **`sinergy_work.exe`**
- ✅ Barra titolo finestra: **"Sinergy Work"**
- ✅ Task Manager: **"Sinergy Work"**
- ✅ Menu Start: **"Sinergy Work"**
- ✅ Proprietà file: **"Sinergy Work"** (prodotto)
- ✅ Azienda: **"FragArray"**

---

## 🔧 Come Ricompilare

### **Android APK**
```powershell
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### **Windows Installer MSIX**
```powershell
flutter pub run msix:create
```
Output: `build/windows/x64/runner/Release/sinergy_work.msix`

### **Windows EXE (standalone)**
```powershell
flutter build windows --release
```
Output: `build/windows/x64/runner/Release/sinergy_work.exe`

---

## ⚠️ Note Importanti

### **1. Nome Package NON Modificato**
Il nome del package Dart rimane `ingresso_uscita` nel `pubspec.yaml`:
```yaml
name: ingresso_uscita  # ⚠️ NON MODIFICATO
```

**Motivo:** Cambiare il nome del package richiede refactoring massiccio di tutti gli import:
```dart
// Tutti questi import dovrebbero cambiare:
import 'package:ingresso_uscita/main.dart';
import 'package:ingresso_uscita/models/employee.dart';
// ... centinaia di riferimenti
```

**Impatto:** NESSUNO - Il nome del package è interno e non visibile all'utente finale.

---

### **2. Cartella Progetto NON Rinominata**
La cartella del progetto rimane:
```
C:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\
```

**Motivo:** Evitare problemi con:
- Percorsi assoluti nei file di configurazione
- Repository Git
- Script di build
- Path hardcoded

**Impatto:** NESSUNO - Il nome della cartella non è visibile nell'applicazione compilata.

---

### **3. File Server NON Modificati**
I file nella cartella `server/` mantengono i riferimenti a `ingresso_uscita`:
- `ingresso_uscita.db` (database)
- Script bash con percorsi `ingresso_uscita_server`
- File di configurazione

**Motivo:** Il server è un componente backend separato, la ridenominazione non è necessaria.

**Impatto:** NESSUNO - Il server non ha interfaccia utente visibile.

---

## 🎯 Verifica Modifiche

### **Test Android:**
1. Compila APK: `flutter build apk --release`
2. Installa su dispositivo
3. Verifica nome nell'app drawer: ✅ "Sinergy Work"
4. Apri app e verifica titolo: ✅ "Sinergy Work"

### **Test Windows:**
1. Compila eseguibile: `flutter build windows --release`
2. Avvia `build/windows/x64/runner/Release/sinergy_work.exe`
3. Verifica barra titolo: ✅ "Sinergy Work"
4. Apri Task Manager: ✅ "Sinergy Work"
5. Proprietà file → Dettagli:
   - Nome prodotto: ✅ "Sinergy Work"
   - Azienda: ✅ "FragArray"

---

## 📊 Riepilogo Modifiche

| Elemento | Vecchio Nome | Nuovo Nome |
|----------|--------------|------------|
| **Titolo App** | Sistema Timbratura | Sinergy Work |
| **Titolo Login** | Sistema Timbratura | Sinergy Work |
| **App Android** | ingresso_uscita | Sinergy Work |
| **Finestra Windows** | ingresso_uscita | Sinergy Work |
| **EXE Windows** | ingresso_uscita.exe | sinergy_work.exe |
| **MSIX Windows** | Ingresso Uscita | Sinergy Work |
| **Azienda** | com.example | FragArray |
| **Package ID (MSIX)** | com.fragarray.ingressouscita | com.fragarray.sinergywork |

---

## ✅ Completato

Tutte le modifiche sono state applicate con successo. L'applicazione è ora completamente rinominata in **"Sinergy Work"** in tutti i punti visibili all'utente finale.

**Data modifica:** 18 Ottobre 2025
