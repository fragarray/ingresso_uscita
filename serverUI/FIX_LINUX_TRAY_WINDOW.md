# Fix: Gestione System Tray e Finestra su Linux

## Problema
Su Ubuntu/Linux, l'applicazione Server Manager aveva due problemi principali:

1. **Tasto X della finestra**: Premendo X, l'applicazione si chiudeva completamente invece di minimizzarsi nella system tray
2. **Minimizza nel tray**: Premendo "Minimizza nel tray", la tray veniva creata ma la finestra rimaneva aperta

## Soluzione Implementata

### 1. Aggiunta Dipendenza `window_manager`
Aggiunta la dipendenza `window_manager: ^0.3.9` nel `pubspec.yaml` per gestire le finestre desktop su Linux, Windows e macOS.

### 2. Inizializzazione Window Manager
Modificato `main.dart` per:
- Importare `window_manager`
- Inizializzare il window manager per le piattaforme desktop
- Configurare le opzioni della finestra
- Impostare `setPreventClose(true)` per intercettare l'evento di chiusura

### 3. Implementazione WindowListener
- Aggiunto `WindowListener` al `ServerManagerHome`
- Implementato `onWindowClose()` per gestire la pressione del tasto X
- Implementato `onWindowRestore()` per aggiornare lo stato quando la finestra viene ripristinata
- Il tasto X ora minimizza nella tray invece di chiudere l'applicazione

### 4. Aggiornamento TrayService
Modificato `services/tray_service.dart` per:
- Usare `window_manager` per mostrare/nascondere la finestra su tutte le piattaforme desktop
- Implementare correttamente `hideToTray()` con `windowManager.hide()`
- Implementare correttamente `_showApplication()` con `windowManager.show()`, `focus()` e `restore()`
- Gestire la chiusura dell'applicazione con `windowManager.destroy()`

### 5. Semplificazione HomeScreen
- Rimosso il `PopScope` che causava conflitti
- Rimosso il metodo `_onWillPop()` non più necessario
- Aggiornato il menu "Minimizza nel tray" per usare `TrayService.hideToTray()`

## Comportamento Attuale

### Linux (Ubuntu)
- ✅ **Tasto X**: Minimizza l'applicazione nella system tray
- ✅ **Minimizza nel tray**: Nasconde correttamente la finestra
- ✅ **Click su tray icon**: Ripristina la finestra
- ✅ **Menu tray "Mostra Applicazione"**: Ripristina la finestra
- ✅ **Menu tray "Esci"**: Chiude completamente l'applicazione

### Windows
- ✅ Mantiene il comportamento precedente con supporto migliorato
- ✅ Fallback ai metodi nativi se window_manager non funziona

### Funzionalità Cross-Platform
- ✅ Gestione unificata delle finestre su tutte le piattaforme desktop
- ✅ System tray funzionante su Linux, Windows e macOS
- ✅ Stato dell'applicazione sincronizzato con la visibilità della finestra

## File Modificati
- `/serverUI/server_ui/pubspec.yaml` - Aggiunta dipendenza window_manager
- `/serverUI/server_ui/lib/main.dart` - Inizializzazione window manager e WindowListener
- `/serverUI/server_ui/lib/services/tray_service.dart` - Gestione finestre con window_manager
- `/serverUI/server_ui/lib/screens/home_screen.dart` - Semplificazione gestione chiusura

## Test
Testato su:
- ✅ Ubuntu 22.04 LTS
- ✅ Windows 10/11 (compatibilità mantenuta)

## Note Tecniche
- La dipendenza `window_manager` è specifica per applicazioni desktop Flutter
- Compatibile con Flutter 3.x
- Gestisce automaticamente le differenze tra window manager dei vari sistemi operativi
- Mantiene retrocompatibilità con le versioni precedenti di Windows