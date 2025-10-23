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
  List<WorkSite> _sortedWorkSites = []; // Lista ordinata una sola volta
  bool _isLoading = true;
  Map<int, List<Map<String, dynamic>>> _activeEmployeesByWorkSite = {};
  Map<int, List<Map<String, dynamic>>> _completedShiftsByWorkSite = {};
  Map<int, bool> _expandedWorkSites = {};
  DateTime _selectedDate = DateTime.now(); // Data selezionata per la visualizzazione
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  List<WorkSite> _sortWorkSites(List<WorkSite> workSites, Map<int, List<Map<String, dynamic>>> employeesByWorkSite) {
    final sortedList = List<WorkSite>.from(workSites);
    
    sortedList.sort((a, b) {
      final aActiveEmployees = employeesByWorkSite[a.id!]?.length ?? 0;
      final bActiveEmployees = employeesByWorkSite[b.id!]?.length ?? 0;
      final aCompleted = _completedShiftsByWorkSite[a.id!]?.length ?? 0;
      final bCompleted = _completedShiftsByWorkSite[b.id!]?.length ?? 0;
      
      // Priorità 1: Cantieri con dipendenti IN (attivi)
      if (aActiveEmployees > 0 && bActiveEmployees == 0) return -1;
      if (aActiveEmployees == 0 && bActiveEmployees > 0) return 1;
      
      // Priorità 2: Se entrambi hanno dipendenti IN, ordina per numero (più IN prima)
      if (aActiveEmployees > 0 && bActiveEmployees > 0) {
        return bActiveEmployees.compareTo(aActiveEmployees);
      }
      
      // Priorità 3: Cantieri con solo turni completati
      if (aCompleted > 0 && bCompleted == 0) return -1;
      if (aCompleted == 0 && bCompleted > 0) return 1;
      
      // Priorità 4: Se entrambi hanno turni completati, ordina per numero
      if (aCompleted > 0 && bCompleted > 0) {
        return bCompleted.compareTo(aCompleted);
      }
      
      // Priorità 5: Cantieri senza attività - ordine alfabetico
      return a.name.compareTo(b.name);
    });
    
    return sortedList;
  }

  Future<void> _loadCompletedShifts(int workSiteId) async {
    try {
      // Carica i turni completati per la data selezionata per questo cantiere
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      
      final data = await ApiService.getWorkSiteHistory(
        workSiteId: workSiteId,
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      // Raggruppa per dipendente
      final Map<int, List<Map<String, dynamic>>> recordsByEmployee = {};
      for (var record in data) {
        final empId = record['employeeId'] as int;
        if (!recordsByEmployee.containsKey(empId)) {
          recordsByEmployee[empId] = [];
        }
        recordsByEmployee[empId]!.add(record);
      }
      
      // Crea coppie entrata/uscita per ogni dipendente
      final completedShifts = <Map<String, dynamic>>[];
      
      recordsByEmployee.forEach((empId, records) {
        // Ordina per timestamp
        records.sort((a, b) {
          final aTime = DateTime.parse(a['timestamp']);
          final bTime = DateTime.parse(b['timestamp']);
          return aTime.compareTo(bTime);
        });
        
        // Cerca coppie IN/OUT
        for (int i = 0; i < records.length; i++) {
          final record = records[i];
          
          if (record['type'] == 'in') {
            // Cerca il prossimo OUT per questo dipendente
            for (int j = i + 1; j < records.length; j++) {
              if (records[j]['type'] == 'out') {
                // Trovata coppia completa!
                completedShifts.add({
                  'employeeId': empId,
                  'employeeName': record['employeeName'],
                  'inTimestamp': record['timestamp'],
                  'outTimestamp': records[j]['timestamp'],
                });
                break;
              }
            }
          }
        }
      });
      
      // NON chiamare setState qui - aggiorna solo i dati
      _completedShiftsByWorkSite[workSiteId] = completedShifts;
    } catch (e) {
      print('Error loading completed shifts: $e');
      _completedShiftsByWorkSite[workSiteId] = [];
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      // Carica tutti i cantieri attivi
      final workSites = await ApiService.getWorkSites();
      final activeWorkSites = workSites.where((ws) => ws.isActive).toList();
      
      // Verifica se la data selezionata è oggi
      final today = DateTime.now();
      final isToday = _selectedDate.year == today.year && 
                      _selectedDate.month == today.month && 
                      _selectedDate.day == today.day;
      
      // Carica dipendenti attivi per ogni cantiere (solo se data = oggi)
      final Map<int, List<Map<String, dynamic>>> employeesByWorkSite = {};
      final Map<int, bool> expandedStates = {};
      
      for (var workSite in activeWorkSites) {
        try {
          // Carica dipendenti attivi solo se visualizziamo oggi
          final employees = isToday 
              ? await ApiService.getActiveEmployeesForWorkSite(workSite.id!)
              : <Map<String, dynamic>>[];
          employeesByWorkSite[workSite.id!] = employees;
          
          // Carica SEMPRE i turni completati per la data selezionata
          await _loadCompletedShifts(workSite.id!);
          
          // Logica espansione:
          // - Se ci sono dipendenti IN (solo oggi) -> espandi
          // - Se ci sono turni completati -> espandi
          // - Altrimenti -> comprimi
          final completedShifts = _completedShiftsByWorkSite[workSite.id!] ?? [];
          expandedStates[workSite.id!] = employees.isNotEmpty || completedShifts.isNotEmpty;
          
        } catch (e) {
          print('Error loading employees for worksite ${workSite.id}: $e');
          employeesByWorkSite[workSite.id!] = [];
          expandedStates[workSite.id!] = false;
        }
      }
      
      // Ordina i cantieri UNA SOLA VOLTA al caricamento
      final sortedWorkSites = _sortWorkSites(activeWorkSites, employeesByWorkSite);
      
      setState(() {
        _workSites = activeWorkSites;
        _sortedWorkSites = sortedWorkSites;
        _activeEmployeesByWorkSite = employeesByWorkSite;
        _expandedWorkSites = expandedStates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dati: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadAllData(); // Ricarica i dati per la nuova data
    }
  }

  Future<void> _generateAllWorkSitesReportPdf() async {
    setState(() => _isGeneratingReport = true);

    try {
      final filePath = await ApiService.downloadForemanAllWorkSitesReportPdf(
        date: _selectedDate,
      );

      setState(() => _isGeneratingReport = false);

      if (filePath != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report PDF scaricato: ${filePath.split('/').last}'),
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
          const SnackBar(content: Text('Errore durante il download del report PDF')),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingReport = false);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final employee = appState.currentEmployee;

    // Calcola totale dipendenti presenti
    final totalActiveEmployees = _activeEmployeesByWorkSite.values
        .fold<int>(0, (sum, employees) => sum + employees.length);
    
    // Calcola cantieri con dipendenti attivi (almeno 1 dipendente presente)
    final activeWorkSitesCount = _activeEmployeesByWorkSite.values
        .where((employees) => employees.isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: null,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 56,
        flexibleSpace: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[700]!, Colors.blue[900]!],
              ),
            ),
            child: Stack(
              children: [
                // Titolare a sinistra
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'Titolare - ${employee?.name ?? ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                
                // Calendario + Report al centro assoluto
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsante Data + Calendario
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Pulsante Report
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: _isGeneratingReport
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                                  ),
                                )
                              : Icon(Icons.description, color: Colors.blue[700], size: 22),
                          onPressed: _isGeneratingReport ? null : _generateAllWorkSitesReportPdf,
                          tooltip: 'Stampa report PDF tutti i cantieri',
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Pulsanti a destra
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadAllData,
                        tooltip: 'Aggiorna',
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () {
                          appState.logout();
                        },
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildWorkSitesWithEmployees(activeWorkSitesCount, totalActiveEmployees),
    );
  }

  Widget _buildWorkSitesWithEmployees(int activeWorkSitesCount, int totalActive) {
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

    return Column(
      children: [
        // Header riepilogo - molto più compatto
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.construction,
                label: 'Cantieri Attivi',
                value: '$activeWorkSitesCount',
                color: Colors.white,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildSummaryItem(
                icon: Icons.people,
                label: 'Dipendenti Presenti',
                value: '$totalActive',
                color: Colors.white,
              ),
            ],
          ),
        ),
        
        // Lista cantieri espandibili (usa lista pre-ordinata)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _sortedWorkSites.length,
            itemBuilder: (context, index) {
              final workSite = _sortedWorkSites[index];
              final employees = _activeEmployeesByWorkSite[workSite.id!] ?? [];
              final isExpanded = _expandedWorkSites[workSite.id!] ?? false;
              
              return _buildWorkSiteExpansionTile(workSite, employees, isExpanded);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.9),
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkSiteExpansionTile(WorkSite workSite, List<Map<String, dynamic>> employees, bool isExpanded) {
    final completedShifts = _completedShiftsByWorkSite[workSite.id!] ?? [];
    
    // I cantieri con dipendenti IN o turni completati devono essere SEMPRE aperti
    final shouldBeExpanded = employees.isNotEmpty || completedShifts.isNotEmpty ? true : isExpanded;
    
    // Determina il colore del cantiere
    Color workSiteColor;
    Color workSiteBackgroundColor;
    if (employees.isNotEmpty) {
      // Verde: ha dipendenti presenti
      workSiteColor = Colors.green;
      workSiteBackgroundColor = Colors.green[50]!;
    } else if (completedShifts.isNotEmpty) {
      // Arancione: ha turni completati ma nessuno presente
      workSiteColor = Colors.orange;
      workSiteBackgroundColor = Colors.orange[50]!;
    } else {
      // Grigio: nessuna attività
      workSiteColor = Colors.grey;
      workSiteBackgroundColor = Colors.grey[100]!;
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: employees.isNotEmpty || completedShifts.isNotEmpty
              ? workSiteColor 
              : Colors.grey[300]!,
          width: employees.isNotEmpty || completedShifts.isNotEmpty ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey<int>(workSite.id!),
        initiallyExpanded: shouldBeExpanded,
        onExpansionChanged: (expanded) {
          // I cantieri con dipendenti IN o turni completati non possono essere compressi
          if (employees.isNotEmpty || completedShifts.isNotEmpty) {
            return; // Ignora il tentativo di comprimere
          }
          
          // Posticipa setState per evitare "setState during build"
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _expandedWorkSites[workSite.id!] = expanded;
              });
            }
          });
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: workSiteBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: workSiteColor,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.construction,
            color: workSiteColor == Colors.green 
                ? Colors.green[700]! 
                : (workSiteColor == Colors.orange ? Colors.orange[700]! : Colors.grey[600]!),
            size: 24,
          ),
        ),
        title: Text(
          workSite.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    workSite.address,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge numero dipendenti/turni
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: workSiteColor == Colors.grey ? Colors.grey[300]! : workSiteColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    size: 14,
                    color: workSiteColor == Colors.grey ? Colors.grey[600]! : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${employees.length + completedShifts.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: workSiteColor == Colors.grey ? Colors.grey[600]! : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          if (employees.isEmpty && completedShifts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, color: Colors.grey[400]!, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Nessuna attività in questa data',
                    style: TextStyle(
                      color: Colors.grey[600]!,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Dipendenti ATTIVI (verde) - solo se visualizziamo oggi
                  ...employees.map((empData) {
                    final timestamp = empData['timestamp'] != null
                        ? DateTime.parse(empData['timestamp'])
                        : null;
                    final name = empData['employeeName'] ?? 'Sconosciuto';
                    final initial = name.substring(0, 1).toUpperCase();

                    return _buildEmployeeAvatar(
                      name: name,
                      initial: initial,
                      inTimestamp: timestamp,
                      outTimestamp: null,
                      isActive: true,
                    );
                  }),
                  
                  // Dipendenti con TURNO COMPLETATO (arancione) - SEMPRE visualizzati
                  ...completedShifts.map((shiftData) {
                    final name = shiftData['employeeName'] ?? 'Sconosciuto';
                    final initial = name.substring(0, 1).toUpperCase();
                    final inTime = shiftData['inTimestamp'] != null
                        ? DateTime.parse(shiftData['inTimestamp'])
                        : null;
                    final outTime = shiftData['outTimestamp'] != null
                        ? DateTime.parse(shiftData['outTimestamp'])
                        : null;

                    return _buildEmployeeAvatar(
                      name: name,
                      initial: initial,
                      inTimestamp: inTime,
                      outTimestamp: outTime,
                      isActive: false,
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmployeeAvatar({
    required String name,
    required String initial,
    required DateTime? inTimestamp,
    required DateTime? outTimestamp,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [Colors.green[400]!, Colors.green[700]!]
                  : [Colors.orange[400]!, Colors.orange[700]!],
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? Colors.green : Colors.orange).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Nome
        SizedBox(
          width: 70,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Orari
        if (isActive && inTimestamp != null)
          // Solo orario di ingresso (verde)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.login, size: 10, color: Colors.green),
                const SizedBox(width: 2),
                Text(
                  DateFormat('HH:mm').format(inTimestamp),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ],
            ),
          ),
        if (!isActive && inTimestamp != null && outTimestamp != null)
          // Ingresso (verde) e Uscita (arancione) con colori diversi
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.login, size: 9, color: Colors.green),
                    const SizedBox(width: 2),
                    Text(
                      DateFormat('HH:mm').format(inTimestamp),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.logout, size: 9, color: Colors.orange),
                    const SizedBox(width: 2),
                    Text(
                      DateFormat('HH:mm').format(outTimestamp),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// Pagina separata per lo storico del cantiere
class _WorkSiteHistoryPage extends StatefulWidget {
  final WorkSite workSite;

  const _WorkSiteHistoryPage({required this.workSite});

  @override
  _WorkSiteHistoryPageState createState() => _WorkSiteHistoryPageState();
}

class _WorkSiteHistoryPageState extends State<_WorkSiteHistoryPage> {
  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  List<Map<String, dynamic>>? _historyData;
  bool _isLoadingHistory = false;

  Future<void> _loadWorkSiteHistory() async {
    if (_historyStartDate == null || _historyEndDate == null) {
      return;
    }

    setState(() => _isLoadingHistory = true);

    try {
      final data = await ApiService.getWorkSiteHistory(
        workSiteId: widget.workSite.id!,
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
    setState(() => _isLoadingHistory = true);

    try {
      final filePath = await ApiService.downloadForemanWorkSiteReport(
        workSiteId: widget.workSite.id!,
        startDate: _historyStartDate,
        endDate: _historyEndDate,
      );

      setState(() => _isLoadingHistory = false);

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
      setState(() => _isLoadingHistory = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Storico - ${widget.workSite.name}'),
      ),
      body: Column(
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
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.workSite.address,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filtri data
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleziona Periodo',
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

          // Storico timbrature
          if (_historyData != null)
            _buildHistoryView()
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.date_range, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Seleziona un periodo per visualizzare lo storico',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
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
                    color: Colors.grey[600]!,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final pairs = _createAttendancePairsFromRecords(records);

    if (pairs.isEmpty) {
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Ci sono solo ingressi senza uscite',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9E9E9E),
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
    
    final Map<int, List<Map<String, dynamic>>> recordsByEmployee = {};
    for (var record in records) {
      final empId = record['employeeId'] as int;
      if (!recordsByEmployee.containsKey(empId)) {
        recordsByEmployee[empId] = [];
      }
      recordsByEmployee[empId]!.add(record);
    }

    recordsByEmployee.forEach((empId, empRecords) {
      empRecords.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < empRecords.length; i++) {
        final record = empRecords[i];
        
        if (record['type'] == 'in') {
          Map<String, dynamic>? outRecord;
          for (int j = i + 1; j < empRecords.length; j++) {
            if (empRecords[j]['type'] == 'out') {
              outRecord = empRecords[j];
              break;
            }
          }

          final inTimestamp = DateTime.parse(record['timestamp']);
          final outTimestamp = outRecord != null ? DateTime.parse(outRecord['timestamp']) : null;

          String? duration;
          bool isNightShift = false;
          
          if (outTimestamp != null) {
            final diff = outTimestamp.difference(inTimestamp);
            final hours = diff.inHours;
            final minutes = diff.inMinutes % 60;
            duration = '$hours:${minutes.toString().padLeft(2, '0')}';
            
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

    pairs.sort((a, b) {
      final aTime = a['inTimestamp'] as DateTime;
      final bTime = b['inTimestamp'] as DateTime;
      return bTime.compareTo(aTime);
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
          // Header
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
                if (duration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 14, color: Colors.grey),
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
          
          // Badge
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
          
          // IN/OUT
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniTimeRecord(inTime, isIn: true),
                ),
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
          color: Colors.grey[200]!,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Column(
          children: [
            Icon(
              isIn ? Icons.login : Icons.logout,
              size: 20,
              color: Colors.grey[400]!,
            ),
            const SizedBox(height: 4),
            Text(
              isIn ? 'IN' : 'OUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600]!,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '---',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500]!,
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
