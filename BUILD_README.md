# 🚀 Build Release - Quick Start

## Comandi Rapidi

### 🪟 Windows (EXE + MSIX)
```powershell
# Metodo 1: Script automatico
.\build.ps1 windows

# Metodo 2: Manuale
flutter build windows --release
flutter pub run msix:create
```

**Output:**
- EXE: `build\windows\x64\runner\Release\ingresso_uscita.exe`
- MSIX: `build\windows\x64\runner\Release\ingresso_uscita.msix`

---

### 🤖 Android (APK)
```powershell
# Metodo 1: Script automatico
.\build.ps1 android

# Metodo 2: Manuale
flutter build apk --release --split-per-abi
```

**Output:**
- APK ARM64: `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (per smartphone moderni)
- APK ARMv7: `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` (per smartphone vecchi)

---

### 🎯 Build Tutto
```powershell
.\build.ps1 all
```

Genera Windows + Android in un comando.

---

## ⚙️ Prima Configurazione

### Android: Crea Keystore (Prima Volta)

```powershell
# 1. Genera keystore per firma
keytool -genkey -v -keystore c:\Users\frag_\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. Crea file android/key.properties
# Contenuto:
storePassword=tua_password
keyPassword=tua_password
keyAlias=upload
storeFile=c:/Users/frag_/upload-keystore.jks
```

⚠️ **Salva password del keystore in luogo sicuro!** Se la perdi non potrai più aggiornare l'app.

---

## 📦 Distribuzione

### Windows
**Opzione 1:** Distribuisci `ingresso_uscita.msix` (consigliato)
- Doppio click per installare
- Icona automatica in menu Start

**Opzione 2:** ZIP della cartella `Release\`
- Include EXE + DLL + data/
- User estrae ed esegue EXE

### Android
**Opzione 1:** Invia `app-arm64-v8a-release.apk`
- Funziona su 95% smartphone (2019+)
- User installa APK

**Opzione 2:** Google Play Store
- Build con: `flutter build appbundle --release`
- Upload su Play Console

---

## 📋 Documentazione Completa

Vedi **BUILD_GUIDE.md** per:
- Troubleshooting
- Firma digitale
- Google Play Store
- Configurazione avanzata

---

## ✅ Checklist Release

- [ ] Aggiornato `version` in `pubspec.yaml`
- [ ] Testato in modalità release
- [ ] Build Windows completato
- [ ] Build Android completato
- [ ] Testato installer/APK su macchina pulita
- [ ] Aggiornato CHANGELOG.md
- [ ] Tag Git versione (es: `git tag v1.0.0`)
