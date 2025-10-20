import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/employee.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart';
import 'pages/employee_page.dart';
import 'pages/foreman_page.dart';
import 'services/api_service.dart';

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
  
  Employee? get currentEmployee => _currentEmployee;
  int get refreshCounter => _refreshCounter;
  double get personnelTabDividerWidth => _personnelTabDividerWidth;
  double get minGpsAccuracyPercent => _minGpsAccuracyPercent;
  
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinergy Work',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
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
    );
  }
}