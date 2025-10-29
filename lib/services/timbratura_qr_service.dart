import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'gps_service.dart';
import 'deep_link_service.dart';
import 'debug_log_service.dart';

class TimbratureQRService {
  static final TimbratureQRService _instance = TimbratureQRService._internal();
  factory TimbratureQRService() => _instance;
  TimbratureQRService._internal();

  final _debugLog = DebugLogService();

  /// Trova l'ID numerico del cantiere dal nome
  Future<String?> _getWorkSiteId({
    required String cantiereName,
    required String serverHost,
    required int serverPort,
  }) async {
    try {
      final url = Uri.parse('http://$serverHost:$serverPort/api/worksites');
      await _debugLog.log('Timbratura', '🔍 Ricerca cantiere: $cantiereName su $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> workSites = jsonDecode(response.body);
        
        // Cerca il cantiere per nome
        for (final site in workSites) {
          if (site['name'].toString().toLowerCase() == cantiereName.toLowerCase()) {
            await _debugLog.log('Timbratura', '✅ Cantiere trovato: ${site['name']} -> ID ${site['id']}');
            return site['id'].toString();
          }
        }
        
        await _debugLog.log('Timbratura', '⚠️ Cantiere $cantiereName non trovato');
        return null;
      } else {
        await _debugLog.log('Timbratura', '❌ Errore ricerca cantiere: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      await _debugLog.log('Timbratura', '❌ Errore ricerca cantiere: $e');
      return null;
    }
  }

  /// Esegue timbratura automatica da QR code
  Future<TimbratureResult> timbraFromQR({
    required QRTimbratureData qrData,
    required String userId,
    required String authToken,
  }) async {
    await _debugLog.log('Timbratura', '🎯 INIZIO - Avvio timbratura per cantiere: ${qrData.cantiereName}');
    await _debugLog.log('Timbratura', '🎯 UserId: $userId, Server: ${qrData.serverHost}:${qrData.serverPort}');

    try {
      // 1. Ottieni GPS (dovrebbe essere già precaricato)
      await _debugLog.log('Timbratura', '📍 STEP 1 - Ottenimento GPS...');
      final gpsService = GPSService();
      Position? position = await gpsService.getCurrentPosition();

      if (position == null) {
        await _debugLog.log('Timbratura', '❌ ERRORE STEP 1 - GPS nullo');
        return TimbratureResult.error('Impossibile ottenere posizione GPS');
      }
      
      await _debugLog.log('Timbratura', '✅ STEP 1 COMPLETATO - GPS: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');

      // Verifica accuratezza (opzionale)
      if (position.accuracy > 50) {
        print('[Timbratura] ⚠️ Accuratezza GPS bassa: ${position.accuracy}m');
        // TODO: Mostra warning all'utente
      }

      // 2. Determina tipo timbratura (IN o OUT)
      await _debugLog.log('Timbratura', '🔍 STEP 2 - Determinazione tipo timbratura...');
      final tipo = await _determinaTipoTimbratura(
        userId: userId,
        cantiereId: qrData.cantiereId,
        serverHost: qrData.serverHost,
        serverPort: qrData.serverPort,
        authToken: authToken,
      );

      await _debugLog.log('Timbratura', '✅ STEP 2 COMPLETATO - Tipo: $tipo');

      // 3. Invia timbratura al server
      await _debugLog.log('Timbratura', '📤 STEP 3 - Invio timbratura al server...');
      final result = await _sendTimbratura(
        userId: userId,
        cantiereId: qrData.cantiereId,
        cantiereName: qrData.cantiereName,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        tipo: tipo,
        serverHost: qrData.serverHost,
        serverPort: qrData.serverPort,
        authToken: authToken,
      );

      await _debugLog.log('Timbratura', '✅ STEP 3 COMPLETATO - Risultato: ${result.success}');
      return result;

    } catch (e, stackTrace) {
      print('[Timbratura] ❌ ERRORE GENERALE: $e');
      print('[Timbratura] 📚 STACK TRACE: $stackTrace');
      return TimbratureResult.error('Errore durante la timbratura: $e');
    }
  }

  /// Determina automaticamente se timbrare IN o OUT usando API esistente
  Future<String> _determinaTipoTimbratura({
    required String userId,
    required String cantiereId,
    required String serverHost,
    required int serverPort,
    required String authToken,
  }) async {
    // Usa endpoint esistente /api/attendance per ottenere ultima timbratura
    try {
      final url = Uri.parse('http://$serverHost:$serverPort/api/attendance');
      await _debugLog.log('Timbratura', '🔍 Chiamata GET ultima timbratura: $url?employeeId=$userId');
      
      final response = await http.get(
        Uri.parse('$url?employeeId=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      await _debugLog.log('Timbratura', '🔍 Response status: ${response.statusCode}');
      await _debugLog.log('Timbratura', '🔍 Response body: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> records = jsonDecode(response.body);
        
        if (records.isNotEmpty) {
          // Prendi l'ultima timbratura (la prima nell'array ordinato)
          final lastRecord = records[0];
          final lastType = lastRecord['type'] as String;
          await _debugLog.log('Timbratura', '🔍 Ultimo tipo trovato: $lastType');

          // Se ultima timbratura era 'in' → ora fai 'out'  
          // Se ultima timbratura era 'out' → ora fai 'in'
          if (lastType == 'in') {
            await _debugLog.log('Timbratura', '🔍 Ultimo era IN → ora OUT');
            return 'out';
          } else {
            await _debugLog.log('Timbratura', '🔍 Ultimo era OUT → ora IN');
            return 'in';
          }
        } else {
          // Nessuna timbratura precedente → fai IN
          await _debugLog.log('Timbratura', '🔍 Nessuna timbratura precedente → IN');
          return 'in';
        }
      } else {
        // Se errore, default a IN
        await _debugLog.log('Timbratura', '🔍 Status non 200 → default IN');
        return 'in';
      }
    } catch (e) {
      await _debugLog.log('Timbratura', '⚠️ ERRORE determinazione tipo, default a IN: $e');
      return 'in';
    }
  }

  /// Invia timbratura al server usando endpoint esistente
  Future<TimbratureResult> _sendTimbratura({
    required String userId,
    required String cantiereId,
    required String cantiereName,
    required double latitude,
    required double longitude,
    required double accuracy,
    required String tipo,
    required String serverHost,
    required int serverPort,
    required String authToken,
  }) async {
    try {
      // Prima trova l'ID numerico del cantiere
      final workSiteId = await _getWorkSiteId(
        cantiereName: cantiereName,
        serverHost: serverHost,
        serverPort: serverPort,
      );
      
      if (workSiteId == null) {
        return TimbratureResult.error('Cantiere "$cantiereName" non trovato sul server');
      }
      
      final url = Uri.parse('http://$serverHost:$serverPort/api/attendance');
      
      final body = {
        'employeeId': int.parse(userId),
        'workSiteId': int.parse(workSiteId),
        'timestamp': DateTime.now().toIso8601String(),
        'type': tipo, // 'in' o 'out'
        'deviceInfo': 'QR Code Scanner',
        'latitude': latitude,
        'longitude': longitude,
        'isForced': false,
      };

      await _debugLog.log('Timbratura', '📤 Invio al server: $url');
      await _debugLog.log('Timbratura', '📦 Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: 15));

      await _debugLog.log('Timbratura', '📥 Response status: ${response.statusCode}');
      await _debugLog.log('Timbratura', '📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          return TimbratureResult.success(
            tipo: tipo == 'in' ? 'ingresso' : 'uscita',
            cantiereName: cantiereName,
            timestamp: DateTime.now(),
            latitude: latitude,
            longitude: longitude,
            message: 'Timbratura registrata con successo',
          );
        } else {
          return TimbratureResult.error('Errore dal server: ${data['error'] ?? 'Sconosciuto'}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        return TimbratureResult.error(errorData['error'] ?? 'Errore HTTP ${response.statusCode}');
      }

    } catch (e) {
      await _debugLog.log('Timbratura', '❌ Errore invio: $e');
      return TimbratureResult.error('Errore connessione al server: $e');
    }
  }
}

/// Risultato timbratura
class TimbratureResult {
  final bool success;
  final String? tipo;
  final String? cantiereName;
  final DateTime? timestamp;
  final double? latitude;
  final double? longitude;
  final String? message;
  final String? error;

  TimbratureResult._({
    required this.success,
    this.tipo,
    this.cantiereName,
    this.timestamp,
    this.latitude,
    this.longitude,
    this.message,
    this.error,
  });

  factory TimbratureResult.success({
    required String tipo,
    required String cantiereName,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    String? message,
  }) {
    return TimbratureResult._(
      success: true,
      tipo: tipo,
      cantiereName: cantiereName,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      message: message,
    );
  }

  factory TimbratureResult.error(String error) {
    return TimbratureResult._(
      success: false,
      error: error,
    );
  }
}