# 📦 Guida Build Release - Windows & Android

## 🪟 BUILD WINDOWS (.exe)

### Metodo 1: Build Release Standard (Solo EXE)

#### Comando
```powershell
# Nella root del progetto
flutter build windows --release
```

#### Output
```
build/windows/x64/runner/Release/
├── ingresso_uscita.exe         ← Eseguibile principale
├── flutter_windows.dll          ← DLL Flutter (obbligatoria!)
├── msvcp140.dll                 ← Runtime C++ (se presente)
├── vcruntime140.dll             ← Runtime C++ (se presente)
├── vcruntime140_1.dll           ← Runtime C++ (se presente)
└── data/                        ← Assets e risorse app
    ├── icudtl.dat
    ├── flutter_assets/
    └── [altri file]
```

#### ⚠️ IMPORTANTE - Distribuzione
**NON puoi distribuire solo l'exe!** Devi includere:

1. `ingresso_uscita.exe`
2. `flutter_windows.dll`
3. Cartella `data/` completa
4. Eventuali DLL runtime (msvcp140, vcruntime140)

**Come distribuire:**
```powershell
# Comprimi tutta la cartella Release
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "IngressoUscita_Windows_v1.0.0.zip"
```

L'utente dovrà:
1. Estrarre lo zip
2. Eseguire `ingresso_uscita.exe`

---

### Metodo 2: MSIX Installer (Raccomandato) ⭐

#### Vantaggi
- ✅ **Installer unico** (.msix)
- ✅ **Installazione automatica** (doppio click)
- ✅ **Icona nel menu Start**
- ✅ **Aggiornamenti gestiti** da Windows
- ✅ **Disinstallazione pulita**
- ✅ **Firma digitale** (opzionale)

#### Setup (già fatto!)
```yaml
# pubspec.yaml
msix_config:
  display_name: Ingresso Uscita
  publisher_display_name: FragArray
  identity_name: com.fragarray.ingressouscita
  msix_version: 1.0.0.0
  capabilities: internetClient, location
```

#### Build MSIX
```powershell
# 1. Build release
flutter build windows --release

# 2. Crea installer MSIX
flutter pub run msix:create
```

#### Output
```
build/windows/x64/runner/Release/ingresso_uscita.msix  ← Installer
```

#### Distribuzione
Invia solo il file `.msix` agli utenti.

**Installazione utente:**
1. Doppio click su `ingresso_uscita.msix`
2. Windows chiederà conferma
3. App installata in menu Start

#### Firma Digitale (Opzionale)
Per evitare warning "Publisher unknown":

```yaml
msix_config:
  certificate_path: certificato.pfx
  certificate_password: tua_password
```

**Come ottenere certificato:**
- **Gratis (dev):** Auto-firmato con `New-SelfSignedCertificate` PowerShell
- **A pagamento:** DigiCert, Comodo, Sectigo (~300€/anno)

---

## 🤖 BUILD ANDROID (.apk)

### Preparazione

#### 1. Configura App ID e Versione
File: `android/app/build.gradle`

```gradle
android {
    defaultConfig {
        applicationId "com.fragarray.ingresso_uscita"  // ID unico
        minSdkVersion 21                               // Android 5.0+
        targetSdkVersion 34                            // Android 14
        versionCode 1                                  // Incrementa ad ogni release
        versionName "1.0.0"                           // Versione visualizzata
    }
}
```

