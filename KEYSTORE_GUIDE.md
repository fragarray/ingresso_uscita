# 🔐 Creare Keystore per Android - Guida Rapida

## 📝 Quando Serve

Il **keystore** è necessario per:
- ✅ Firmare APK di **produzione**
- ✅ Pubblicare su **Google Play Store**
- ✅ Aggiornare l'app in futuro

**NON serve** per:
- ❌ Build di test/debug
- ❌ Installazione diretta su dispositivo per sviluppo

---

## 🚀 Creazione Keystore (5 minuti)

### Step 1: Genera Keystore

Apri PowerShell e esegui:

```powershell
keytool -genkey -v -keystore c:\Users\frag_\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 2: Compila le Informazioni

Ti chiederà:

```
Enter keystore password: tuaPassword123        ← Scegli password forte
Re-enter new password: tuaPassword123          ← Ripeti password

What is your first and last name?
  [Unknown]:  FragArray                        ← Nome/Azienda

What is the name of your organizational unit?
  [Unknown]:  Development                      ← Reparto (opzionale)

What is the name of your organization?
  [Unknown]:  FragArray                        ← Organizzazione

What is the name of your City or Locality?
  [Unknown]:  Roma                             ← Città

What is the name of your State or Province?
  [Unknown]:  RM                               ← Provincia

What is the two-letter country code for this unit?
  [Unknown]:  IT                               ← Codice paese

Is CN=FragArray, OU=Development, O=FragArray, L=Roma, ST=RM, C=IT correct?
  [no]:  yes                                   ← Conferma

Enter key password for <upload>
        (RETURN if same as keystore password):  ← Premi INVIO (usa stessa password)
```

### Step 3: Verifica Creazione

```powershell
# Verifica che il file esista
Test-Path c:\Users\frag_\upload-keystore.jks
# Output: True
```

---

## 📄 Configurazione Progetto

### Step 1: Crea file key.properties

Crea il file `android/key.properties` con questo contenuto:

```properties
storePassword=tuaPassword123
keyPassword=tuaPassword123
keyAlias=upload
storeFile=c:/Users/frag_/upload-keystore.jks
```

⚠️ **Usa `/` non `\` nel path!**

### Step 2: Crea file con PowerShell

```powershell
# Naviga nella cartella android
cd "c:\Users\frag_\Documents\Progetti flutter\ingresso_uscita\android"

# Crea file key.properties
@"
storePassword=tuaPassword123
keyPassword=tuaPassword123
keyAlias=upload
storeFile=c:/Users/frag_/upload-keystore.jks
"@ | Out-File -FilePath "key.properties" -Encoding UTF8
```

### Step 3: Verifica Configurazione

```powershell
# Verifica che il file esista
Test-Path android\key.properties
# Output: True

# Visualizza contenuto
Get-Content android\key.properties
```

---

## 🧪 Test Build con Keystore

```powershell
# Build APK firmato con keystore di produzione
flutter build apk --release
```

Se vedi questo output:
```
✓ Built build\app\outputs\flutter-apk\app-release.apk (XX MB)
```

✅ **Successo!** L'APK è firmato con il tuo keystore.

---

## 🔒 Sicurezza

### ⚠️ IMPORTANTE: Salva Queste Informazioni

Crea un file `KEYSTORE_INFO.txt` in **luogo sicuro** (NON nel progetto Git):

```
KEYSTORE INFORMAZIONI - Ingresso Uscita
========================================

File: c:\Users\frag_\upload-keystore.jks
Password Keystore: tuaPassword123
Password Key: tuaPassword123
Alias: upload

Data Creazione: 15/10/2025
Validità: 10000 giorni (fino al 2052)

ATTENZIONE: Se perdi questa password o il file .jks,
NON potrai più aggiornare l'app su Google Play!
```

### 📦 Backup Keystore

```powershell
# Copia keystore in luogo sicuro
Copy-Item c:\Users\frag_\upload-keystore.jks -Destination "D:\Backup\upload-keystore.jks"

# O carica su cloud (Google Drive, OneDrive, ecc.)
```

### 🚫 NON Committare su Git

Verifica `.gitignore` contenga:

```gitignore
# Signing files
android/key.properties
*.jks
*.keystore
```

---

## 🆘 Troubleshooting

### Errore: "keytool: command not found"

**Causa:** Java JDK non installato o non nel PATH

**Soluzione:**
```powershell
# Verifica Java installato
java -version

# Se non installato, scarica da:
# https://www.oracle.com/java/technologies/downloads/

# Aggiungi al PATH:
$env:Path += ";C:\Program Files\Java\jdk-XX\bin"
```

### Errore: "Keystore file does not exist"

**Causa:** Path errato in `key.properties`

**Soluzione:** Usa `/` invece di `\`:
```properties
# ❌ SBAGLIATO
storeFile=c:\Users\frag_\upload-keystore.jks

# ✅ CORRETTO
storeFile=c:/Users/frag_/upload-keystore.jks
```

### Errore: "Incorrect keystore password"

**Causa:** Password sbagliata in `key.properties`

**Soluzione:** Verifica password (case-sensitive!)

### Build Fallito: ProGuard Error

**Causa:** Ottimizzazione troppo aggressiva

**Soluzione Temporanea:** Disabilita ProGuard in `build.gradle.kts`:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = false  // Cambia da true a false
        isShrinkResources = false
    }
}
```

---

## 📊 Differenza Debug vs Release

| Aspetto | Debug Build | Release Build |
|---------|-------------|---------------|
| **Firma** | Keystore debug auto-generato | Tuo keystore produzione |
| **Dimensione** | ~40 MB | ~25 MB (ottimizzato) |
| **Performance** | Lento | Veloce |
| **Google Play** | ❌ Non accettato | ✅ Richiesto |
| **Aggiornamenti** | N/A | Stesso keystore obbligatorio |

---

## ✅ Checklist Finale

Prima di distribuire l'APK:

- [ ] Keystore creato (`upload-keystore.jks`)
- [ ] Password salvata in luogo sicuro
- [ ] File `key.properties` configurato
- [ ] Backup keystore fatto
- [ ] `.gitignore` aggiornato
- [ ] Build test completato: `flutter build apk --release`
- [ ] APK installato e testato su dispositivo reale

---

## 🎓 Risorse

- **Documentazione Flutter:** https://docs.flutter.dev/deployment/android#signing-the-app
- **Android Developer:** https://developer.android.com/studio/publish/app-signing
- **Java keytool:** https://docs.oracle.com/javase/8/docs/technotes/tools/windows/keytool.html

---

## 🚀 Comandi Rapidi

```powershell
# Crea keystore
keytool -genkey -v -keystore c:\Users\frag_\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Verifica keystore
keytool -list -v -keystore c:\Users\frag_\upload-keystore.jks

# Build APK firmato
flutter build apk --release --split-per-abi

# Build App Bundle per Play Store
flutter build appbundle --release
```

---

**Dopo aver creato il keystore, esegui di nuovo:**
```powershell
.\build.ps1 android
```

E non vedrai più il warning! 🎉
