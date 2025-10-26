import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'providers/server_provider.dart';
import 'services/tray_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza il window manager per le piattaforme desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });
  }
  
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

class _ServerManagerHomeState extends State<ServerManagerHome> with WindowListener {
  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Registra il listener per gli eventi della finestra
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
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
    // Rimuovi il listener per gli eventi della finestra
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // WindowListener methods
  @override
  void onWindowClose() async {
    // Invece di chiudere, minimizza nella tray
    await TrayService.hideToTray();
  }

  @override
  void onWindowMinimize() {
    // Gestisce la minimizzazione (può essere usato per eventi aggiuntivi)
  }

  @override
  void onWindowRestore() {
    // Gestisce il ripristino della finestra
    final serverProvider = context.read<ServerProvider>();
    serverProvider.setMinimized(false);
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}