#### 2. Crea Keystore per Firma (Prima Volta)
```powershell
# Genera keystore per firmare l'APK
keytool -genkey -v -keystore c:\Users\frag_\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Ti chiederà:**
- Password keystore (salvala!)
- Nome, organizzazione, città, ecc.
- Password chiave (puoi usare la stessa)

**Output:** `c:\Users\frag_\upload-keystore.jks`

#### 3. Configura Firma
Crea file `android/key.properties`:

```properties
storePassword=tua_password_keystore
keyPassword=tua_password_chiave
keyAlias=upload
storeFile=c:/Users/frag_/upload-keystore.jks
```

⚠️ **NON committare questo file su Git!**

Aggiungi a `.gitignore`:
```
android/key.properties
*.jks
*.keystore
```

#### 4. Aggiorna build.gradle
File: `android/app/build.gradle`

Aggiungi PRIMA di `android {`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

### Build APK

#### APK Standard (Per Test/Distribuzione Diretta)
```powershell
flutter build apk --release
```

**Output:**
```
build/app/outputs/flutter-apk/app-release.apk  ← APK pronto
```

**Dimensione tipica:** 20-50 MB

**Distribuzione:**
- Invia APK via email/WhatsApp/Drive
- Utente scarica e installa (richiede "Installa da fonti sconosciute")

---

#### APK Split per Architettura (Raccomandato)
Crea APK separati per ogni architettura → file più piccoli!

```powershell
flutter build apk --release --split-per-abi
```

**Output:**
```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk    ← Android vecchi (32-bit)  ~15MB
├── app-arm64-v8a-release.apk      ← Android moderni (64-bit) ~18MB
└── app-x86_64-release.apk         ← Emulatori               ~20MB
```

**Vantaggi:**
- File più piccoli (utente scarica solo quello per il suo dispositivo)
- Download più veloce

**Quale distribuire:**
- **arm64-v8a:** 95% degli smartphone moderni (2019+)
- **armeabi-v7a:** Smartphone vecchi (pre-2019)
- **x86_64:** Solo per test emulatori

---

#### App Bundle (Per Google Play Store)
Se pubblichi su Play Store usa `.aab` invece di `.apk`:

```powershell
flutter build appbundle --release
```

**Output:**
```
build/app/outputs/bundle/release/app-release.aab
```

**Vantaggi:**
- Google Play genera APK ottimizzati per ogni dispositivo
- Download utente fino a 50% più piccolo
- **Obbligatorio** per nuove app su Play Store

---

## 📋 Checklist Pre-Release

### Windows
- [ ] Aggiornato version in `pubspec.yaml`
- [ ] Testato build release: `flutter build windows --release`
- [ ] Verificato che l'exe funzioni (con tutte le DLL)
- [ ] Creato MSIX se necessario: `flutter pub run msix:create`
- [ ] Testato installer MSIX su macchina pulita

### Android
- [ ] Creato keystore (prima volta)
- [ ] Configurato `key.properties`
- [ ] Aggiornato `versionCode` e `versionName`
- [ ] Build APK: `flutter build apk --release`
- [ ] Testato APK su dispositivo fisico
- [ ] Verificato permessi (location, internet)
- [ ] Testato su Android 5.0+ (minSdk 21)

---

## 🚀 Comandi Rapidi

### Windows - Build Completo
```powershell
# Build + MSIX in un comando
flutter clean ; flutter pub get ; flutter build windows --release ; flutter pub run msix:create
```

### Android - Build Completo
```powershell
# Build APK split
flutter clean ; flutter pub get ; flutter build apk --release --split-per-abi
```

### Android - Build per Play Store
```powershell
# Build App Bundle
flutter clean ; flutter pub get ; flutter build appbundle --release
```

---

## 📊 Dimensioni File Tipiche

| Build Type | Dimensione | Tempo Build |
|------------|------------|-------------|
| **Windows Release (cartella)** | ~60-80 MB | 2-5 min |
| **Windows MSIX** | ~50-70 MB | 3-6 min |
| **Android APK (fat)** | ~30-50 MB | 3-7 min |
| **Android APK (arm64)** | ~18-25 MB | 3-7 min |
| **Android AAB** | ~25-35 MB | 3-7 min |

---

## 🔧 Troubleshooting

### Windows: "DLL mancante"
```
Errore: Impossibile avviare, manca flutter_windows.dll
```

**Soluzione:** Distribuisci tutta la cartella `Release/`, non solo l'exe

---

### Windows: MSIX non si installa
```
Errore: Impossibile verificare il publisher
```

**Soluzioni:**
1. Firma con certificato valido
2. Abilita "Developer Mode" su Windows
3. Usa certificato auto-firmato per test

---

### Android: "Keystore not found"
```
Execution failed for task ':app:validateSigningRelease'
```

**Soluzione:** Verifica path in `key.properties`:
```properties
storeFile=C:/Users/frag_/upload-keystore.jks  ← Usa / non \
```

---

### Android: APK non si installa
```
App not installed
```

**Cause comuni:**
1. **Firma non valida:** Rigenera keystore
2. **Architettura incompatibile:** Usa APK fat o arm64-v8a
3. **Versione precedente installata:** Disinstalla prima

**Soluzione:**
```powershell
# Build APK fat (supporta tutte le architetture)
flutter build apk --release
```

---

### Android: "Minimum SDK version"
```
Manifest merger failed : uses-sdk:minSdkVersion 21 cannot be smaller than version 23
```

**Soluzione:** Aumenta minSdkVersion in `android/app/build.gradle`:
```gradle
minSdkVersion 23  // Cambia da 21 a 23
```

---

## 📦 Distribuzione

### Windows
**Opzione 1: ZIP**
- Comprimi cartella `Release/`
- Distribuisci via Google Drive / Dropbox
- README con istruzioni (estrai e esegui exe)

**Opzione 2: MSIX**
- File singolo `.msix`
- Installazione con doppio click
- Più professionale

**Opzione 3: Setup.exe (Avanzato)**
- Usa Inno Setup / NSIS
- Installer personalizzato
- Desktop shortcut automatico

### Android
**Opzione 1: APK Diretta**
- Distribuisci APK via link
- User abilita "Fonti sconosciute"
- Installazione manuale

**Opzione 2: Google Play Store**
- Upload AAB su Play Console
- Distribuzione ufficiale
- Aggiornamenti automatici
- Costa 25$ una tantum (registrazione developer)

**Opzione 3: Private Distribution**
- Firebase App Distribution (gratis)
- Google Drive con link diretto
- TestFlight (per iOS)

---

## 🎯 Best Practices

### Versioning
```yaml
# pubspec.yaml
version: 1.0.0+1
#        │ │ │  │
#        │ │ │  └─ buildNumber (Android versionCode)
#        │ │ └──── patch (bugfix)
#        │ └────── minor (feature)
#        └──────── major (breaking change)
```

**Esempio incrementi:**
- Bugfix: `1.0.0+1` → `1.0.1+2`
- Feature: `1.0.1+2` → `1.1.0+3`
- Breaking: `1.1.0+3` → `2.0.0+4`

### Changelog
Mantieni un file `CHANGELOG.md`:
```markdown
## [1.0.0] - 2025-10-15
### Aggiunto
- Vista mappa con cambio stradale/satellite
- Geocoding cross-platform
- Zoom controls

### Modificato
- Tile server da OSM a CartoDB

### Risolto
- Warning tile server OSM
```

### Testing Release
```powershell
# Windows: Testa su macchina SENZA Flutter installato
# Android: Testa su dispositivo fisico (non emulatore)

# Verifica:
- App si avvia
- Connessione server funziona
- Location funziona
- Mappa carica
- Ricerca indirizzo funziona
- Cambio tipo mappa funziona
```

---

## 📄 File da NON Committare

Aggiungi a `.gitignore`:
```gitignore
# Build output
build/
*.apk
*.aab
*.msix

# Signing
android/key.properties
*.jks
*.keystore
*.pfx

# Secrets
.env
*.pem
```

---

## ✅ Summary Comandi

| Azione | Windows | Android |
|--------|---------|---------|
| **Build release base** | `flutter build windows --release` | `flutter build apk --release` |
| **Build ottimizzato** | `flutter pub run msix:create` | `flutter build apk --split-per-abi` |
| **Build store** | MSIX firmato | `flutter build appbundle` |
| **Output location** | `build/windows/x64/runner/Release/` | `build/app/outputs/flutter-apk/` |

---

**Vuoi che ti aiuti a configurare il keystore Android o a creare il primo build?** 🚀
