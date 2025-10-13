import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  Employee? get currentEmployee => _currentEmployee;
  
  void setEmployee(Employee employee) {
    _currentEmployee = employee;
    notifyListeners();
  }
  
  void logout() {
    _currentEmployee = null;
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