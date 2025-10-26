import 'dart:io' show Platform, exit;
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/server_provider.dart';

class TrayService {
  static SystemTray? _tray;
  static ServerProvider? _serverProvider;
  static bool _isSupported = false;
  static const platform = MethodChannel('com.fragarray.sinergywork/window');

  static Future<void> initialize(ServerProvider serverProvider) async {
    _serverProvider = serverProvider;
    
    // System tray non sempre funziona bene su tutte le piattaforme Windows
    // Proviamo ad inizializzarlo, ma gestiamo gracefully l'errore
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      debugPrint('⚠️ System tray non supportato su questa piattaforma');
      _isSupported = false;
      return;
    }
    
    try {
      _tray = SystemTray();

      // Configura l'icona del system tray
      await _tray!.initSystemTray(
        title: "Sinergy Work Server",
        iconPath: _getIconPath(),
      );

      // Registra il callback per il click sull'icona del tray
      _tray!.registerSystemTrayEventHandler((eventName) {
        debugPrint('System tray event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          _showApplication();
        } else if (eventName == kSystemTrayEventRightClick) {
          _tray!.popUpContextMenu();
        }
      });

      // Crea il menu del system tray
      await _createTrayMenu();
      _isSupported = true;
      
      debugPrint('✅ System tray inizializzato con successo');
    } catch (e) {
      debugPrint('⚠️ System tray non disponibile: $e');
      debugPrint('   L\'applicazione funzionerà normalmente senza tray icon');
      _isSupported = false;
      _tray = null;
    }
  }

  static bool get isSupported => _isSupported;

  static Future<void> _createTrayMenu() async {
    if (!_isSupported || _tray == null || _serverProvider == null) return;

    try {
      final menu = Menu();

      // Stato dei server
      final runningCount = _serverProvider!.servers.where((s) => s.isRunning).length;
      final totalCount = _serverProvider!.servers.length;
      
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Server attivi: $runningCount/$totalCount',
          enabled: false,
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Mostra Applicazione',
          onClicked: (_) => _showApplication(),
        ),
        MenuItemLabel(
          label: 'Ferma tutti i server',
          enabled: runningCount > 0,
          onClicked: (_) => _stopAllServers(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Esci',
          onClicked: (_) => _exitApplication(),
        ),
      ]);

      await _tray!.setContextMenu(menu);
    } catch (e) {
      debugPrint('⚠️ Errore aggiornamento menu tray: $e');
    }
  }

  static Future<void> updateTrayMenu() async {
    if (_isSupported) {
      await _createTrayMenu();
    }
  }

  static Future<void> _showApplication() async {
    try {
      if (Platform.isWindows) {
        // Su Windows usa il metodo nativo (non window_manager)
        try {
          await platform.invokeMethod('show');
        } catch (e) {
          debugPrint('⚠️ Metodo nativo fallito: $e');
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        // Su Linux/macOS usa window_manager
        try {
          await windowManager.show();
          await windowManager.focus();
          await windowManager.restore();
        } catch (e) {
          debugPrint('⚠️ Window manager fallito: $e');
        }
      }
      _serverProvider?.setMinimized(false);
      debugPrint('✅ Applicazione mostrata');
    } catch (e) {
      debugPrint('⚠️ Errore mostrando applicazione: $e');
    }
  }

  /// Nascondi l'applicazione nella tray
  static Future<void> hideToTray() async {
    try {
      if (Platform.isWindows) {
        // Su Windows usa il metodo nativo (non window_manager)
        try {
          await platform.invokeMethod('hide');
        } catch (e) {
          debugPrint('⚠️ Metodo nativo fallito: $e');
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        // Su Linux/macOS usa window_manager
        try {
          await windowManager.hide();
        } catch (e) {
          debugPrint('⚠️ Window manager fallito: $e');
        }
      }
      _serverProvider?.setMinimized(true);
      debugPrint('✅ Applicazione minimizzata nella tray');
    } catch (e) {
      debugPrint('⚠️ Errore nascondendo applicazione: $e');
    }
  }

  static Future<void> _stopAllServers() async {
    await _serverProvider?.stopAllServers();
    await updateTrayMenu();
  }

  static Future<void> _exitApplication() async {
    // Ferma tutti i server prima di uscire
    await _serverProvider?.stopAllServers();
    
    // Pulisce il system tray
    await _tray?.destroy();
    
    // Chiude l'applicazione usando il metodo appropriato per la piattaforma
    if (Platform.isWindows) {
      // Su Windows usa il metodo nativo
      try {
        await platform.invokeMethod('exit');
      } catch (e) {
        debugPrint('⚠️ Metodo nativo fallito: $e');
        exit(0);
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      // Su Linux/macOS usa window_manager
      try {
        await windowManager.destroy();
      } catch (e) {
        debugPrint('⚠️ Window manager fallito: $e');
        exit(0);
      }
    } else {
      exit(0);
    }
  }

  static String _getIconPath() {
    // Percorso dell'icona del system tray
    // Su Windows cerca l'icona nella cartella assets
    if (Platform.isWindows) {
      return 'assets/images/tray_icon.ico';
    }
    return 'assets/images/tray_icon.png';
  }

  static Future<void> dispose() async {
    if (_isSupported && _tray != null) {
      try {
        await _tray!.destroy();
      } catch (e) {
        debugPrint('⚠️ Errore chiusura tray: $e');
      }
    }
  }
}