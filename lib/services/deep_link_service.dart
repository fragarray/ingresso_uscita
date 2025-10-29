import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription? _sub;
  Function(QRTimbratureData)? onQRScanned;

  /// Inizializza il listener per deep link
  Future<void> initialize() async {
    // Gestisci deep link che ha aperto l'app (cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      print('[DeepLink] Errore getting initial link: $e');
    }

    // Ascolta deep link mentre app è in background/foreground
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri.toString());
    }, onError: (err) {
      print('[DeepLink] Errore stream: $err');
    });
  }

  /// Parse e valida deep link
  void _handleDeepLink(String link) {
    print('[DeepLink] Ricevuto: $link');

    if (!link.startsWith('sinergywork://scan/')) {
      print('[DeepLink] ❌ Schema non valido');
      return;
    }

    try {
      // Estrai parte Base64
      final base64Part = link.replaceFirst('sinergywork://scan/', '');
      
      // Decodifica Base64 → JSON string
      final jsonString = utf8.decode(base64Decode(base64Part));
      
      // Parse JSON
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      // Crea oggetto dati
      final qrData = QRTimbratureData.fromJson(data);
      
      // Valida firma
      if (!_validateSignature(qrData)) {
        print('[DeepLink] ❌ Firma non valida');
        throw Exception('Firma QR code non valida');
      }
      
      // Valida timestamp (max 24h)
      if (!_validateTimestamp(qrData.timestamp)) {
        print('[DeepLink] ❌ QR code scaduto');
        throw Exception('QR code scaduto (max 24h)');
      }
      
      print('[DeepLink] ✅ QR validato: Cantiere ${qrData.cantiereName}');
      
      // Notifica listener
      if (onQRScanned != null) {
        onQRScanned!(qrData);
      }
      
    } catch (e) {
      print('[DeepLink] ❌ Errore parsing: $e');
      // TODO: Mostra errore all'utente
    }
  }

  /// Valida firma SHA-256
  bool _validateSignature(QRTimbratureData data) {
    const String SECRET_KEY = "SinergyWork2025SecretKey";
    final signatureData = '${data.cantiereId}|${data.timestamp}|$SECRET_KEY';
    final bytes = utf8.encode(signatureData);
    final digest = sha256.convert(bytes);
    final expectedSignature = digest.toString();
    
    return data.signature == expectedSignature;
  }

  /// Valida timestamp (max 24h)
  bool _validateTimestamp(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    const maxAge = 24 * 60 * 60; // 24 ore in secondi
    
    return diff >= 0 && diff <= maxAge;
  }

  void dispose() {
    _sub?.cancel();
  }
}

/// Modello dati QR timbratura
class QRTimbratureData {
  final String cantiereId;
  final String cantiereName;
  final String serverHost;
  final int serverPort;
  final int timestamp;
  final String signature;

  QRTimbratureData({
    required this.cantiereId,
    required this.cantiereName,
    required this.serverHost,
    required this.serverPort,
    required this.timestamp,
    required this.signature,
  });

  factory QRTimbratureData.fromJson(Map<String, dynamic> json) {
    return QRTimbratureData(
      cantiereId: json['cantiere_id'] as String,
      cantiereName: json['cantiere_name'] as String,
      serverHost: json['server_host'] as String,
      serverPort: json['server_port'] as int,
      timestamp: json['timestamp'] as int,
      signature: json['signature'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cantiere_id': cantiereId,
      'cantiere_name': cantiereName,
      'server_host': serverHost,
      'server_port': serverPort,
      'timestamp': timestamp,
      'signature': signature,
    };
  }
}