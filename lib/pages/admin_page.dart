import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../widgets/personnel_tab.dart';
import '../widgets/reports_tab.dart';
import '../widgets/work_sites_tab.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Area Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async => await context.read<AppState>().logout(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Personale'),
              Tab(icon: Icon(Icons.person_pin), text: 'Chi è Timbrato'),
              Tab(icon: Icon(Icons.access_time), text: 'Presenze Oggi'),
              Tab(icon: Icon(Icons.location_city), text: 'Cantieri'),
              Tab(icon: Icon(Icons.assessment), text: 'Report'),
              Tab(icon: Icon(Icons.settings), text: 'Impostazioni'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PersonnelTab(),
            CurrentlyLoggedInTab(),
            TodayAttendanceTab(),
            WorkSitesTab(),
            ReportsTab(),
            SettingsTab(),
          ],
        ),
      ),
    );
  }
}

// Tab per le presenze di oggi
class TodayAttendanceTab extends StatefulWidget {
  const TodayAttendanceTab({Key? key}) : super(key: key);

  @override
  State<TodayAttendanceTab> createState() => _TodayAttendanceTabState();
}

class _TodayAttendanceTabState extends State<TodayAttendanceTab> 
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<Employee> _employees = [];
  List<WorkSite> _workSites = [];
  List<AttendanceRecord> _todayAttendance = [];
  AppState? _appState; // Riferimento salvato
  int _lastRefreshCounter = -1; // Traccia l'ultimo refresh processato

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Salva il riferimento e aggiungi listener solo la prima volta
    if (_appState == null) {
      _appState = context.read<AppState>();
      _appState!.addListener(_onAppStateChanged);
    }
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final currentCounter = _appState?.refreshCounter ?? -1;
    // Esegui refresh solo se il counter è cambiato
    if (currentCounter != _lastRefreshCounter && currentCounter >= 0) {
      debugPrint('=== TODAY ATTENDANCE TAB: Refresh triggered (counter: $currentCounter) ===');
      _lastRefreshCounter = currentCounter;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      final workSites = await ApiService.getWorkSites();
      final attendance = await ApiService.getAttendanceRecords();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Filtra solo le timbrature di oggi
      final todayRecords = attendance.where((record) {
        final recordDate = DateTime(
          record.timestamp.year,
          record.timestamp.month,
          record.timestamp.day,
        );
        return recordDate.isAtSameMomentAs(today);
      }).toList();
      
      debugPrint('=== DEBUG PRESENZE OGGI ===');
      debugPrint('Total employees: ${employees.length}');
      debugPrint('Total attendance records: ${attendance.length}');
      debugPrint('Today attendance records: ${todayRecords.length}');
      
      if (!mounted) return;
      
      setState(() {
        _employees = employees;
        _workSites = workSites;
        _todayAttendance = todayRecords;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento dei dati: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_todayAttendance.where((r) => r.type == 'in').length}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text('Ingressi'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_todayAttendance.where((r) => r.type == 'out').length}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text('Uscite'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Oggi'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _todayAttendance.isEmpty
                ? const Center(
                    child: Text('Nessuna timbratura oggi'),
                  )
                : ListView.builder(
                    itemCount: _todayAttendance.length,
                    itemBuilder: (context, index) {
                      final record = _todayAttendance[index];
                      final employee = _employees.firstWhere(
                        (e) => e.id == record.employeeId,
                        orElse: () => Employee(name: 'Sconosciuto', username: 'unknown'),
                      );
                      
                      // Trova il cantiere associato
                      final workSite = _workSites.firstWhere(
                        (ws) => ws.id == record.workSiteId,
                        orElse: () => WorkSite(
                          id: 0,
                          name: 'Cantiere sconosciuto',
                          address: '',
                          latitude: 0,
                          longitude: 0,
                        ),
                      );
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: record.type == 'in' 
                                ? Colors.green 
                                : Colors.red,
                            child: Icon(
                              record.type == 'in' ? Icons.login : Icons.logout,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            employee.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat('HH:mm:ss').format(record.timestamp.toLocal())} - ${record.type == 'in' ? 'Ingresso' : 'Uscita'}',
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      workSite.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Tab per le impostazioni
class SettingsTab extends StatefulWidget {
  const SettingsTab({Key? key}) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _minGpsAccuracy = 75.0; // Valore predefinito 75%
  bool _isLoading = true;
  bool _autoBackupEnabled = false;
  int _autoBackupDays = 7;
  String? _lastBackupDate;
  List<Map<String, dynamic>> _backups = [];
  bool _loadingBackup = false;
  
  // Server IP
  final TextEditingController _serverIpController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  String _currentServerIp = '192.168.1.2';
  int _currentServerPort = 3000;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackupSettings();
    _loadBackupList();
    _loadServerIp();
  }
  
  @override
  void dispose() {
    _serverIpController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }
  
  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('serverIp') ?? '192.168.1.2';
    final savedPort = prefs.getInt('serverPort') ?? 3000;
    setState(() {
      _currentServerIp = savedIp;
      _currentServerPort = savedPort;
      _serverIpController.text = savedIp;
      _serverPortController.text = savedPort.toString();
    });
  }

  Future<void> _testAndSaveServerIp() async {
    final newIp = _serverIpController.text.trim();
    final portText = _serverPortController.text.trim();
    
    if (newIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un indirizzo server valido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Valida porta
    final newPort = int.tryParse(portText);
    if (newPort == null || newPort < 1 || newPort > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Porta non valida (deve essere tra 1 e 65535)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _testingConnection = true;
    });
    
    // Test connessione con porta specificata
    final result = await ApiService.pingServer(newIp, newPort);
    
    setState(() {
      _testingConnection = false;
    });
    
    if (result['success'] == true) {
      // Server valido, salva IP e porta
      await ApiService.setServerIp(newIp);
      await ApiService.setServerPort(newPort);
      setState(() {
        _currentServerIp = newIp;
        _currentServerPort = newPort;
      });
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Connessione riuscita'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Server: ${result['message']}'),
              const SizedBox(height: 8),
              Text('Versione: ${result['version']}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text(
                'L\'indirizzo del server è stato aggiornato.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Errore di connessione
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Connessione fallita'),
            ],
          ),
          content: Text(result['error'] ?? 'Errore sconosciuto'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Ricarica SEMPRE dal server per avere il valore più aggiornato
      final serverValue = await ApiService.getSetting('minGpsAccuracyPercent');
      
      if (serverValue != null) {
        final accuracy = double.tryParse(serverValue) ?? 75.0;
        
        // Aggiorna anche l'AppState per sincronizzare
        final appState = context.read<AppState>();
        appState.setMinGpsAccuracyPercent(accuracy, adminId: null); // Null = non risalva
        
        if (!mounted) return;
        setState(() {
          _minGpsAccuracy = accuracy;
        });
        
        debugPrint('✓ GPS accuracy loaded from server: $accuracy%');
      } else {
        // Fallback: usa il valore corrente dell'AppState
        final appState = context.read<AppState>();
        setState(() {
          _minGpsAccuracy = appState.minGpsAccuracyPercent;
        });
        debugPrint('⚠️ Using AppState GPS accuracy: $_minGpsAccuracy%');
      }
    } catch (e) {
      debugPrint('❌ Error loading GPS accuracy from server: $e');
      // Fallback: usa il valore corrente dell'AppState
      final appState = context.read<AppState>();
      setState(() {
        _minGpsAccuracy = appState.minGpsAccuracyPercent;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveGpsAccuracy(double value) async {
    final appState = context.read<AppState>();
    final adminId = appState.currentEmployee?.id;
    
    if (adminId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore: admin non identificato'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Salva sul server con adminId
    await appState.setMinGpsAccuracyPercent(value, adminId: adminId);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accuratezza GPS minima impostata al ${value.toInt()}% per tutti i dispositivi'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadBackupSettings() async {
    final settings = await ApiService.getBackupSettings();
    if (settings != null && mounted) {
      setState(() {
        _autoBackupEnabled = settings['autoBackupEnabled'] ?? false;
        _autoBackupDays = settings['autoBackupDays'] ?? 7;
        _lastBackupDate = settings['lastBackupDate'];
      });
    }
  }

  Future<void> _loadBackupList() async {
    final backups = await ApiService.listBackups();
    if (mounted) {
      setState(() => _backups = backups);
    }
  }

  Future<void> _saveBackupSettings() async {
    final success = await ApiService.saveBackupSettings(
      autoBackupEnabled: _autoBackupEnabled,
      autoBackupDays: _autoBackupDays,
    );
    
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impostazioni backup salvate'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _createBackupNow() async {
    setState(() => _loadingBackup = true);
    
    final result = await ApiService.createBackup();
    
    if (!mounted) return;
    setState(() => _loadingBackup = false);
    
    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup creato con successo!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBackupSettings();
      _loadBackupList();
      
      // Chiedi se vuole scaricare
      _askDownloadBackup(result['backup']['fileName']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante la creazione del backup'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _askDownloadBackup(String fileName) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Backup creato'),
          ],
        ),
        content: Text(
          'Il backup è stato salvato sul server.\n\n'
          'Vuoi scaricare una copia locale per conservarla in un luogo sicuro?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÌ, SCARICA'),
          ),
        ],
      ),
    );

    if (download == true) {
      _downloadBackup(fileName);
    }
  }

  Future<void> _downloadBackup(String fileName) async {
    setState(() => _loadingBackup = true);
    
    final filePath = await ApiService.downloadBackup(fileName);
    
    if (!mounted) return;
    setState(() => _loadingBackup = false);
    
    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup scaricato in:\n$filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante il download del backup'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBackup(String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi eliminare il backup "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteBackup(fileName);
      if (success) {
        _loadBackupList();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup eliminato'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    try {
      // Usa file_picker per selezionare il file .db
      // withData: true per ottenere i bytes (necessario per Android)
      // FileType.any perché .db non è un'estensione riconosciuta su Android
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Seleziona file database (.db)',
        withData: true, // Importante per Android
      );

      if (result == null || result.files.isEmpty) {
        return; // Utente ha annullato
      }

      final pickedFile = result.files.first;
      final fileName = pickedFile.name;
      
      // Verifica che sia un file .db
      if (!fileName.toLowerCase().endsWith('.db')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: seleziona un file con estensione .db'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final fileBytes = pickedFile.bytes;
      
      // Su Android, bytes è disponibile, su desktop potrebbe servire il path
      if (fileBytes == null) {
        // Fallback per desktop: leggi dal path
        final filePath = pickedFile.path;
        if (filePath == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore: impossibile leggere il file'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        // Leggi i bytes dal file (desktop)
        final file = File(filePath);
        if (!await file.exists()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore: file non trovato'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final bytesFromFile = await file.readAsBytes();
        await _proceedWithRestore(bytesFromFile, fileName);
      } else {
        // Android o web: usa i bytes direttamente
        await _proceedWithRestore(fileBytes, fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la selezione del file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _proceedWithRestore(List<int> fileBytes, String fileName) async {
    try {

      // Conferma restore
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Attenzione'),
          content: const Text(
            'Il ripristino del database sostituirà TUTTI i dati correnti.\n\n'
            'Verrà creato un backup automatico del database corrente prima del ripristino.\n\n'
            'Il server si riavvierà automaticamente.\n\n'
            'Continuare?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ripristina'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mostra loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ripristino in corso...'),
              SizedBox(height: 8),
              Text(
                'Non chiudere l\'applicazione',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Esegui restore
      final response = await ApiService.restoreBackup(fileBytes, fileName);

      if (!mounted) return;
      Navigator.pop(context); // Chiudi loading dialog

      if (response != null && response['success'] == true) {
        // Successo - mostra messaggio e aspetta riavvio server
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Ripristino completato'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Database ripristinato con successo!'),
                const SizedBox(height: 12),
                Text(
                  'Backup creato: ${response['backupCreated'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Il server si riavvierà automaticamente.\n'
                  'L\'app tornerà alla schermata di login.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Logout e torna alla login
                  await context.read<AppState>().logout();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Attendi qualche secondo per il riavvio del server
        await Future.delayed(const Duration(seconds: 2));
        
        // Forza logout e refresh
        if (!mounted) return;
        await context.read<AppState>().logout();
        
      } else {
        // Errore
        final errorMsg = response?['error'] ?? 'Errore sconosciuto durante il ripristino';
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Errore'),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Chiudi loading dialog se aperto
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Errore'),
          content: Text('Errore durante il ripristino: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sezione Server IP
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dns, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Indirizzo Server',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Configura l\'indirizzo del server (IP locale, IP pubblico o nome dominio DynDNS) e la porta. Il test di connessione verificherà che sia raggiungibile.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _serverIpController,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo Server',
                          hintText: 'es: 192.168.1.2 o example.ddns.net',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                          helperText: 'IP o nome dominio',
                        ),
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _serverPortController,
                        decoration: const InputDecoration(
                          labelText: 'Porta',
                          hintText: '3000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.power),
                          helperText: ' ', // Spazio per allineamento
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testingConnection ? null : _testAndSaveServerIp,
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_testingConnection ? 'Test in corso...' : 'Testa e Salva Configurazione'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.purple[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Server corrente: $_currentServerIp:$_currentServerPort',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sezione GPS
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Accuratezza GPS',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Imposta l\'accuratezza minima richiesta per effettuare una timbratura',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Impostazione condivisa - Valida per tutti i dispositivi',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Minimo richiesto:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _minGpsAccuracy,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_minGpsAccuracy.toInt()}%',
                        onChanged: (value) {
                          setState(() {
                            _minGpsAccuracy = value;
                          });
                        },
                        onChangeEnd: _saveGpsAccuracy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _minGpsAccuracy >= 75 
                            ? Colors.green 
                            : _minGpsAccuracy >= 50 
                                ? Colors.orange 
                                : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_minGpsAccuracy.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _minGpsAccuracy == 0
                              ? 'Attenzione: timbratura permessa anche senza GPS accurato'
                              : _minGpsAccuracy < 50
                                  ? 'GPS poco accurato potrebbe causare errori di posizione'
                                  : _minGpsAccuracy < 75
                                      ? 'Accuratezza media - errori possibili'
                                      : 'Accuratezza alta - timbrature affidabili',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sezione Backup Database
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.backup, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Backup Database',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Proteggi i tuoi dati con backup automatici o manuali',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                // Backup automatico
                SwitchListTile(
                  title: const Text('Backup Automatico'),
                  subtitle: Text(_autoBackupEnabled 
                      ? 'Attivo - ogni $_autoBackupDays giorni'
                      : 'Disattivato'),
                  value: _autoBackupEnabled,
                  onChanged: (value) {
                    setState(() => _autoBackupEnabled = value);
                    _saveBackupSettings();
                  },
                ),
                if (_autoBackupEnabled) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Frequenza backup automatico:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1 giorno'),
                        selected: _autoBackupDays == 1,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _autoBackupDays = 1);
                            _saveBackupSettings();
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('3 giorni'),
                        selected: _autoBackupDays == 3,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _autoBackupDays = 3);
                            _saveBackupSettings();
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('7 giorni'),
                        selected: _autoBackupDays == 7,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _autoBackupDays = 7);
                            _saveBackupSettings();
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('15 giorni'),
                        selected: _autoBackupDays == 15,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _autoBackupDays = 15);
                            _saveBackupSettings();
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('30 giorni'),
                        selected: _autoBackupDays == 30,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _autoBackupDays = 30);
                            _saveBackupSettings();
                          }
                        },
                      ),
                    ],
                  ),
                  if (_lastBackupDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ultimo backup: ${_formatDate(_lastBackupDate!)}',
                              style: TextStyle(
                                color: Colors.green[900],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                // Backup manuale
                ElevatedButton.icon(
                  onPressed: _loadingBackup ? null : _createBackupNow,
                  icon: _loadingBackup 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_loadingBackup ? 'Creazione in corso...' : 'Crea Backup Ora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                // Restore da backup
                ElevatedButton.icon(
                  onPressed: _loadingBackup ? null : _restoreFromBackup,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ripristina da Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Lista backup esistenti
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Backup Esistenti',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadBackupList,
                      tooltip: 'Aggiorna lista',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_backups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Nessun backup disponibile',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._backups.take(5).map((backup) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.storage, color: Colors.purple),
                      title: Text(
                        backup['fileName'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '${_formatFileSize(backup['size'])} - ${_formatDate(backup['createdAt'])}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download, size: 20),
                            onPressed: () => _downloadBackup(backup['fileName']),
                            tooltip: 'Scarica',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteBackup(backup['fileName']),
                            tooltip: 'Elimina',
                          ),
                        ],
                      ),
                    ),
                  )),
                if (_backups.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        'E altri ${_backups.length - 5} backup...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Oggi alle ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Ieri alle ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} giorni fa';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Tab per visualizzare chi è attualmente timbrato
class CurrentlyLoggedInTab extends StatefulWidget {
  const CurrentlyLoggedInTab({Key? key}) : super(key: key);

  @override
  State<CurrentlyLoggedInTab> createState() => _CurrentlyLoggedInTabState();
}

class _CurrentlyLoggedInTabState extends State<CurrentlyLoggedInTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<Employee> _employees = [];
  List<WorkSite> _workSites = [];
  Map<int, AttendanceRecord> _lastRecords = {}; // employeeId -> last record
  List<Employee> _loggedInEmployees = [];
  AppState? _appState; // Riferimento salvato
  int _lastRefreshCounter = -1; // Traccia l'ultimo refresh processato

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Salva il riferimento e aggiungi listener solo la prima volta
    if (_appState == null) {
      _appState = context.read<AppState>();
      _appState!.addListener(_onAppStateChanged);
    }
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final currentCounter = _appState?.refreshCounter ?? -1;
    // Esegui refresh solo se il counter è cambiato
    if (currentCounter != _lastRefreshCounter && currentCounter >= 0) {
      debugPrint('=== CHI È TIMBRATO TAB: Refresh triggered (counter: $currentCounter) ===');
      _lastRefreshCounter = currentCounter;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final employees = await ApiService.getEmployees();
      final workSites = await ApiService.getWorkSites();
      final attendance = await ApiService.getAttendanceRecords();
      
      debugPrint('=== DEBUG CHI È TIMBRATO ===');
      debugPrint('Total employees: ${employees.length}');
      debugPrint('Total attendance records: ${attendance.length}');
      
      // Trova l'ultimo record per ogni dipendente
      final Map<int, AttendanceRecord> lastRecordsMap = {};
      
      for (var employee in employees) {
        final employeeRecords = attendance
            .where((r) => r.employeeId == employee.id)
            .toList();
        
        if (employeeRecords.isNotEmpty) {
          // I record arrivano già ordinati DESC (più recente prima)
          lastRecordsMap[employee.id!] = employeeRecords.first;
          debugPrint('Employee ${employee.name}: last record type = ${employeeRecords.first.type}, isForced = ${employeeRecords.first.isForced}');
        }
      }
      
      // Filtra i dipendenti che hanno l'ultimo record di tipo 'in'
      final loggedIn = employees.where((employee) {
        final lastRecord = lastRecordsMap[employee.id];
        return lastRecord != null && lastRecord.type == 'in';
      }).toList();
      
      debugPrint('Currently logged in employees: ${loggedIn.length}');
      
      if (!mounted) return;
      
      setState(() {
        _employees = employees;
        _workSites = workSites;
        _lastRecords = lastRecordsMap;
        _loggedInEmployees = loggedIn;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_loggedInEmployees.length}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Dipendenti Timbrati',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_employees.length - _loggedInEmployees.length}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Text('Non Timbrati'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loggedInEmployees.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nessun dipendente attualmente timbrato',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _loggedInEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = _loggedInEmployees[index];
                      final lastRecord = _lastRecords[employee.id]!;
                      final isForced = lastRecord.isForced;
                      
                      // Trova il cantiere associato
                      final workSite = _workSites.firstWhere(
                        (ws) => ws.id == lastRecord.workSiteId,
                        orElse: () => WorkSite(
                          id: 0,
                          name: 'Cantiere sconosciuto',
                          address: '',
                          latitude: 0,
                          longitude: 0,
                        ),
                      );
                      
                      // Calcola da quanto tempo è timbrato
                      final duration = DateTime.now().difference(lastRecord.timestamp);
                      String durationText;
                      if (duration.inDays > 0) {
                        durationText = '${duration.inDays}g ${duration.inHours % 24}h fa';
                      } else if (duration.inHours > 0) {
                        durationText = '${duration.inHours}h ${duration.inMinutes % 60}m fa';
                      } else {
                        durationText = '${duration.inMinutes}m fa';
                      }
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: isForced ? Colors.orange[50] : null,
                        child: ListTile(
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: isForced ? Colors.orange : Colors.green,
                                child: Text(
                                  employee.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isForced)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.warning,
                                      color: Colors.orange,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  employee.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isForced)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'FORZATA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      workSite.name,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Timbrato ${DateFormat('HH:mm:ss').format(lastRecord.timestamp.toLocal())}',
                              ),
                              Text(
                                durationText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isForced && lastRecord.deviceInfo.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    lastRecord.deviceInfo,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isForced ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isForced ? 'FORZATA' : 'TIMBRATO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}