import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/employee.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart';
import 'pages/employee_page.dart';
import 'pages/foreman_page_new.dart';
import 'services/api_service.dart';
import 'services/deep_link_service.dart';
import 'services/gps_service.dart';
import 'services/timbratura_qr_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Consenti tutti gli orientamenti (portrait + landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft, // Commentare 
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  Employee? _currentEmployee;
  int _refreshCounter = 0; // Invece di bool, usa counter
  double _personnelTabDividerWidth = 350.0; // Larghezza divisore tab personale
  double _minGpsAccuracyPercent = 75.0; // Accuratezza GPS minima richiesta (default 75%)
  QRTimbratureData? _pendingQRData; // QR code in attesa di login
  bool _isGPSReady = false; // Stato GPS per login
  bool _isWaitingForGPS = false; // Indica se stiamo aspettando il GPS
  Timer? _gpsTimeoutTimer; // Timer per timeout GPS
  
  Employee? get currentEmployee => _currentEmployee;
  int get refreshCounter => _refreshCounter;
  double get personnelTabDividerWidth => _personnelTabDividerWidth;
  double get minGpsAccuracyPercent => _minGpsAccuracyPercent;
  QRTimbratureData? get pendingQRData => _pendingQRData;
  bool get isGPSReady => _isGPSReady;
  bool get isWaitingForGPS => _isWaitingForGPS;
  
  AppState() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    // PRIMA prova a caricare dal SERVER (fonte di verità)
    try {
      final serverValue = await ApiService.getSetting('minGpsAccuracyPercent');
      if (serverValue != null) {
        _minGpsAccuracyPercent = double.tryParse(serverValue) ?? 75.0;
        debugPrint('✓ GPS accuracy loaded from SERVER: $_minGpsAccuracyPercent%');
        
        // Salva in cache locale per offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('minGpsAccuracyPercent', _minGpsAccuracyPercent);
      } else {
        // Fallback: carica da SharedPreferences (cache locale)
        final prefs = await SharedPreferences.getInstance();
        _minGpsAccuracyPercent = prefs.getDouble('minGpsAccuracyPercent') ?? 75.0;
        debugPrint('⚠️ GPS accuracy loaded from LOCAL CACHE: $_minGpsAccuracyPercent%');
      }
    } catch (e) {
      // Errore rete: fallback a cache locale
      debugPrint('❌ Error loading from server, using local cache: $e');
      final prefs = await SharedPreferences.getInstance();
      _minGpsAccuracyPercent = prefs.getDouble('minGpsAccuracyPercent') ?? 75.0;
    }
    
    notifyListeners();
  }
  
  Future<void> setMinGpsAccuracyPercent(double value, {int? adminId}) async {
    _minGpsAccuracyPercent = value;
    
    // Salva PRIMA sul SERVER (fonte di verità)
    if (adminId != null) {
      try {
        final success = await ApiService.updateSetting(
          key: 'minGpsAccuracyPercent',
          value: value.toString(),
          adminId: adminId,
        );
        
        if (success) {
          debugPrint('✓ GPS accuracy saved to SERVER: $value%');
        } else {
          debugPrint('⚠️ Failed to save GPS accuracy to server');
        }
      } catch (e) {
        debugPrint('❌ Error saving to server: $e');
      }
    }
    
    // Salva ANCHE in cache locale per offline
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minGpsAccuracyPercent', value);
    
    notifyListeners();
  }
  
  void setEmployee(Employee employee) {
    _currentEmployee = employee;
    notifyListeners();
  }
  
  Future<void> logout() async {
    _currentEmployee = null;
    
    // Disabilita l'auto-login quando si fa logout manualmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);
    
    notifyListeners();
  }
  
  void triggerRefresh() {
    debugPrint('=== TRIGGER REFRESH CALLED ===');
    _refreshCounter++; // Incrementa invece di toggle
    notifyListeners();
  }
  
  void setPersonnelTabDividerWidth(double width) {
    _personnelTabDividerWidth = width;
    notifyListeners();
  }
  
  void setPendingQRData(QRTimbratureData? qrData) {
    _pendingQRData = qrData;
    notifyListeners();
  }
  
  void clearPendingQRData() {
    _pendingQRData = null;
    _stopGPSWaitingMode();
    notifyListeners();
  }
  
  void startGPSWaitingMode() {
    _isWaitingForGPS = true;
    _isGPSReady = false;
    
    // Start 7-second timeout
    _gpsTimeoutTimer?.cancel();
    _gpsTimeoutTimer = Timer(const Duration(seconds: 7), () {
      if (_isWaitingForGPS && !_isGPSReady) {
        print('[App] ⏰ GPS timeout (7s) - proceeding to normal site selection');
        _stopGPSWaitingMode();
        clearPendingQRData(); // This will trigger normal site selection
      }
    });
    
    notifyListeners();
  }
  
  void setGPSReady(bool ready) {
    _isGPSReady = ready;
    if (ready) {
      print('[App] ✅ GPS ready - login can proceed');
    }
    notifyListeners();
  }
  
  void _stopGPSWaitingMode() {
    _isWaitingForGPS = false;
    _isGPSReady = false;
    _gpsTimeoutTimer?.cancel();
    _gpsTimeoutTimer = null;
  }
  
  @override
  void dispose() {
    _gpsTimeoutTimer?.cancel();
    super.dispose();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    
    // Inizializza deep link listener
    _deepLinkService.initialize();
    
    // Gestisci QR scan (ricevuto da fotocamera nativa)
    _deepLinkService.onQRScanned = (qrData) {
      print('[App] 📱 QR ricevuto da FOTOCAMERA NATIVA: ${qrData.cantiereName}');
      
      final appState = context.read<AppState>();
      appState.setPendingQRData(qrData);
      
      if (appState.currentEmployee == null) {
        // Utente non loggato → Start GPS waiting mode
        print('[App] ⏳ Utente non loggato, avvio modalità attesa GPS...');
        appState.startGPSWaitingMode();
        
        // ⚡ AVVIA GPS ORA
        final gpsService = GPSService();
        gpsService.preloadGPS().then((_) {
          // Check if GPS meets accuracy requirements
          _checkGPSAccuracy(appState, gpsService);
        }).catchError((error) {
          print('[App] ❌ GPS preload error: $error');
          appState.setGPSReady(false);
        });
        print('[App] 🛰️ GPS preloading avviato...');
      } else {
        // Utente già loggato → Timbra direttamente
        print('[App] ✅ Utente già loggato, timbro direttamente...');
        
        // Start GPS for accuracy
        final gpsService = GPSService();
        gpsService.preloadGPS();
        print('[App] 🛰️ GPS preloading avviato...');
        
        _handleQRTimbratura(qrData);
      }
    };
  }

  void _handleQRTimbratura(QRTimbratureData qrData) async {
    final appState = context.read<AppState>();
    // At this point user is already logged in, execute timbratura
    await _executeTimbratura(qrData, appState);
  }

  void _checkGPSAccuracy(AppState appState, GPSService gpsService) {
    if (!gpsService.isGPSReady()) {
      print('[App] ⏳ GPS not ready yet, continuing to wait...');
      appState.setGPSReady(false);
      return;
    }

    final accuracy = gpsService.getAccuracy();
    if (accuracy == null) {
      print('[App] ❌ No GPS accuracy data available');
      appState.setGPSReady(false);
      return;
    }

    // Calculate accuracy percentage (smaller accuracy in meters = better)
    // Assume max acceptable accuracy is 50m = 0%, perfect accuracy is 0m = 100%
    final maxAccuracyMeters = 50.0;
    final accuracyPercent = ((maxAccuracyMeters - accuracy) / maxAccuracyMeters * 100).clamp(0.0, 100.0);
    
    print('[App] 🛰️ GPS accuracy: ${accuracy.toStringAsFixed(1)}m (${accuracyPercent.toStringAsFixed(1)}%)');
    print('[App] 📊 Required accuracy: ${appState.minGpsAccuracyPercent}%');

    if (accuracyPercent >= appState.minGpsAccuracyPercent) {
      print('[App] ✅ GPS accuracy sufficient - login allowed');
      appState.setGPSReady(true);
    } else {
      print('[App] ⚠️ GPS accuracy insufficient - waiting for better signal...');
      appState.setGPSReady(false);
      
      // Keep checking every 2 seconds
      Timer(const Duration(seconds: 2), () {
        if (appState.isWaitingForGPS && !appState.isGPSReady) {
          _checkGPSAccuracy(appState, gpsService);
        }
      });
    }
  }

  Future<void> _executeTimbratura(QRTimbratureData qrData, AppState appState) async {
    // Defer execution to next frame to ensure MaterialApp is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      print('[MAIN] 🚀 Inizio chiamata al servizio timbratura QR - NESSUN ALERT!');
      final timbratureService = TimbratureQRService();
      
      try {
        // Aggiungiamo timeout di 30 secondi per evitare blocchi infiniti
        final result = await timbratureService.timbraFromQR(
          qrData: qrData,
          userId: appState.currentEmployee!.id.toString(),
          authToken: 'dummy_token', // TODO: Implementare sistema auth token
        ).timeout(Duration(seconds: 30));

        print('[MAIN] 🏁 Fine chiamata servizio, risultato: ${result.success} - NESSUN ALERT MOSTRATO');
      } catch (e) {
        print('[MAIN] ❌ Timeout o errore servizio timbratura: $e - NESSUN ALERT MOSTRATO');
      }
      
      // Pulisci QR pending
      appState.clearPendingQRData();
    });
  }



  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinergy Work',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Stack(
        children: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (appState.currentEmployee == null) {
                return LoginPage();
              }
              
              // Routing basato su ruolo
              final employee = appState.currentEmployee!;
              
              switch (employee.role) {
                case EmployeeRole.admin:
                  return AdminPage();
                case EmployeeRole.foreman:
                  return ForemanPage();
                case EmployeeRole.employee:
                  return EmployeePage();
              }
            },
          ),
          // Overlay per loading timbratura: ELIMINATO COMPLETAMENTE
        ],
      ),
    );
  }
}