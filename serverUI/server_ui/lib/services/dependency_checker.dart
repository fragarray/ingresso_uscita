import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servizio per verificare e installare le dipendenze necessarie
class DependencyChecker {
  
  /// Verifica se Node.js è installato
  static Future<DependencyStatus> checkNodeJs() async {
    try {
      final command = Platform.isWindows ? 'node.exe' : 'node';
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [command],
      );
      
      if (result.exitCode == 0) {
        // Node.js trovato, ottieni la versione
        final versionResult = await Process.run('node', ['--version']);
        final version = versionResult.stdout.toString().trim();
        return DependencyStatus(
          name: 'Node.js',
          isInstalled: true,
          version: version,
          path: result.stdout.toString().trim().split('\n').first,
        );
      }
      
      return DependencyStatus(
        name: 'Node.js',
        isInstalled: false,
        message: 'Node.js non trovato nel sistema',
      );
    } catch (e) {
      return DependencyStatus(
        name: 'Node.js',
        isInstalled: false,
        message: 'Errore durante la verifica: $e',
      );
    }
  }

  /// Verifica se npm è installato
  static Future<DependencyStatus> checkNpm() async {
    try {
      final command = Platform.isWindows ? 'npm.cmd' : 'npm';
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [command],
      );
      
      if (result.exitCode == 0) {
        // npm trovato, ottieni la versione
        final versionResult = await Process.run(
          Platform.isWindows ? 'npm.cmd' : 'npm',
          ['--version'],
        );
        final version = versionResult.stdout.toString().trim();
        return DependencyStatus(
          name: 'npm',
          isInstalled: true,
          version: version,
          path: result.stdout.toString().trim().split('\n').first,
        );
      }
      
      return DependencyStatus(
        name: 'npm',
        isInstalled: false,
        message: 'npm non trovato (dovrebbe essere installato con Node.js)',
      );
    } catch (e) {
      return DependencyStatus(
        name: 'npm',
        isInstalled: false,
        message: 'Errore durante la verifica: $e',
      );
    }
  }

  /// Verifica tutte le dipendenze
  static Future<List<DependencyStatus>> checkAll() async {
    return Future.wait([
      checkNodeJs(),
      checkNpm(),
    ]);
  }

  /// Apre la pagina di download di Node.js nel browser
  static Future<void> openNodeJsDownloadPage() async {
    const url = 'https://nodejs.org/';
    
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      }
    } catch (e) {
      debugPrint('Errore aprendo browser: $e');
    }
  }

  /// Scarica e avvia l'installer di Node.js (Windows)
  static Future<InstallationResult> installNodeJsWindows() async {
    if (!Platform.isWindows) {
      return InstallationResult(
        success: false,
        message: 'Installazione automatica disponibile solo su Windows',
      );
    }

    try {
      // Su Windows, usiamo winget se disponibile
      final wingetCheck = await Process.run('where', ['winget']);
      
      if (wingetCheck.exitCode == 0) {
        // winget disponibile
        debugPrint('Installazione Node.js tramite winget...');
        
        final result = await Process.run(
          'winget',
          ['install', 'OpenJS.NodeJS.LTS', '--silent', '--accept-source-agreements', '--accept-package-agreements'],
          runInShell: true,
        );
        
        if (result.exitCode == 0) {
          return InstallationResult(
            success: true,
            message: 'Node.js installato con successo! Riavvia l\'applicazione per applicare le modifiche.',
          );
        } else {
          return InstallationResult(
            success: false,
            message: 'Errore durante l\'installazione: ${result.stderr}',
          );
        }
      } else {
        // winget non disponibile, apri la pagina di download
        return InstallationResult(
          success: false,
          message: 'winget non disponibile. Apro la pagina di download...',
          requiresManualInstall: true,
        );
      }
    } catch (e) {
      return InstallationResult(
        success: false,
        message: 'Errore: $e',
        requiresManualInstall: true,
      );
    }
  }

  /// Istruzioni per installare Node.js su Linux
  static String getLinuxInstallInstructions() {
    return '''
Per installare Node.js su Ubuntu/Debian:

sudo apt update
sudo apt install nodejs npm

Per altre distribuzioni, visita: https://nodejs.org/
''';
  }

  /// Istruzioni per installare Node.js su macOS
  static String getMacOsInstallInstructions() {
    return '''
Per installare Node.js su macOS:

1. Tramite Homebrew:
   brew install node

2. Oppure scarica l'installer da:
   https://nodejs.org/
''';
  }
}

/// Stato di una dipendenza
class DependencyStatus {
  final String name;
  final bool isInstalled;
  final String? version;
  final String? path;
  final String? message;

  DependencyStatus({
    required this.name,
    required this.isInstalled,
    this.version,
    this.path,
    this.message,
  });

  String get statusText {
    if (isInstalled) {
      return '✅ Installato${version != null ? " ($version)" : ""}';
    } else {
      return '❌ Non installato';
    }
  }
}

/// Risultato di un'installazione
class InstallationResult {
  final bool success;
  final String message;
  final bool requiresManualInstall;

  InstallationResult({
    required this.success,
    required this.message,
    this.requiresManualInstall = false,
  });
}
