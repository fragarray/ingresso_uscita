import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/personnel_tab.dart';
import '../widgets/reports_tab.dart';
import '../widgets/work_sites_tab.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
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
              onPressed: () => context.read<AppState>().logout(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
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
                        orElse: () => Employee(name: 'Sconosciuto', email: ''),
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
                          subtitle: Text(
                            '${DateFormat('HH:mm:ss').format(record.timestamp.toLocal())} - ${record.type == 'in' ? 'Ingresso' : 'Uscita'}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${record.latitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${record.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 11),
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Carica le impostazioni salvate
    final appState = context.read<AppState>();
    setState(() {
      _minGpsAccuracy = appState.minGpsAccuracyPercent;
      _isLoading = false;
    });
  }

  Future<void> _saveGpsAccuracy(double value) async {
    final appState = context.read<AppState>();
    await appState.setMinGpsAccuracyPercent(value);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accuratezza GPS minima impostata al ${value.toInt()}%'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
      ],
    );
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