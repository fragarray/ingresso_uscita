import 'package:location/location.dart';

class GPSService {
  static final GPSService _instance = GPSService._internal();
  factory GPSService() => _instance;
  GPSService._internal();

  LocationData? _cachedPosition;
  bool _isLoading = false;
  DateTime? _lastUpdate;
  final Location _location = Location();

  /// Avvia preloading GPS QUANDO deep link viene ricevuto
  /// ⚠️ NON chiamare in main() - troppo presto
  /// ✅ Chiamare SOLO quando utente scansiona QR
  Future<void> preloadGPS() async {
    if (_isLoading) return;
    
    print('[GPS] 🛰️ Avvio preloading GPS (trigger: deep link ricevuto)...');
    _isLoading = true;

    try {
      // 1. Verifica/Richiedi permessi
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        print('[GPS] ❌ Permessi GPS negati');
        _isLoading = false;
        return;
      }

      // 2. Verifica che GPS sia abilitato
      final isEnabled = await _location.serviceEnabled();
      if (!isEnabled) {
        print('[GPS] ⚠️ GPS disabilitato sul dispositivo');
        final enabled = await _location.requestService();
        if (!enabled) {
          print('[GPS] ❌ Utente ha rifiutato di abilitare GPS');
          _isLoading = false;
          return;
        }
      }

      // 3. Ottieni posizione attuale
      final position = await _location.getLocation().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('GPS timeout dopo 10 secondi');
        },
      );

      _cachedPosition = position;
      _lastUpdate = DateTime.now();
      _isLoading = false;

      print('[GPS] ✅ GPS precaricato: ${position.latitude}, ${position.longitude} (±${position.accuracy}m)');
      
    } catch (e) {
      print('[GPS] ❌ Errore preloading: $e');
      _isLoading = false;
    }
  }

  /// Ottieni posizione (usa cache se recente)
  Future<LocationData?> getCurrentPosition() async {
    // Se cache è recente (< 30 secondi), usala
    if (_cachedPosition != null && _lastUpdate != null) {
      final age = DateTime.now().difference(_lastUpdate!);
      if (age.inSeconds < 30) {
        print('[GPS] ⚡ Uso posizione cached (age: ${age.inSeconds}s)');
        return _cachedPosition;
      }
    }

    // Altrimenti ottieni nuova posizione
    print('[GPS] 🔄 Aggiornamento posizione...');
    try {
      final position = await _location.getLocation().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('GPS timeout dopo 10 secondi');
        },
      );
      
      _cachedPosition = position;
      _lastUpdate = DateTime.now();
      
      return position;
    } catch (e) {
      print('[GPS] ❌ Errore getting position: $e');
      return null;
    }
  }

  /// Verifica e richiedi permessi GPS
  Future<bool> _checkAndRequestPermission() async {
    var permissionStatus = await _location.hasPermission();
    
    if (permissionStatus == PermissionStatus.granted || 
        permissionStatus == PermissionStatus.grantedLimited) {
      return true;
    }

    // Richiedi permessi
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
    }

    return permissionStatus == PermissionStatus.granted || 
           permissionStatus == PermissionStatus.grantedLimited;
  }

  /// Verifica se GPS è pronto
  bool isGPSReady() {
    return _cachedPosition != null && _lastUpdate != null;
  }

  /// Ottieni accuratezza GPS (in metri)
  double? getAccuracy() {
    return _cachedPosition?.accuracy;
  }

  /// Pulisci cache
  void clearCache() {
    _cachedPosition = null;
    _lastUpdate = null;
  }
}