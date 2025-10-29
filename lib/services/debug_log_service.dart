import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DebugLogService {
  static final DebugLogService _instance = DebugLogService._internal();
  factory DebugLogService() => _instance;
  DebugLogService._internal();

  static const String _logsKey = 'debug_logs';
  static const int _maxLogs = 100; // Mantieni solo gli ultimi 100 log

  /// Aggiunge un log persistente
  Future<void> log(String category, String message) async {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final logEntry = '[$timestamp] [$category] $message';
    
    // Stampa anche in console per debug immediato
    print(logEntry);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> logs = prefs.getStringList(_logsKey) ?? [];
      
      // Aggiungi nuovo log
      logs.add(logEntry);
      
      // Mantieni solo gli ultimi N log
      if (logs.length > _maxLogs) {
        logs = logs.sublist(logs.length - _maxLogs);
      }
      
      await prefs.setStringList(_logsKey, logs);
    } catch (e) {
      print('[DebugLog] Errore salvataggio log: $e');
    }
  }

  /// Ottieni tutti i log salvati
  Future<List<String>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_logsKey) ?? [];
    } catch (e) {
      print('[DebugLog] Errore lettura log: $e');
      return [];
    }
  }

  /// Pulisci tutti i log
  Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
    } catch (e) {
      print('[DebugLog] Errore pulizia log: $e');
    }
  }

  /// Ottieni log come stringa singola
  Future<String> getLogsAsString() async {
    final logs = await getLogs();
    return logs.join('\n');
  }
}