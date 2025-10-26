import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';
import '../providers/server_provider.dart';

class TrayService {
  static SystemTray? _tray;
  static ServerProvider? _serverProvider;
  static bool _isSupported = false;

  static Future<void> initialize(ServerProvider serverProvider) async {
    _serverProvider = serverProvider;
    
    try {
      _tray = SystemTray();

      // Configura l'icona del system tray
      await _tray!.initSystemTray(
        title: "Server Manager",
        iconPath: _getIconPath(),
      );

      // Crea il menu del system tray
      await _createTrayMenu();
      _isSupported = true;
      
      debugPrint('✅ System tray inizializzato con successo');
    } catch (e) {
      debugPrint('⚠️ System tray non disponibile: $e');
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
    await windowManager.show();
    await windowManager.focus();
    _serverProvider?.setMinimized(false);
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
    
    // Chiude l'applicazione
    await windowManager.destroy();
  }

  static String _getIconPath() {
    // Percorso dell'icona del system tray
    // Dovresti sostituire questo con il percorso effettivo della tua icona
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