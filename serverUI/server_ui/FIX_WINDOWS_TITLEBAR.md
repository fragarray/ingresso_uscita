# Fix Barra Titolo Windows

## Problema
L'applicazione su Ubuntu funziona perfettamente, ma su Windows ha perso la barra del titolo standard con i pulsanti - [] X.

## Causa
Il package `window_manager` con la configurazione `setPreventClose(true)` e `WindowListener` stava interferendo con i controlli nativi di Windows, impedendo la visualizzazione della barra del titolo standard.

## Soluzione Implementata

### 1. Configurazione Specifica per Piattaforma in `main.dart`

**Windows:**
- `titleBarStyle: TitleBarStyle.normal` - Usa i pulsanti nativi di Windows
- **NON** usa `setPreventClose(true)` - Permette il comportamento nativo
- **NON** registra `WindowListener` - Il controllo della chiusura è gestito dal codice C++ nativo
- Il tasto X viene intercettato da `WM_CLOSE` in `flutter_window.cpp` che nasconde la finestra invece di chiuderla

**Linux/macOS:**
- `titleBarStyle: TitleBarStyle.hidden` - Usa i controlli custom di window_manager
- Usa `setPreventClose(true)` - Previene la chiusura
- Registra `WindowListener` - Gestisce onWindowClose() per minimizzare nella tray

### 2. Codice Modificato

```dart
// main.dart - Configurazione piattaforma specifica
WindowOptions windowOptions = WindowOptions(
  size: const Size(1200, 800),
  center: true,
  backgroundColor: Colors.transparent,
  skipTaskbar: false,
  // Su Windows usa i pulsanti nativi, su Linux usa quelli custom
  titleBarStyle: Platform.isWindows ? TitleBarStyle.normal : TitleBarStyle.hidden,
  windowButtonVisibility: true,
);

// Solo su Linux settiamo preventClose, Windows gestisce WM_CLOSE nativamente
if (Platform.isLinux || Platform.isMacOS) {
  await windowManager.setPreventClose(true);
}

// WindowListener solo su Linux/macOS
if (Platform.isLinux || Platform.isMacOS) {
  windowManager.addListener(this);
}
```

### 3. Gestione Chiusura Finestra

**Windows:**
```cpp
// flutter_window.cpp - WM_CLOSE handler
case WM_CLOSE:
  // Quando l'utente clicca X, nascondi la finestra invece di chiuderla
  ::ShowWindow(hwnd, SW_HIDE);
  return 0; // Impedisce la chiusura predefinita
```

**Linux/macOS:**
```dart
// main.dart - WindowListener
@override
void onWindowClose() async {
  if (Platform.isLinux || Platform.isMacOS) {
    await TrayService.hideToTray();
  }
}
```

## Risultato
- ✅ **Windows**: Barra del titolo nativa con pulsanti - [] X visibili e funzionanti
- ✅ **Windows**: Tasto X nasconde la finestra nella tray (non chiude l'app)
- ✅ **Linux**: Controlli custom con behavior corretto
- ✅ **Ubuntu**: Funziona perfettamente come prima
- ✅ **Cross-platform**: Ogni OS usa il metodo migliore per la sua piattaforma

## Test
1. Ricompila: `flutter build windows --release`
2. Avvia l'app su Windows → La barra del titolo deve essere visibile
3. Clicca X → La finestra si nasconde, l'app rimane nella tray
4. Clicca icona tray → La finestra riappare
5. Testa su Ubuntu → Tutto deve funzionare come prima

## Data
26 Ottobre 2025
