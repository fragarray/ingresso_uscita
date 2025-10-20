import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'package:open_file/open_file.dart';

class ForemanPage extends StatefulWidget {
  @override
  _ForemanPageState createState() => _ForemanPageState();
}

class _ForemanPageState extends State<ForemanPage> {
  List<WorkSite> _workSites = [];
  bool _isLoading = true;
  WorkSite? _selectedWorkSite;
  List<Map<String, dynamic>> _activeEmployees = [];
  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  List<Map<String, dynamic>>? _historyData;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadWorkSites();
  }

  Future<void> _loadWorkSites() async {
    setState(() => _isLoading = true);
    
    try {
      final workSites = await ApiService.getWorkSites();
      setState(() {
        _workSites = workSites.where((ws) => ws.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading work sites: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveEmployees(int workSiteId) async {
    setState(() => _isLoading = true);
    
    try {
      final employees = await ApiService.getActiveEmployeesForWorkSite(workSiteId);
      setState(() {
        _activeEmployees = employees;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading active employees: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dipendenti attivi: $e')),
        );
      }
    }
  }

  Future<void> _showWorkSiteDetails(WorkSite workSite) async {
    setState(() {
      _selectedWorkSite = workSite;
      _historyData = null;
      _historyStartDate = null;
      _historyEndDate = null;
    });
    await _loadActiveEmployees(workSite.id!);
  }

  Future<void> _loadWorkSiteHistory() async {
    if (_selectedWorkSite == null || _historyStartDate == null || _historyEndDate == null) {
      return;
    }

    setState(() => _isLoadingHistory = true);

    try {
      final data = await ApiService.getWorkSiteHistory(
        workSiteId: _selectedWorkSite!.id!,
        startDate: _historyStartDate,
        endDate: _historyEndDate,
      );

      setState(() {
        _historyData = data;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() => _isLoadingHistory = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento storico: $e')),
        );
      }
    }
  }

  Future<void> _downloadWorkSiteHistory() async {
    if (_selectedWorkSite == null) return;

    setState(() => _isLoading = true);

    try {
      final filePath = await ApiService.downloadForemanWorkSiteReport(
        workSiteId: _selectedWorkSite!.id!,
        startDate: _historyStartDate,
        endDate: _historyEndDate,
      );

      setState(() => _isLoading = false);

      if (filePath != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report scaricato: ${filePath.split('/').last}'),
            action: SnackBarAction(
              label: 'Apri',
              onPressed: () async {
                await OpenFile.open(filePath);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante il download del report')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _historyStartDate != null && _historyEndDate != null
          ? DateTimeRange(start: _historyStartDate!, end: _historyEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _historyStartDate = picked.start;
        _historyEndDate = picked.end;
      });
      // Carica automaticamente lo storico dopo aver selezionato le date
      await _loadWorkSiteHistory();
    }
  }

  void _clearDateRange() {
    setState(() {
      _historyStartDate = null;
      _historyEndDate = null;
      _historyData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final employee = appState.currentEmployee;

    return Scaffold(
      appBar: AppBar(
        title: Text('Capocantiere - ${employee?.name ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedWorkSite != null) {
                _loadActiveEmployees(_selectedWorkSite!.id!);
              } else {
                _loadWorkSites();
              }
            },
            tooltip: 'Aggiorna',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              appState.logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedWorkSite == null
              ? _buildWorkSitesList()
              : _buildWorkSiteDetails(),
    );
  }

  Widget _buildWorkSitesList() {
    if (_workSites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nessun cantiere disponibile',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workSites.length,
      itemBuilder: (context, index) {
        final workSite = _workSites[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.construction, color: Colors.white),
            ),
            title: Text(
              workSite.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        workSite.address,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showWorkSiteDetails(workSite),
          ),
        );
      },
    );
  }

  Widget _buildWorkSiteDetails() {
    return Column(
      children: [
        // Header cantiere
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedWorkSite = null;
                        _activeEmployees = [];
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedWorkSite!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedWorkSite!.address,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filtri data per storico
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Storico Cantiere',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _historyStartDate != null && _historyEndDate != null
                            ? '${DateFormat('dd/MM/yy').format(_historyStartDate!)} - ${DateFormat('dd/MM/yy').format(_historyEndDate!)}'
                            : 'Seleziona periodo',
                      ),
                      onPressed: _selectDateRange,
                    ),
                  ),
                  if (_historyStartDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearDateRange,
                      tooltip: 'Rimuovi filtro',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Scarica Report Excel'),
                  onPressed: _downloadWorkSiteHistory,
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // Lista dipendenti attivi o storico timbrature
        if (_historyData != null)
          // Se c'è un periodo selezionato, mostra lo storico (anche se vuoto)
          _buildHistoryView()
        else
          // Nessun periodo selezionato: mostra dipendenti attualmente presenti
          _buildActiveEmployeesView(),
      ],
    );
  }

  Widget _buildActiveEmployeesView() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Dipendenti Presenti (${_activeEmployees.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _activeEmployees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nessun dipendente attualmente presente',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _activeEmployees.length,
                    itemBuilder: (context, index) {
                      final empData = _activeEmployees[index];
                      final timestamp = empData['timestamp'] != null
                          ? DateTime.parse(empData['timestamp'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(
                              empData['employeeName']?.substring(0, 1) ?? '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            empData['employeeName'] ?? 'Sconosciuto',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: timestamp != null
                              ? Text(
                                  'Ingresso: ${DateFormat('dd/MM/yyyy HH:mm').format(timestamp)}',
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
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

  Widget _buildHistoryView() {
    if (_isLoadingHistory) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final records = _historyData!;

    if (records.isEmpty) {
      // Formatta il periodo selezionato
      String periodText = '';
      if (_historyStartDate != null && _historyEndDate != null) {
        final startStr = DateFormat('dd/MM/yyyy').format(_historyStartDate!);
        final endStr = DateFormat('dd/MM/yyyy').format(_historyEndDate!);
        if (startStr == endStr) {
          periodText = 'del $startStr';
        } else {
          periodText = 'dal $startStr al $endStr';
        }
      }

      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Nessun dipendente in servizio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (periodText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  periodText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Crea coppie IN/OUT dai record grezzi
    final pairs = _createAttendancePairsFromRecords(records);

    if (pairs.isEmpty) {
      // Caso raro: ci sono record ma nessun turno completo
      String periodText = '';
      if (_historyStartDate != null && _historyEndDate != null) {
        final startStr = DateFormat('dd/MM/yyyy').format(_historyStartDate!);
        final endStr = DateFormat('dd/MM/yyyy').format(_historyEndDate!);
        if (startStr == endStr) {
          periodText = 'del $startStr';
        } else {
          periodText = 'dal $startStr al $endStr';
        }
      }

      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Nessun turno completo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (periodText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  periodText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Ci sono solo ingressi senza uscite',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Storico Timbrature (${pairs.length} ${pairs.length == 1 ? 'turno' : 'turni'})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: pairs.length,
              itemBuilder: (context, index) {
                final pair = pairs[index];
                return _buildAttendancePairCard(pair);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _createAttendancePairsFromRecords(List<Map<String, dynamic>> records) {
    final pairs = <Map<String, dynamic>>[];
    
    // Raggruppa per dipendente
    final Map<int, List<Map<String, dynamic>>> recordsByEmployee = {};
    for (var record in records) {
      final empId = record['employeeId'] as int;
      if (!recordsByEmployee.containsKey(empId)) {
        recordsByEmployee[empId] = [];
      }
      recordsByEmployee[empId]!.add(record);
    }

    // Per ogni dipendente, crea coppie IN/OUT
    recordsByEmployee.forEach((empId, empRecords) {
      // Ordina per timestamp
      empRecords.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return aTime.compareTo(bTime);
      });

      // Crea coppie
      for (int i = 0; i < empRecords.length; i++) {
        final record = empRecords[i];
        
        if (record['type'] == 'in') {
          // Cerca il corrispondente OUT
          Map<String, dynamic>? outRecord;
          for (int j = i + 1; j < empRecords.length; j++) {
            if (empRecords[j]['type'] == 'out') {
              outRecord = empRecords[j];
              break;
            }
          }

          final inTimestamp = DateTime.parse(record['timestamp']);
          final outTimestamp = outRecord != null ? DateTime.parse(outRecord['timestamp']) : null;

          // Calcola durata se c'è OUT
          String? duration;
          bool isNightShift = false;
          
          if (outTimestamp != null) {
            final diff = outTimestamp.difference(inTimestamp);
            final hours = diff.inHours;
            final minutes = diff.inMinutes % 60;
            duration = '$hours:${minutes.toString().padLeft(2, '0')}';
            
            // Verifica se è turno notturno (finisce in un giorno diverso)
            isNightShift = inTimestamp.day != outTimestamp.day ||
                           inTimestamp.month != outTimestamp.month ||
                           inTimestamp.year != outTimestamp.year;
          }

          pairs.add({
            'employeeName': record['employeeName'],
            'employeeId': record['employeeId'],
            'inTimestamp': inTimestamp,
            'outTimestamp': outTimestamp,
            'duration': duration,
            'isNightShift': isNightShift,
            'inForced': record['isForced'] == 1,
            'outForced': outRecord?['isForced'] == 1,
            'inNotes': record['notes'],
            'outNotes': outRecord?['notes'],
          });
        }
      }
    });

    // Ordina tutti i turni cronologicamente (più recente prima)
    pairs.sort((a, b) {
      final aTime = a['inTimestamp'] as DateTime;
      final bTime = b['inTimestamp'] as DateTime;
      return bTime.compareTo(aTime); // Inverso per avere i più recenti prima
    });

    return pairs;
  }

  Widget _buildAttendancePairCard(Map<String, dynamic> pair) {
    final employeeName = pair['employeeName'] as String;
    final inTimestamp = pair['inTimestamp'] as DateTime;
    final outTimestamp = pair['outTimestamp'] as DateTime?;
    final duration = pair['duration'] as String?;
    final isNightShift = pair['isNightShift'] as bool;
    final inForced = pair['inForced'] as bool;
    final outForced = pair['outForced'] as bool;
    
    final isComplete = outTimestamp != null;
    
    // Formatta date
    final inDate = DateFormat('dd/MM/yyyy').format(inTimestamp);
    final inTime = DateFormat('HH:mm').format(inTimestamp);
    final outTime = outTimestamp != null ? DateFormat('HH:mm').format(outTimestamp) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isComplete
              ? [Colors.blue[50]!, Colors.blue[100]!]
              : [Colors.orange[50]!, Colors.orange[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? Colors.blue : Colors.orange,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? Colors.blue : Colors.orange).withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con data, dipendente e durata
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [Colors.blue[600]!, Colors.blue[700]!]
                    : [Colors.orange[600]!, Colors.orange[700]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                // Avatar dipendente
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Text(
                    employeeName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nome dipendente
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge durata o stato
                if (duration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${duration}h',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'IN CORSO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Badge turno notturno o forzato
          if (isNightShift || inForced || outForced)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  if (isNightShift)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.nightlight, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'TURNO NOTTURNO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (inForced)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.admin_panel_settings, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'IN FORZATO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (outForced)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.admin_panel_settings, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'OUT FORZATO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          
          // Contenuto IN/OUT
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // IN
                Expanded(
                  child: _buildMiniTimeRecord(inTime, isIn: true),
                ),
                
                // Connettore
                if (isComplete)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 2,
                          height: 15,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.green.withOpacity(0.5),
                                Colors.grey[300]!,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 10,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 15,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.grey[300]!,
                                Colors.red.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // OUT
                Expanded(
                  child: _buildMiniTimeRecord(outTime, isIn: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTimeRecord(String? time, {required bool isIn}) {
    if (time == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Column(
          children: [
            Icon(
              isIn ? Icons.login : Icons.logout,
              size: 20,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 4),
            Text(
              isIn ? 'IN' : 'OUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '---',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIn ? Colors.green[300]! : Colors.red[300]!,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isIn ? Icons.login : Icons.logout,
            size: 20,
            color: isIn ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 4),
          Text(
            isIn ? 'ENTRATA' : 'USCITA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isIn ? Colors.green[700] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
