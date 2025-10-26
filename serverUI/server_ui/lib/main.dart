import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/server_provider.dart';
import 'services/tray_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inizializza il system tray (se supportato)
  // La configurazione della finestra su Windows è gestita nativamente
  
  runApp(const ServerManagerApp());
}

class ServerManagerApp extends StatelessWidget {
  const ServerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ServerProvider(),
      child: MaterialApp(
        title: 'Sinergy Work - Server Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF1976D2),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: const ServerManagerHome(),
      ),
    );
  }
}

class ServerManagerHome extends StatefulWidget {
  const ServerManagerHome({super.key});

  @override
  State<ServerManagerHome> createState() => _ServerManagerHomeState();
}

class _ServerManagerHomeState extends State<ServerManagerHome> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Inizializza il system tray
    final serverProvider = context.read<ServerProvider>();
    await TrayService.initialize(serverProvider);
    
    // Ascolta i cambiamenti del provider per aggiornare il tray
    serverProvider.addListener(_updateTray);
  }

  void _updateTray() {
    TrayService.updateTrayMenu();
  }

  @override
  void dispose() {
    final serverProvider = context.read<ServerProvider>();
    serverProvider.removeListener(_updateTray);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}