import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/employee.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart';
import 'pages/employee_page.dart';

void main() {
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
    final prefs = await SharedPreferences.getInstance();
    _minGpsAccuracyPercent = prefs.getDouble('minGpsAccuracyPercent') ?? 75.0;
    notifyListeners();
  }
  
  Future<void> setMinGpsAccuracyPercent(double value) async {
    _minGpsAccuracyPercent = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minGpsAccuracyPercent', value);
    notifyListeners();
  }
  
  void setEmployee(Employee employee) {
    _currentEmployee = employee;
    notifyListeners();
  }
  
  void logout() {
    _currentEmployee = null;
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
      title: 'Sistema Timbratura',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.currentEmployee == null) {
            return LoginPage();
          }
          return appState.currentEmployee!.isAdmin
              ? AdminPage()
              : EmployeePage();
        },
      ),
    );
  }
}