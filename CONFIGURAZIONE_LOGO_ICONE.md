# Configurazione Logo e Icone App

## 📅 Data: 17 Ottobre 2025

## 🎯 Modifiche Applicate

### 1. **File Assets Organizzati**

**Posizione**: `assets/images/`

- ✅ **`logo.ico`** - Icona per Windows e Android
- ✅ **`logo.png`** - Logo Sinergy Work per pagina di login

### 2. **Icona Windows** 

**File modificato**: `windows/runner/resources/app_icon.ico`

- ✅ Sostituito con il file `logo.ico` personalizzato
- ✅ Configurato in `msix_config` del pubspec.yaml
- ✅ L'icona verrà utilizzata per:
  - Eseguibile `.exe` 
  - Installer `.msix`
  - Barra delle applicazioni
  - File explorer

**Come ricostruire**:
```powershell
flutter build windows --release
```

### 3. **Icona Android**

**File generati**: `android/app/src/main/res/mipmap-*/`

- ✅ Generati automaticamente da `logo.ico` usando `flutter_launcher_icons`
- ✅ Icone create per tutte le risoluzioni:
  - `mipmap-mdpi` (48x48)
  - `mipmap-hdpi` (72x72)
  - `mipmap-xhdpi` (96x96)
  - `mipmap-xxhdpi` (144x144)
  - `mipmap-xxxhdpi` (192x192)

**Come rigenerare le icone Android**:
```bash
dart run flutter_launcher_icons
```

### 4. **Logo nella Pagina di Login**

**File modificato**: `lib/pages/login_page.dart`

**Modifiche applicate**:
- ✅ Aggiunto `SingleChildScrollView` per supportare schermi piccoli
- ✅ Aggiunto logo `logo.png` sopra il form di login
- ✅ Dimensioni: 250x250 con `BoxFit.contain`
- ✅ Spaziatura di 30px tra logo e testo "Benvenuto"

**Layout aggiornato**:
```
┌─────────────────────┐
│   [Logo Sinergy]    │  ← 250x250px
│                     │
│     Benvenuto       │  ← Testo
│                     │
│   [Email Field]     │
│   [Password Field]  │
│   [Login Button]    │
│   [Verifica Server] │
└─────────────────────┘
```

### 5. **Configurazione pubspec.yaml**

**Modifiche al file `pubspec.yaml`**:

```yaml
# Assets dell'applicazione
assets:
  - assets/images/logo.png
  - assets/images/logo.ico

# Dev dependencies
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

# Configurazione icone Android
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/images/logo.ico"

# Configurazione Windows MSIX
msix_config:
  logo_path: windows/runner/resources/app_icon.ico
```

## 🚀 Come Usare

### Build Windows con nuova icona:
```powershell
# Build release
flutter build windows --release

# Generare installer MSIX (opzionale)
dart run msix:create
```

### Build Android con nuova icona:
```bash
# Debug
flutter build apk --debug

# Release (richiede keystore)
flutter build apk --release
```

### Test rapido dell'app:
```bash
# Windows
flutter run -d windows

# Android
flutter run -d <device_id>
```

## 📋 Checklist Verifica

- [x] ✅ Logo.ico copiato in `windows/runner/resources/app_icon.ico`
- [x] ✅ Assets registrati in `pubspec.yaml`
- [x] ✅ Icone Android generate con `flutter_launcher_icons`
- [x] ✅ Logo PNG aggiunto alla pagina di login
- [x] ✅ Login page aggiornata con `SingleChildScrollView`
- [x] ✅ Nessun errore di compilazione

## 🎨 File Sorgente Logo

**Logo originale**: Sinergy Work
- Edificio giallo
- Orologio centrale  
- Gru da costruzione
- Testo "Sinergy Work" (rosso + blu)

## 📝 Note Importanti

1. **Windows**: L'icona `.ico` deve contenere più risoluzioni (16x16, 32x32, 48x48, 256x256)
2. **Android**: `flutter_launcher_icons` converte automaticamente in tutte le risoluzioni necessarie
3. **Logo Login**: Il file PNG viene usato per avere qualità migliore nel logo visualizzato
4. **Responsive**: `SingleChildScrollView` permette lo scroll su schermi piccoli

## 🔄 Per Aggiornare Logo/Icone in Futuro

1. Sostituire i file in `assets/images/`
2. Rigenerare icone Android: `dart run flutter_launcher_icons`
3. Copiare nuovo `.ico` in `windows/runner/resources/`
4. Ricompilare: `flutter build windows --release`

## 🐛 Troubleshooting

### Icona Windows non si aggiorna
```powershell
# Pulire build
flutter clean
# Ricostruire
flutter build windows --release
```

### Icona Android non si aggiorna
```bash
# Rigenerare icone
dart run flutter_launcher_icons
# Pulire build
flutter clean
# Ricostruire
flutter build apk --release
```

### Logo non appare nella login
```bash
# Verificare assets in pubspec.yaml
flutter pub get
# Hot restart (non hot reload!)
Press 'R' in terminal
```

---

✅ **Configurazione completata con successo!** 🎉
