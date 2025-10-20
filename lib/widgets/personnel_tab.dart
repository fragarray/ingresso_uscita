import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/attendance_record.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';
import '../widgets/add_employee_dialog.dart';
import '../widgets/edit_employee_dialog.dart';
import '../main.dart';

class PersonnelTab extends StatefulWidget {
  const PersonnelTab({Key? key}) : super(key: key);

  @override
  _PersonnelTabState createState() => _PersonnelTabState();
}

class _PersonnelTabState extends State<PersonnelTab> {
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  List<WorkSite> _workSites = [];
  Employee? _selectedEmployee;
  List<AttendanceRecord> _employeeAttendance = [];
  Map<int, bool> _employeeClockedInStatus = {}; // employeeId -> is clocked in
  bool _isLoading = false;
  final _searchController = TextEditingController();
  AppState? _appState; // Riferimento salvato
  int _lastRefreshCounter = -1; // Traccia l'ultimo refresh processato

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(_filterEmployees);
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
    _searchController.dispose();
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final currentCounter = _appState?.refreshCounter ?? -1;
    // Esegui refresh solo se il counter è cambiato
    if (currentCounter != _lastRefreshCounter && currentCounter >= 0) {
      debugPrint(
        '=== PERSONNEL TAB: Refresh triggered (counter: $currentCounter) ===',
      );
      _lastRefreshCounter = currentCounter;
      _loadEmployees();
      if (_selectedEmployee != null) {
        _loadEmployeeAttendance(_selectedEmployee!);
      }
    }
  }

  void _filterEmployees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(_employees);
      } else {
        _filteredEmployees = _employees.where((employee) {
          return employee.name.toLowerCase().contains(query) ||
              (employee.email?.toLowerCase().contains(query) ?? false) ||
              employee.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      final workSites = await ApiService.getWorkSites();
      final allAttendance = await ApiService.getAttendanceRecords();

      // Calcola lo stato di timbratura per ogni dipendente
      final Map<int, bool> statusMap = {};
      for (var employee in employees) {
        final employeeRecords = allAttendance
            .where((r) => r.employeeId == employee.id)
            .toList();

        if (employeeRecords.isNotEmpty) {
          // Il primo record è il più recente (ordinamento DESC dal server)
          statusMap[employee.id!] = employeeRecords.first.type == 'in';
        } else {
          statusMap[employee.id!] = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _workSites = workSites;
        _filteredEmployees = List.from(employees);
        _employeeClockedInStatus = statusMap;
        _selectedEmployee = null;
        _employeeAttendance = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante il caricamento dei dipendenti'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEmployeeAttendance(Employee employee) async {
    setState(() => _isLoading = true);
    try {
      final attendance = await ApiService.getAttendanceRecords(
        employeeId: employee.id,
      );
      if (!mounted) return;
      setState(() {
        _employeeAttendance = attendance;
        _selectedEmployee = employee;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante il caricamento delle presenze'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Crea coppie IN/OUT dai record di presenza
  List<Map<String, dynamic>> _createAttendancePairs() {
    final pairs = <Map<String, dynamic>>[];
    AttendanceRecord? lastIn;
    
    // IMPORTANTE: Il server restituisce i record in ordine DESC (dal più recente)
    // ma per accoppiarli correttamente dobbiamo processarli in ordine cronologico ASC (dal più vecchio)
    final sortedRecords = _employeeAttendance.reversed.toList();
    
    for (var record in sortedRecords) {
      if (record.type == 'in') {
        // Se c'è già un IN senza OUT, lo aggiungiamo come singolo
        if (lastIn != null) {
          pairs.add({
            'in': lastIn,
            'out': null,
            'isMixed': false,
          });
        }
        lastIn = record;
      } else if (record.type == 'out') {
        if (lastIn != null) {
          // Verifica se i cantieri sono diversi
          final isMixed = lastIn.workSiteId != record.workSiteId;
          pairs.add({
            'in': lastIn,
            'out': record,
            'isMixed': isMixed,
          });
          lastIn = null;
        } else {
          // OUT senza IN precedente - lo aggiungiamo come singolo
          pairs.add({
            'in': null,
            'out': record,
            'isMixed': false,
          });
        }
      }
    }
    
    // Se c'è un IN finale senza OUT
    if (lastIn != null) {
      pairs.add({
        'in': lastIn,
        'out': null,
        'isMixed': false,
      });
    }
    
    // Inverti l'ordine per mostrare dal più recente al più vecchio
    return pairs.reversed.toList();
  }

  Future<void> _removeEmployee(Employee employee) async {
    // Verifica se è un admin e se è l'unico o se è l'utente corrente
    if (employee.isAdmin) {
      final currentUser = context.read<AppState>().currentEmployee;

      // Impedisci l'eliminazione se è l'utente corrente
      if (employee.id == currentUser?.id) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 30),
                SizedBox(width: 8),
                Text('Operazione non permessa'),
              ],
            ),
            content: const Text(
              'Non puoi eliminare il tuo stesso account.\n\n'
              'Per eliminare questo account admin, accedi con un altro account admin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Verifica se è l'unico admin
      final adminCount = _employees.where((e) => e.isAdmin).length;
      if (adminCount <= 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 30),
                SizedBox(width: 8),
                Text('Operazione non permessa'),
              ],
            ),
            content: const Text(
              'Non puoi eliminare l\'unico amministratore del sistema.\n\n'
              'Prima di eliminare questo account, crea almeno un altro amministratore.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Verifica se il dipendente è attualmente timbrato IN
    final records = await ApiService.getAttendanceRecords(
      employeeId: employee.id,
    );
    if (records.isNotEmpty) {
      // Ordina per timestamp decrescente per ottenere l'ultima timbratura
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final lastRecord = records.first;

      if (lastRecord.type == 'in') {
        // Il dipendente è attualmente timbrato IN, chiedi di timbrare OUT prima
        final shouldForceOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Forza Timbratura OUT - ${employee.name}'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'STATO ATTUALE: TIMBRATO IN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ultima timbratura:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('• Tipo: ENTRATA'),
                  Text(
                    '• Data/Ora: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(lastRecord.timestamp)}',
                  ),
                  Text(
                    '• Cantiere: ${lastRecord.workSiteId != null ? "ID ${lastRecord.workSiteId}" : "N/A"}',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'È necessario timbrare OUT prima di eliminare il dipendente.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nota: La timbratura OUT verrà registrata automaticamente con i dati dell\'ultima timbratura IN.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ANNULLA ELIMINAZIONE'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('TIMBRA OUT E CONTINUA'),
              ),
            ],
          ),
        );

        if (shouldForceOut != true) {
          return; // Annulla l'eliminazione
        }

        // Effettua timbratura OUT forzata
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Timbratura OUT in corso...'),
              ],
            ),
          ),
        );

        final currentUser = context.read<AppState>().currentEmployee;
        final success = await ApiService.forceAttendance(
          employeeId: employee.id!,
          type: 'out',
          workSiteId: lastRecord.workSiteId ?? 0, // Usa 0 se null
          adminId: currentUser?.id ?? 0,
          notes: 'Timbratura OUT automatica prima dell\'eliminazione',
        );

        if (!mounted) return;
        Navigator.pop(context); // Chiudi loading dialog

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Errore durante la timbratura OUT. Eliminazione annullata.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        // Mostra conferma timbratura OUT
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 8),
                Text('Timbratura OUT completata'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${employee.name} è stato timbrato OUT con successo.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Timbratura registrata',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'La timbratura OUT è stata registrata nel database e apparirà nei report.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ora puoi procedere con l\'eliminazione del dipendente.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('CONTINUA'),
              ),
            ],
          ),
        );
      }
    }

    // Prima conferma
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 30),
            SizedBox(width: 8),
            Text('Attenzione!'),
          ],
        ),
        content: Text(
          'Stai per eliminare ${employee.isAdmin ? "l\'amministratore" : "il dipendente"} "${employee.name}".\n\n'
          'Questa azione non può essere annullata. Prima dell\'eliminazione '
          'dovrai scaricare obbligatoriamente il report completo delle timbrature.\n\n'
          'Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('CONTINUA'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Download obbligatorio del report SOLO se il dipendente ha timbrature
    final hasRecords = records.isNotEmpty;
    String? reportPath;
    
    if (hasRecords) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generazione report in corso...'),
            ],
          ),
        ),
      );

      try {
        reportPath = await ApiService.downloadExcelReportFiltered(
          employeeId: employee.id!,
        );

        if (!mounted) return;
        Navigator.pop(context); // Chiudi loading dialog

        if (reportPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Errore durante la generazione del report. Eliminazione annullata.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Mostra conferma download con path
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 8),
                Text('Report scaricato'),
              ],
            ),
            content: Text(
              'Il report delle timbrature è stato salvato in:\n\n$reportPath\n\n'
              'Conserva questo file prima di procedere con l\'eliminazione.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Chiudi loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la generazione del report: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Nessuna timbratura - mostra messaggio informativo
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 30),
              SizedBox(width: 8),
              Text('Nessuna Timbratura'),
            ],
          ),
          content: Text(
            '${employee.name} non ha mai effettuato timbrature.\n\n'
            'Non è necessario scaricare alcun report.\n\n'
            'Il dipendente verrà eliminato completamente dal database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    // Conferma finale
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text('Conferma Finale'),
          ],
        ),
        content: Text(
          'ULTIMA CONFERMA\n\n'
          'Stai per eliminare definitivamente:\n'
          '• Nome: ${employee.name}\n'
          '• Email: ${employee.email}\n'
          '• Ruolo: ${employee.isAdmin ? "Amministratore" : "Dipendente"}\n'
          '${hasRecords ? "• Timbrature: ${records.length}\n" : "• Timbrature: 0 (nessuna)\n"}'
          '${hasRecords ? "\nIl report è stato scaricato.\n" : "\nNessun report da scaricare.\n"}'
          '\nSei assolutamente sicuro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO, ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SÌ, ELIMINA'),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    // Esegui eliminazione
    try {
      final success = await ApiService.removeEmployee(employee.id!);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasRecords 
                ? '${employee.name} eliminato. Report salvato in:\n$reportPath'
                : '${employee.name} eliminato (nessuna timbratura presente)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        _loadEmployees();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'eliminazione')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di connessione al server')),
      );
    }
  }

  void _editEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => EditEmployeeDialog(
        employee: employee,
        onEmployeeUpdated: _loadEmployees,
      ),
    );
  }

  Future<void> _forceAttendance(Employee employee) async {
    // Carica i cantieri disponibili
    final workSites = await ApiService.getWorkSites();
    if (!mounted) return;

    if (workSites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun cantiere disponibile')),
      );
      return;
    }

    // Ottieni l'admin corrente
    final admin = context.read<AppState>().currentEmployee;
    if (admin == null || !admin.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore: non sei un amministratore')),
      );
      return;
    }

    // Determina lo stato attuale del dipendente e il cantiere dove è timbrato
    final records = await ApiService.getAttendanceRecords(
      employeeId: employee.id!,
    );
    final currentlyClockedIn = records.isNotEmpty && records.first.type == 'in';
    final currentWorkSiteId = currentlyClockedIn ? records.first.workSiteId : null;

    // Dialog per selezionare cantiere e tipo
    // Preseleziona il cantiere corrente se il dipendente è timbrato IN
    WorkSite? selectedWorkSite;
    if (currentWorkSiteId != null) {
      selectedWorkSite = workSites.firstWhere(
        (ws) => ws.id == currentWorkSiteId,
        orElse: () => workSites.first,
      );
    } else {
      selectedWorkSite = workSites.first;
    }
    
    // ⚠️ LOGICA INTELLIGENTE: 
    // - Se dipendente è IN → può forzare OUT o altro IN
    // - Se dipendente è OUT → può forzare solo IN (mai OUT da solo)
    String selectedType = currentlyClockedIn ? 'out' : 'in'; // Default intelligente
    final notesController = TextEditingController();

    // Variabili per data/ora personalizzate
    bool useCustomDateTime = false;
    DateTime customDateTime = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('Forza Timbratura - ${employee.name}')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stato attuale: ${currentlyClockedIn ? "TIMBRATO IN" : "TIMBRATO OUT"}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo timbratura:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Pulsanti per selezionare IN o OUT (con validazione)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedType = 'in';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedType == 'in'
                                ? Colors.green
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedType == 'in'
                                  ? Colors.green
                                  : Colors.grey[300]!,
                              width: selectedType == 'in' ? 3 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.login,
                                color: selectedType == 'in'
                                    ? Colors.white
                                    : Colors.green,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'INGRESSO',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: selectedType == 'in'
                                      ? Colors.white
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: currentlyClockedIn ? 1.0 : 0.3, // Disabilitato se OUT
                        child: InkWell(
                          onTap: currentlyClockedIn ? () {
                            setState(() {
                              selectedType = 'out';
                            });
                          } : null, // Disabilitato se dipendente è OUT
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedType == 'out'
                                  ? Colors.red
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedType == 'out'
                                    ? Colors.red
                                    : Colors.grey[300]!,
                                width: selectedType == 'out' ? 3 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: selectedType == 'out'
                                      ? Colors.white
                                      : Colors.red,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'USCITA',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: selectedType == 'out'
                                        ? Colors.white
                                        : Colors.red[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!currentlyClockedIn) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'USCITA disabilitata: dipendente non è attualmente IN',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Cantiere:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<WorkSite>(
                  value: selectedWorkSite,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                    fillColor: currentWorkSiteId != null && selectedWorkSite?.id == currentWorkSiteId
                        ? Colors.green[50]
                        : null,
                    filled: currentWorkSiteId != null && selectedWorkSite?.id == currentWorkSiteId,
                  ),
                  items: workSites.map((ws) {
                    final isCurrentWorkSite = currentWorkSiteId != null && ws.id == currentWorkSiteId;
                    return DropdownMenuItem<WorkSite>(
                      value: ws,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrentWorkSite)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              ws.name,
                              style: TextStyle(
                                fontWeight: isCurrentWorkSite ? FontWeight.bold : FontWeight.normal,
                                color: isCurrentWorkSite ? Colors.green[700] : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentWorkSite)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ATTUALE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedWorkSite = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // SEZIONE DATA E ORA
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Data e Ora Timbratura',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Switch per selezionare modalità
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  useCustomDateTime = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: !useCustomDateTime
                                      ? Colors.blue
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !useCustomDateTime
                                        ? Colors.blue
                                        : Colors.blue[200]!,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      color: !useCustomDateTime
                                          ? Colors.white
                                          : Colors.blue,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ora Attuale',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: !useCustomDateTime
                                            ? Colors.white
                                            : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  useCustomDateTime = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: useCustomDateTime
                                      ? Colors.blue
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: useCustomDateTime
                                        ? Colors.blue
                                        : Colors.blue[200]!,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.edit_calendar,
                                      color: useCustomDateTime
                                          ? Colors.white
                                          : Colors.blue,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Personalizza',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: useCustomDateTime
                                            ? Colors.white
                                            : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (useCustomDateTime) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        // Selezione Data
                        InkWell(
                          onTap: () async {
                            // Determina il firstDate in base al contesto:
                            // Se sto forzando un'uscita e c'è un ingresso attivo,
                            // non posso selezionare una data antecedente all'ingresso
                            DateTime firstDate = DateTime(2020);
                            if (selectedType == 'out' && currentlyClockedIn) {
                              final lastInDateTime = records.first.timestamp;
                              firstDate = DateTime(
                                lastInDateTime.year,
                                lastInDateTime.month,
                                lastInDateTime.day,
                              );
                            }

                            final date = await showDatePicker(
                              context: context,
                              initialDate: customDateTime,
                              firstDate: firstDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                customDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  customDateTime.hour,
                                  customDateTime.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Data:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${customDateTime.day.toString().padLeft(2, '0')}/${customDateTime.month.toString().padLeft(2, '0')}/${customDateTime.year}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Selezione Ora
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                customDateTime,
                              ),
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              // Crea il nuovo DateTime con l'ora selezionata
                              final newDateTime = DateTime(
                                customDateTime.year,
                                customDateTime.month,
                                customDateTime.day,
                                time.hour,
                                time.minute,
                              );

                              // VALIDAZIONE: Se sto forzando un'uscita con ingresso attivo,
                              // verifica che il nuovo orario non sia antecedente all'ingresso
                              if (selectedType == 'out' && currentlyClockedIn) {
                                final lastInDateTime = records.first.timestamp;
                                if (newDateTime.isBefore(lastInDateTime)) {
                                  // Mostra errore
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Errore: L\'uscita non può essere antecedente all\'ingresso!\n'
                                        'Ingresso: ${lastInDateTime.hour.toString().padLeft(2, '0')}:${lastInDateTime.minute.toString().padLeft(2, '0')} '
                                        'del ${lastInDateTime.day.toString().padLeft(2, '0')}/${lastInDateTime.month.toString().padLeft(2, '0')}/${lastInDateTime.year}',
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                  return; // Non aggiornare il DateTime
                                }
                              }

                              setState(() {
                                customDateTime = newDateTime;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ora:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${customDateTime.hour.toString().padLeft(2, '0')}:${customDateTime.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verrà usata l\'ora attuale del dispositivo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[900],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ATTENZIONE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Questa timbratura sarà marcata come FORZATA e includerà:\n'
                        '• Il tuo nome come amministratore\n'
                        '• Coordinate GPS 0,0\n'
                        '• Note: ',
                        style: TextStyle(fontSize: 12, color: Colors.red[900]),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: 'Inserisci note (opzionale)...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.red[300],
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.red[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.red[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.red[400]!,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 12, color: Colors.red[900]),
                        maxLines: 2,
                        maxLength: 200,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Questa azione verrà registrata nei report.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULLA'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('FORZA TIMBRATURA'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedWorkSite == null) {
      notesController.dispose();
      return;
    }

    final notes = notesController.text.trim();
    notesController.dispose();

    // ⚠️ VALIDAZIONE CRITICA: Non posso forzare OUT se dipendente è già OUT
    if (selectedType == 'out' && !currentlyClockedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ ERRORE: Non puoi forzare un\'uscita!\n\n'
            'Il dipendente NON risulta attualmente timbrato in ingresso.\n'
            'Devi prima forzare un ingresso corrispondente.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // ⚠️ LOGICA DIFFERENZIATA per IN vs OUT
    if (selectedType == 'out') {
      // CASO 1: Forzatura USCITA (dipendente attualmente IN)
      // Validazione: OUT non può essere prima dell'IN esistente
      if (useCustomDateTime && currentlyClockedIn) {
        final lastInDateTime = records.first.timestamp;
        if (customDateTime.isBefore(lastInDateTime)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ERRORE: L\'uscita non può essere prima dell\'ingresso!\n\n'
                'Ingresso: ${lastInDateTime.day.toString().padLeft(2, '0')}/${lastInDateTime.month.toString().padLeft(2, '0')}/${lastInDateTime.year} '
                'alle ${lastInDateTime.hour.toString().padLeft(2, '0')}:${lastInDateTime.minute.toString().padLeft(2, '0')}\n\n'
                'Seleziona un orario successivo all\'ingresso.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
          return;
        }
      }

      // Salva solo OUT
      try {
        final success = await ApiService.forceAttendance(
          employeeId: employee.id!,
          workSiteId: selectedWorkSite!.id!,
          type: 'out',
          adminId: admin.id!,
          notes: notes.isNotEmpty ? notes : null,
          timestamp: useCustomDateTime ? customDateTime : null,
        );

        if (!mounted) return;

        if (success) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            context.read<AppState>().triggerRefresh();
          }
          if (_selectedEmployee?.id == employee.id) {
            await _loadEmployeeAttendance(employee);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Uscita forzata per ${employee.name}\n'
                'Dipendente ora OUT',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore durante la timbratura forzata'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
      return; // Fine gestione OUT
    }

    // CASO 2: Forzatura INGRESSO
    
    // ⚠️ VALIDAZIONE CRITICA: Verifica sovrapposizione timbrature
    // Controlla se dipendente ha già una timbratura IN nello stesso range orario
    // IMPORTANTE: Controllo SEMPRE, sia con timestamp custom che corrente!
    if (selectedType == 'in') {
      // Carica TUTTE le timbrature del dipendente
      final allRecords = await ApiService.getAttendanceRecords(
        employeeId: employee.id!,
      );
      
      // Determina il timestamp da usare (custom o corrente)
      final forcedDateTime = useCustomDateTime ? customDateTime : DateTime.now();
      
      // VALIDAZIONE 1: Cerca timbrature IN nel range +/- 1 ora
      final rangeStart = forcedDateTime.subtract(const Duration(hours: 1));
      final rangeEnd = forcedDateTime.add(const Duration(hours: 1));
      
      // VALIDAZIONE 2: Controlla OVERLAP con turni esistenti
      // Ordina i record per timestamp per creare coppie IN/OUT
      final sortedRecords = List<AttendanceRecord>.from(allRecords);
      sortedRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Cerca coppie IN → OUT e controlla overlap con il nuovo IN forzato
      for (int i = 0; i < sortedRecords.length - 1; i++) {
        final current = sortedRecords[i];
        final next = sortedRecords[i + 1];
        
        // Se troviamo una coppia IN → OUT
        if (current.type == 'in' && next.type == 'out') {
          final existingInTime = current.timestamp;
          final existingOutTime = next.timestamp;
          
          // CASO 1: Timestamp forzato cade DENTRO turno esistente
          // Esempio: Esiste 08:00-17:00, forzo IN alle 14:00
          final isInsideExistingShift = forcedDateTime.isAfter(existingInTime) && 
                                         forcedDateTime.isBefore(existingOutTime);
          
          if (isInsideExistingShift) {
            // CONFLITTO GRAVE: Stai forzando IN dentro un turno esistente
            if (!mounted) return;
            
            // Trova nomi cantieri
            String inWorkSiteName = 'N/D';
            String outWorkSiteName = 'N/D';
            
            if (current.workSiteId != null) {
              try {
                final ws = workSites.firstWhere((w) => w.id == current.workSiteId);
                inWorkSiteName = ws.name;
              } catch (e) {
                inWorkSiteName = 'Cantiere ID ${current.workSiteId}';
              }
            }
            
            if (next.workSiteId != null) {
              try {
                final ws = workSites.firstWhere((w) => w.id == next.workSiteId);
                outWorkSiteName = ws.name;
              } catch (e) {
                outWorkSiteName = 'Cantiere ID ${next.workSiteId}';
              }
            }
            
            // Mostra dialog CRITICO
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.dangerous, color: Colors.red, size: 32),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CONFLITTO CRITICO',
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 24),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ SOVRAPPOSIZIONE TURNO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Il dipendente ${employee.name} era GIÀ IN SERVIZIO in quel momento!\n\nIl timestamp forzato cade DENTRO un turno esistente.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🕐 Turno Esistente:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.login, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'IN: ${DateFormat('dd/MM/yyyy HH:mm').format(existingInTime.toLocal())}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              'Cantiere: $inWorkSiteName',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.logout, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'OUT: ${DateFormat('dd/MM/yyyy HH:mm').format(existingOutTime.toLocal())}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              'Cantiere: $outWorkSiteName',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🚫 Timestamp che stai tentando:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'IN: ${DateFormat('dd/MM/yyyy HH:mm').format(forcedDateTime.toLocal())}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '↑ Questo timestamp cade DENTRO il turno esistente!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Un dipendente non può avere due turni sovrapposti.\n\n'
                                'Se devi modificare il turno esistente, usa "Modifica" tenendo premuto sull\'elemento nello storico.',
                                style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('HO CAPITO', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            );
            
            // Blocca SEMPRE l'operazione
            return;
          }
        }
      }
      
      // Se arriviamo qui, controlliamo anche IN singoli vicini
      for (final record in allRecords) {
        if (record.type == 'in') {
          final recordTime = record.timestamp;
          // Controlla se c'è sovrapposizione nel range ±1 ora
          if (recordTime.isAfter(rangeStart) && recordTime.isBefore(rangeEnd)) {
            // CONFLITTO TROVATO!
            if (!mounted) return;
            
            // Trova il nome del cantiere del record esistente
            String existingWorkSiteName = 'N/D';
            if (record.workSiteId != null) {
              try {
                final ws = workSites.firstWhere((w) => w.id == record.workSiteId);
                existingWorkSiteName = ws.name;
              } catch (e) {
                existingWorkSiteName = 'Cantiere ID ${record.workSiteId}';
              }
            }
            
            // Mostra dialog con dettagli conflitto
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CONFLITTO TIMBRATURA',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ OPERAZIONE NON CONSENTITA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Il dipendente ${employee.name} ha già una timbratura IN nello stesso range orario!',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Timbratura Esistente:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data: ${recordTime.day.toString().padLeft(2, '0')}/${recordTime.month.toString().padLeft(2, '0')}/${recordTime.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Ora IN: ${recordTime.hour.toString().padLeft(2, '0')}:${recordTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Cantiere: $existingWorkSiteName',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Timbratura che stai tentando:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data: ${forcedDateTime.day.toString().padLeft(2, '0')}/${forcedDateTime.month.toString().padLeft(2, '0')}/${forcedDateTime.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Ora IN: ${forcedDateTime.hour.toString().padLeft(2, '0')}:${forcedDateTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Cantiere: ${selectedWorkSite?.name ?? 'N/D'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Un dipendente non può essere in due luoghi contemporaneamente.\n\n'
                              'Se vuoi modificare la timbratura esistente, tieni premuto sull\'elemento nello storico.',
                              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('HO CAPITO'),
                  ),
                ],
              ),
            );
            
            // Blocca sempre l'operazione
            return;
          }
        }
      }
    }
    
    DateTime? outDateTime;
    String? outNotes;

    final now = DateTime.now();
    DateTime forcedDateTime;
    
    if (useCustomDateTime) {
      forcedDateTime = customDateTime;
    } else {
      forcedDateTime = now;
    }

    // Calcola le ore trascorse dall'ingresso forzato a ORA
    final hoursSinceIn = now.difference(forcedDateTime).inHours;

    // REGOLA: Se sono passate più di 8 ore, OBBLIGATORIO forzare anche OUT
    final mustForceOut = hoursSinceIn >= 8;

    if (mustForceOut && selectedType == 'in') {
      if (!mounted) return;

      // Mostra dialog che RICHIEDE di inserire anche l'OUT
      final shouldAddOut = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Non può chiudere senza scegliere
        builder: (context) => _buildRequireOutDialog(
          context,
          employee,
          selectedWorkSite!,
          forcedDateTime,
        ),
      );

      if (shouldAddOut != true) {
        // L'admin ha annullato, non salvare nulla
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operazione annullata: timbratura non salvata'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Raccogli dati dell'uscita OBBLIGATORIA
      if (!mounted) return;
      final outData = await _collectOutData(
        employee,
        selectedWorkSite!,
        forcedDateTime,
      );
      
      if (outData == null) {
        // L'admin ha annullato, non salvare nulla
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operazione annullata: timbratura non salvata'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      outDateTime = outData['dateTime'] as DateTime;
      outNotes = outData['notes'] as String?;
      
      // ⚠️ VALIDAZIONE OVERLAP TURNO COMPLETO
      // Ora che abbiamo sia IN che OUT, verifichiamo che non si sovrappongano
      // con turni esistenti
      if (!mounted) return;
      
      // Ricarica i record per avere dati aggiornati
      final allRecords = await ApiService.getAttendanceRecords(
        employeeId: employee.id!,
      );
      
      final sortedRecords = List<AttendanceRecord>.from(allRecords);
      sortedRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Controlla overlap con turni esistenti
      for (int i = 0; i < sortedRecords.length - 1; i++) {
        final current = sortedRecords[i];
        final next = sortedRecords[i + 1];
        
        if (current.type == 'in' && next.type == 'out') {
          final existingInTime = current.timestamp;
          final existingOutTime = next.timestamp;
          
          // Controlla 4 casi di overlap:
          // 1. Nuovo IN dentro turno esistente
          final newInInsideExisting = forcedDateTime.isAfter(existingInTime) && 
                                       forcedDateTime.isBefore(existingOutTime);
          
          // 2. Nuovo OUT dentro turno esistente
          final newOutInsideExisting = outDateTime.isAfter(existingInTime) && 
                                        outDateTime.isBefore(existingOutTime);
          
          // 3. Turno esistente completamente dentro nuovo turno
          final existingInsideNew = existingInTime.isAfter(forcedDateTime) && 
                                    existingOutTime.isBefore(outDateTime);
          
          // 4. Qualsiasi intersezione tra gli intervalli
          final hasOverlap = (forcedDateTime.isBefore(existingOutTime) && 
                              outDateTime.isAfter(existingInTime));
          
          if (hasOverlap) {
            if (!mounted) return;
            
            // Trova nomi cantieri per dialog
            String existingInWorkSite = 'N/D';
            String existingOutWorkSite = 'N/D';
            
            if (current.workSiteId != null) {
              try {
                final ws = workSites.firstWhere((w) => w.id == current.workSiteId);
                existingInWorkSite = ws.name;
              } catch (e) {
                existingInWorkSite = 'Cantiere ID ${current.workSiteId}';
              }
            }
            
            if (next.workSiteId != null) {
              try {
                final ws = workSites.firstWhere((w) => w.id == next.workSiteId);
                existingOutWorkSite = ws.name;
              } catch (e) {
                existingOutWorkSite = 'Cantiere ID ${next.workSiteId}';
              }
            }
            
            // Determina tipo di overlap per messaggio
            String overlapType;
            if (newInInsideExisting && newOutInsideExisting) {
              overlapType = 'Il nuovo turno è completamente DENTRO un turno esistente!';
            } else if (existingInsideNew) {
              overlapType = 'Il nuovo turno CONTIENE completamente un turno esistente!';
            } else if (newInInsideExisting) {
              overlapType = 'Il nuovo IN cade dentro un turno esistente!';
            } else if (newOutInsideExisting) {
              overlapType = 'Il nuovo OUT cade dentro un turno esistente!';
            } else {
              overlapType = 'I due turni si sovrappongono parzialmente!';
            }
            
            // Dialog CRITICO di overlap
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.dangerous, color: Colors.red, size: 32),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'OVERLAP TURNI',
                        style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              overlapType,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '🕐 Turno Esistente:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.login, color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'IN: ${DateFormat('dd/MM/yyyy HH:mm').format(existingInTime.toLocal())}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '   Cantiere: $existingInWorkSite',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.logout, color: Colors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'OUT: ${DateFormat('dd/MM/yyyy HH:mm').format(existingOutTime.toLocal())}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '   Cantiere: $existingOutWorkSite',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '🚫 Nuovo Turno Tentato:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.login, color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'IN: ${DateFormat('dd/MM/yyyy HH:mm').format(forcedDateTime.toLocal())}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '   Cantiere: ${selectedWorkSite!.name}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.logout, color: Colors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'OUT: ${DateFormat('dd/MM/yyyy HH:mm').format(outDateTime!.toLocal())}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '   Cantiere: ${selectedWorkSite!.name}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.yellow[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Un dipendente non può avere turni sovrapposti',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Per correggere i dati:\n'
                                    '• Usa "Modifica" per cambiare turno esistente\n'
                                    '• Oppure elimina il turno esistente prima',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('HO CAPITO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            
            // Blocca l'operazione
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Operazione annullata: overlap tra turni rilevato'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }
    }

    // SALVATAGGIO ATOMICO: Salva prima IN, poi OUT (se presente)
    try {
      // 1. Salva IN
      final inSuccess = await ApiService.forceAttendance(
        employeeId: employee.id!,
        workSiteId: selectedWorkSite!.id!,
        type: 'in',
        adminId: admin.id!,
        notes: notes.isNotEmpty ? notes : null,
        timestamp: useCustomDateTime ? customDateTime : null,
      );

      if (!mounted) return;

      if (!inSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la timbratura forzata'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Se c'è OUT da aggiungere, salvalo SUBITO
      if (outDateTime != null) {
        final outSuccess = await ApiService.forceAttendance(
          employeeId: employee.id!,
          workSiteId: selectedWorkSite!.id!,
          type: 'out',
          adminId: admin.id!,
          notes: outNotes,
          timestamp: outDateTime,
        );

        if (!mounted) return;

        if (outSuccess) {
          // Entrambe salvate con successo
          await Future.delayed(const Duration(milliseconds: 300));
          
          if (mounted) {
            context.read<AppState>().triggerRefresh();
          }
          
          if (_selectedEmployee?.id == employee.id) {
            await _loadEmployeeAttendance(employee);
          }

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Coppia IN/OUT forzata per ${employee.name}\n'
                'IN: ${forcedDateTime.hour.toString().padLeft(2, '0')}:${forcedDateTime.minute.toString().padLeft(2, '0')} - '
                'OUT: ${outDateTime.hour.toString().padLeft(2, '0')}:${outDateTime.minute.toString().padLeft(2, '0')}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // ❌ CRITICO: IN salvato ma OUT fallito - dati inconsistenti!
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ ERRORE CRITICO: Ingresso salvato ma uscita fallita!\n'
                'Controllare manualmente il dipendente ${employee.name}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } else {
        // Solo IN salvato (timbratura recente < 8 ore)
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          context.read<AppState>().triggerRefresh();
          }
        
        if (_selectedEmployee?.id == employee.id) {
          await _loadEmployeeAttendance(employee);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Ingresso forzato per ${employee.name}\n'
              'Dipendente attualmente IN',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  // Dialog che OBBLIGA ad aggiungere OUT (>8 ore fa)
  Widget _buildRequireOutDialog(
    BuildContext context,
    Employee employee,
    WorkSite workSite,
    DateTime inDateTime,
  ) {
    final now = DateTime.now();
    final hoursSince = now.difference(inDateTime).inHours;
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          const Expanded(child: Text('Uscita Obbligatoria')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'REGOLA OBBLIGATORIA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Stai forzando un ingresso di più di 8 ore fa ($hoursSince ore).',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Per mantenere la coerenza dei dati, DEVI forzare anche l\'uscita.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingresso Forzato',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Dipendente: ${employee.name}', style: const TextStyle(fontSize: 13)),
                Text('Cantiere: ${workSite.name}', style: const TextStyle(fontSize: 13)),
                Text(
                  'Data: ${inDateTime.day.toString().padLeft(2, '0')}/${inDateTime.month.toString().padLeft(2, '0')}/${inDateTime.year}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Ora IN: ${inDateTime.hour.toString().padLeft(2, '0')}:${inDateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ANNULLA TUTTO'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK, AGGIUNGI USCITA'),
        ),
      ],
    );
  }

  // Dialog suggerimento OUT (manteniamo per compatibilità, ma non più usato)
  /// Raccoglie i dati per l'uscita senza salvarli nel database
  /// Restituisce una mappa con 'dateTime' e 'notes' oppure null se annullato
  Future<Map<String, dynamic>?> _collectOutData(
    Employee employee,
    WorkSite workSite,
    DateTime inDateTime,
  ) async {
    // Suggerisci ora di uscita (8 ore dopo l'ingresso)
    // IMPORTANTE: consideriamo il cambio del giorno se le 8 ore sforano
    DateTime outDateTime = inDateTime.add(const Duration(hours: 8));

    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.logout, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('Forza Uscita - ${employee.name}')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cantiere: ${workSite.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data: ${inDateTime.day.toString().padLeft(2, '0')}/${inDateTime.month.toString().padLeft(2, '0')}/${inDateTime.year}',
                      ),
                      Text(
                        'Ingresso: ${inDateTime.hour.toString().padLeft(2, '0')}:${inDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Data e ora di uscita:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Selettore DATA uscita
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: outDateTime,
                      firstDate: inDateTime,
                      lastDate: inDateTime.add(const Duration(days: 2)),
                    );
                    if (date != null) {
                      setState(() {
                        outDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          outDateTime.hour,
                          outDateTime.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${outDateTime.day.toString().padLeft(2, '0')}/${outDateTime.month.toString().padLeft(2, '0')}/${outDateTime.year}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.red),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Selettore ORA uscita
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(outDateTime),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() {
                        outDateTime = DateTime(
                          outDateTime.year,
                          outDateTime.month,
                          outDateTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ora Uscita:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${outDateTime.hour.toString().padLeft(2, '0')}:${outDateTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.red),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note (opzionale):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'Es: Turno standard 8 ore',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULLA'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('FORZA USCITA'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      notesController.dispose();
      return null;
    }

    // Restituisci i dati raccolti SENZA salvare nel database
    final notes = notesController.text.trim();
    notesController.dispose();

    return {'dateTime': outDateTime, 'notes': notes.isNotEmpty ? notes : null};
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Stack(
      children: [
        // Layout principale - verticale per mobile, orizzontale per desktop
        isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        // FloatingActionButton per aggiungere dipendente
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    AddEmployeeDialog(onEmployeeAdded: _loadEmployees),
              );
            },
            tooltip: 'Nuovo Dipendente',
            child: const Icon(Icons.person_add),
          ),
        ),
      ],
    );
  }

  // Layout orizzontale per desktop (larghezza >= 900px)
  Widget _buildDesktopLayout() {
    return Row(
            children: [
              // Lista dipendenti con larghezza dinamica
              SizedBox(
                width: context.watch<AppState>().personnelTabDividerWidth,
                child: Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Campo di ricerca
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cerca dipendente...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      // Contatore risultati
                      if (_searchController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_filteredEmployees.length} risultati',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Lista dipendenti filtrata
                      Expanded(
                        child: _isLoading && _selectedEmployee == null
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredEmployees.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nessun dipendente trovato',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredEmployees.length,
                                itemBuilder: (context, index) {
                                  final employee = _filteredEmployees[index];
                                  final isSelected =
                                      _selectedEmployee?.id == employee.id;
                                  final isClockedIn =
                                      _employeeClockedInStatus[employee.id] ??
                                      false;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : isClockedIn
                                        ? Colors.green[50]
                                        : null,
                                    elevation: isClockedIn ? 3 : 1,
                                    child: InkWell(
                                      onTap: () =>
                                          _loadEmployeeAttendance(employee),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            // Avatar
                                            CircleAvatar(
                                              backgroundColor: isClockedIn
                                                  ? Colors.green
                                                  : null,
                                              foregroundColor: isClockedIn
                                                  ? Colors.white
                                                  : null,
                                              child: isClockedIn
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 20,
                                                    )
                                                  : Text(
                                                      employee.name[0]
                                                          .toUpperCase(),
                                                    ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Nome e email
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          employee.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                fontSize: 15,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      if (employee.isAdmin) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'ADMIN',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    employee.email ?? 'Nessuna email',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 13,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Azioni
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  tooltip:
                                                      'Modifica dipendente',
                                                  iconSize: 20,
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
                                                  onPressed: () =>
                                                      _editEmployee(employee),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
                                                  tooltip: employee.isAdmin
                                                      ? 'Elimina amministratore'
                                                      : 'Elimina dipendente',
                                                  iconSize: 20,
                                                  color: Colors.red[700],
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
                                                  onPressed: () =>
                                                      _removeEmployee(employee),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // Divisore ridimensionabile
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final appState = context.read<AppState>();
                    double newWidth =
                        appState.personnelTabDividerWidth + details.delta.dx;
                    // Limita la larghezza tra 250 e 600 pixel
                    newWidth = newWidth.clamp(250.0, 600.0);
                    appState.setPersonnelTabDividerWidth(newWidth);
                  },
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Dettaglio presenze
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(8.0),
                  child: _selectedEmployee == null
                      ? const Center(child: Text('Seleziona un dipendente'))
                      : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Storico Presenze - ${_selectedEmployee!.name}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _forceAttendance(_selectedEmployee!),
                                    icon: const Icon(
                                      Icons.admin_panel_settings,
                                      size: 20,
                                    ),
                                    label: const Text('Forza Timbratura'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _createAttendancePairs().length,
                                itemBuilder: (context, index) {
                                  final pair = _createAttendancePairs()[index];
                                  final inRecord = pair['in'] as AttendanceRecord?;
                                  final outRecord = pair['out'] as AttendanceRecord?;
                                  final isMixed = pair['isMixed'] as bool;
                                  
                                  // Se è una coppia completa
                                  if (inRecord != null && outRecord != null) {
                                    return _buildSessionPairCard(inRecord, outRecord, isMixed);
                                  }
                                  // Se è solo IN (dipendente attualmente timbrato)
                                  else if (inRecord != null) {
                                    return _buildSingleRecordCard(inRecord, isIn: true);
                                  }
                                  // Se è solo OUT (anomalia)
                                  else if (outRecord != null) {
                                    return _buildSingleRecordCard(outRecord, isIn: false);
                                  }
                                  
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
  }

  // Layout verticale per mobile (larghezza < 900px)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Lista dipendenti in alto con altezza dinamica
        SizedBox(
          height: context.watch<AppState>().personnelTabDividerWidth,
          child: _buildEmployeeListCard(),
        ),
        // Divisore ridimensionabile orizzontale
        MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              final appState = context.read<AppState>();
              double newHeight =
                  appState.personnelTabDividerWidth + details.delta.dy;
              // Limita l'altezza tra 150 e 500 pixel
              newHeight = newHeight.clamp(150.0, 500.0);
              appState.setPersonnelTabDividerWidth(newHeight);
            },
            child: Container(
              height: 8,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Dettaglio presenze in basso
        Expanded(
          child: _buildAttendanceDetailCard(),
        ),
      ],
    );
  }

  // Card con la lista dipendenti (riutilizzata da entrambi i layout)
  Widget _buildEmployeeListCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Campo di ricerca
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca dipendente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Contatore risultati
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_filteredEmployees.length} risultati',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Lista dipendenti filtrata
          Expanded(
            child: _isLoading && _selectedEmployee == null
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nessun dipendente trovato',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : _buildEmployeeList(),
          ),
        ],
      ),
    );
  }

  // Card con il dettaglio presenze (riutilizzata da entrambi i layout)
  Widget _buildAttendanceDetailCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: _selectedEmployee == null
          ? const Center(child: Text('Seleziona un dipendente'))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAttendanceDetail(),
    );
  }

  // Lista dipendenti (estratta per riutilizzo)
  Widget _buildEmployeeList() {
    return ListView.builder(
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = _filteredEmployees[index];
        final isSelected = _selectedEmployee?.id == employee.id;
        final isClockedIn = _employeeClockedInStatus[employee.id] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : isClockedIn
                  ? Colors.green[50]
                  : null,
          elevation: isClockedIn ? 3 : 1,
          child: InkWell(
            onTap: () => _loadEmployeeAttendance(employee),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor: isClockedIn ? Colors.green : null,
                    foregroundColor: isClockedIn ? Colors.white : null,
                    child: isClockedIn
                        ? const Icon(Icons.check, size: 20)
                        : Text(employee.name[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  // Informazioni dipendente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                employee.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (employee.isAdmin) ...[
                              const SizedBox(width: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employee.email ?? 'Nessuna email',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isClockedIn) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Timbrato IN',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Indicatore visivo per selezione/stato
                  if (isSelected || isClockedIn)
                    Icon(
                      isSelected ? Icons.chevron_right : Icons.check_circle,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.green,
                      size: 24,
                    ),
                  // Pulsanti azione
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Modifica dipendente',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => EditEmployeeDialog(
                              employee: employee,
                              onEmployeeUpdated: _loadEmployees,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        tooltip: 'Elimina dipendente',
                        onPressed: () => _removeEmployee(employee),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Dettaglio presenze (estratto per riutilizzo)
  Widget _buildAttendanceDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header elegante con sfondo sfumato
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storico Presenze',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedEmployee!.name,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[700],
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _forceAttendance(_selectedEmployee!),
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('Forza'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _employeeAttendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nessuna timbratura',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _createAttendancePairs().length,
                  itemBuilder: (context, index) {
                    final pair = _createAttendancePairs()[index];
                    final inRecord = pair['in'] as AttendanceRecord?;
                    final outRecord = pair['out'] as AttendanceRecord?;
                    final isMixed = pair['isMixed'] as bool;
                    
                    // Se è una coppia completa
                    if (inRecord != null && outRecord != null) {
                      return _buildSessionPairCard(inRecord, outRecord, isMixed);
                    }
                    // Se è solo IN (dipendente attualmente timbrato)
                    else if (inRecord != null) {
                      return _buildSingleRecordCard(inRecord, isIn: true);
                    }
                    // Se è solo OUT (anomalia)
                    else if (outRecord != null) {
                      return _buildSingleRecordCard(outRecord, isIn: false);
                    }
                    
                    
                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  // Costruisce una card per una coppia completa IN/OUT
  Widget _buildSessionPairCard(AttendanceRecord inRecord, AttendanceRecord outRecord, bool isMixed) {
    final inWorkSite = _workSites.firstWhere(
      (ws) => ws.id == inRecord.workSiteId,
      orElse: () => WorkSite(id: 0, name: 'Sconosciuto', address: '', latitude: 0, longitude: 0),
    );
    final outWorkSite = _workSites.firstWhere(
      (ws) => ws.id == outRecord.workSiteId,
      orElse: () => WorkSite(id: 0, name: 'Sconosciuto', address: '', latitude: 0, longitude: 0),
    );
    
    // Calcola durata
    final duration = outRecord.timestamp.difference(inRecord.timestamp);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    // Verifica se l'uscita è in un giorno diverso
    final inDate = DateFormat('dd/MM/yyyy').format(inRecord.timestamp.toLocal());
    final outDate = DateFormat('dd/MM/yyyy').format(outRecord.timestamp.toLocal());
    final isDifferentDay = inDate != outDate;
    
    return GestureDetector(
      onLongPress: () => _showEditAttendanceMenu(inRecord, outRecord),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6), // Ridotto da 8 a 6
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isMixed 
            ? [Colors.orange[50]!, Colors.orange[100]!]
            : [Colors.blue[50]!, Colors.blue[100]!],
        ),
        borderRadius: BorderRadius.circular(12), // Ridotto da 16 a 12
        border: Border.all(
          color: isMixed ? Colors.orange : Colors.blue,
          width: 1.5, // Ridotto da 2 a 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: (isMixed ? Colors.orange : Colors.blue).withOpacity(0.15), // Ridotto opacità
            blurRadius: 4, // Ridotto da 8 a 4
            offset: const Offset(0, 2), // Ridotto da (0, 4) a (0, 2)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con data e durata
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Ridotto padding
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMixed 
                  ? [Colors.orange[600]!, Colors.orange[700]!]
                  : [Colors.blue[600]!, Colors.blue[700]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10), // Ridotto da 14 a 10
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // Ridotto da 6 a 4
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6), // Ridotto da 8 a 6
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 14, // Ridotto da 18 a 14
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8), // Ridotto da 12 a 8
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inDate,
                      style: const TextStyle(
                        fontSize: 14, // Ridotto da 16 a 14
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isDifferentDay)
                      Text(
                        'Turno notturno → $outDate',
                        style: TextStyle(
                          fontSize: 10, // Ridotto da 11 a 10
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Ridotto padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16), // Ridotto da 20 a 16
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08), // Ridotto opacità
                        blurRadius: 3, // Ridotto da 4 a 3
                        offset: const Offset(0, 1), // Ridotto offset
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 16, // Ridotto da 18 a 16
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4), // Ridotto da 6 a 4
                      Text(
                        '${hours}h ${minutes}m',
                        style: const TextStyle(
                          fontSize: 13, // Ridotto da 14 a 13
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Badge cantieri misti
          if (isMixed)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0), // Ridotto margini ulteriormente
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Ridotto padding
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(5), // Ridotto da 6 a 5
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, size: 12, color: Colors.white), // Ridotto da 14 a 12
                  const SizedBox(width: 3), // Ridotto da 4 a 3
                  const Text(
                    'CANTIERI DIVERSI',
                    style: TextStyle(
                      fontSize: 9, // Ridotto da 10 a 9
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2, // Ridotto da 0.3 a 0.2
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenuto IN/OUT
          Padding(
            padding: const EdgeInsets.all(8), // Ridotto da 12 a 8
            child: Row(
              children: [
                // IN
                Expanded(
                  child: _buildMiniRecord(inRecord, inWorkSite, isIn: true),
                ),
                // Linea connettore centrale
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6), // Ridotto da 8 a 6
                  child: Column(
                    children: [
                      Container(
                        width: 2, // Ridotto da 3 a 2
                        height: 15, // Ridotto da 20 a 15
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
                        padding: const EdgeInsets.all(3), // Ridotto da 4 a 3
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!, width: 1), // Ridotto da 1.5 a 1
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 10, // Ridotto da 12 a 10
                          color: Colors.grey[600],
                        ),
                      ),
                      Container(
                        width: 2, // Ridotto da 3 a 2
                        height: 15, // Ridotto da 20 a 15
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
                  child: _buildMiniRecord(outRecord, outWorkSite, isIn: false),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // Mini card per singolo record (IN o OUT) dentro la coppia - LAYOUT ORIZZONTALE
  Widget _buildMiniRecord(AttendanceRecord record, WorkSite workSite, {required bool isIn}) {
    final isForced = record.isForced;
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIn ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isIn ? Colors.green : Colors.red).withOpacity(0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icona con badge admin se forzato
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isIn 
                      ? [Colors.green[400]!, Colors.green[600]!]
                      : [Colors.red[400]!, Colors.red[600]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (isIn ? Colors.green : Colors.red).withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  isIn ? Icons.login : Icons.logout,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (isForced)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Contenuto orizzontale: tipo, orario, cantiere
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prima riga: Badge tipo + Orario
                Row(
                  children: [
                    // Badge tipo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isIn ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isIn ? 'IN' : 'OUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isIn ? Colors.green[800] : Colors.red[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Orario
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(record.timestamp.toLocal()),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                
                // Seconda riga: Cantiere
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        workSite.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Costruisce una card per un record singolo (IN senza OUT o OUT senza IN)
  Widget _buildSingleRecordCard(AttendanceRecord record, {required bool isIn}) {
    final isForced = record.isForced;
    final workSite = _workSites.firstWhere(
      (ws) => ws.id == record.workSiteId,
      orElse: () => WorkSite(id: 0, name: 'Sconosciuto', address: '', latitude: 0, longitude: 0),
    );

    return GestureDetector(
      onLongPress: () => _showEditAttendanceMenu(record, null),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isForced
            ? Colors.orange[50]
            : isIn
                ? Colors.green[50]
                : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isForced
              ? Colors.orange.withOpacity(0.5)
              : isIn
                  ? Colors.green.withOpacity(0.5)
                  : Colors.red.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isIn ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      isIn ? Icons.login : Icons.logout,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (isForced)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isIn ? 'INGRESSO' : 'USCITA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isIn ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      if (isForced) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FORZATA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (isIn) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'IN CORSO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(record.timestamp.toLocal()),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm:ss').format(record.timestamp.toLocal()),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          workSite.name,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // Mostra menu di modifica/cancellazione per timbratura
  void _showEditAttendanceMenu(AttendanceRecord inRecord, AttendanceRecord? outRecord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Modifica Timbratura'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dipendente: ${_selectedEmployee!.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Data: ${DateFormat('dd/MM/yyyy').format(inRecord.timestamp.toLocal())}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cosa vuoi fare?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _editAttendance(inRecord, outRecord);
            },
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Modifica'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAttendance(inRecord, outRecord);
            },
            icon: const Icon(Icons.delete, size: 20),
            label: const Text('Elimina'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }

  // Modifica timbratura esistente
  Future<void> _editAttendance(AttendanceRecord inRecord, AttendanceRecord? outRecord) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditAttendanceDialog(
        inRecord: inRecord,
        outRecord: outRecord,
        workSites: _workSites,
        employeeName: _selectedEmployee!.name,
      ),
    );

    if (result == null) return; // Annullato

    // Mostra loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Modifica in corso...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Ottieni admin ID
    final adminId = context.read<AppState>().currentEmployee?.id;
    if (adminId == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Errore: Admin non identificato'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool allSuccess = true;

    // Modifica IN se ci sono cambiamenti
    if (result['editIn'] == true) {
      final success = await ApiService.editAttendance(
        recordId: inRecord.id!,
        adminId: adminId,
        timestamp: result['inTimestamp'],
        workSiteId: result['inWorkSiteId'],
      );
      if (!success) allSuccess = false;
    }

    // Modifica OUT se esiste e ci sono cambiamenti
    if (outRecord != null && result['editOut'] == true) {
      final success = await ApiService.editAttendance(
        recordId: outRecord.id!,
        adminId: adminId,
        timestamp: result['outTimestamp'],
        workSiteId: result['outWorkSiteId'],
      );
      if (!success) allSuccess = false;
    }

    // Chiudi loading
    if (!mounted) return;
    Navigator.of(context).pop();

    if (allSuccess) {
      // Ricarica i dati
      _loadEmployees();
      if (_selectedEmployee != null) {
        await _loadEmployeeAttendance(_selectedEmployee!);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Timbratura modificata con successo'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Errore durante la modifica'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Elimina timbratura esistente
  Future<void> _deleteAttendance(AttendanceRecord inRecord, AttendanceRecord? outRecord) async {
    // Conferma cancellazione
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Conferma Eliminazione'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sei sicuro di voler eliminare questa timbratura?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dipendente: ${_selectedEmployee!.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IN: ${DateFormat('dd/MM/yyyy HH:mm').format(inRecord.timestamp.toLocal())}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (outRecord != null)
                    Text(
                      'OUT: ${DateFormat('dd/MM/yyyy HH:mm').format(outRecord.timestamp.toLocal())}',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Questa azione è irreversibile!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mostra loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Eliminazione in corso...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Chiama API per eliminare
    final adminId = context.read<AppState>().currentEmployee?.id;
    if (adminId == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Errore: Admin non identificato'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final success = await ApiService.deleteAttendance(
      recordId: inRecord.id!,
      adminId: adminId,
      deleteOutToo: outRecord != null, // Se c'è OUT, elimina anche quello
    );

    // Chiudi loading
    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      // Ricarica i dati
      _loadEmployees();
      if (_selectedEmployee != null) {
        await _loadEmployeeAttendance(_selectedEmployee!);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Timbratura eliminata con successo'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Errore durante l\'eliminazione'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}

// Dialog per modificare una timbratura esistente
class _EditAttendanceDialog extends StatefulWidget {
  final AttendanceRecord inRecord;
  final AttendanceRecord? outRecord;
  final List<WorkSite> workSites;
  final String employeeName;

  const _EditAttendanceDialog({
    required this.inRecord,
    required this.outRecord,
    required this.workSites,
    required this.employeeName,
  });

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  late DateTime _inDateTime;
  late DateTime? _outDateTime;
  late int _inWorkSiteId;
  late int? _outWorkSiteId;

  @override
  void initState() {
    super.initState();
    _inDateTime = widget.inRecord.timestamp.toLocal();
    _outDateTime = widget.outRecord?.timestamp.toLocal();
    _inWorkSiteId = widget.inRecord.workSiteId!;
    _outWorkSiteId = widget.outRecord?.workSiteId;
  }

  Future<void> _selectDateTime(bool isIn) async {
    final currentDateTime = isIn ? _inDateTime : _outDateTime!;
    
    // Seleziona data
    final date = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (date == null) return;
    
    // Seleziona ora
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDateTime),
    );
    
    if (time == null) return;
    
    // Combina data e ora
    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    
    setState(() {
      if (isIn) {
        _inDateTime = newDateTime;
      } else {
        _outDateTime = newDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modifica Timbratura',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dipendente: ${widget.employeeName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Divider(),
              
              // INGRESSO
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.login, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'INGRESSO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Data/Ora IN
              InkWell(
                onTap: () => _selectDateTime(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data e Ora',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(_inDateTime),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Cantiere IN
              DropdownButtonFormField<int>(
                value: _inWorkSiteId,
                decoration: const InputDecoration(
                  labelText: 'Cantiere',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: widget.workSites.map((ws) {
                  return DropdownMenuItem(
                    value: ws.id,
                    child: Text(ws.name, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _inWorkSiteId = value);
                  }
                },
              ),
              
              // USCITA (se esiste)
              if (widget.outRecord != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'USCITA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Data/Ora OUT
                InkWell(
                  onTap: () => _selectDateTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data e Ora',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(_outDateTime!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Cantiere OUT
                DropdownButtonFormField<int>(
                  value: _outWorkSiteId,
                  decoration: const InputDecoration(
                    labelText: 'Cantiere',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: widget.workSites.map((ws) {
                    return DropdownMenuItem(
                      value: ws.id,
                      child: Text(ws.name, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _outWorkSiteId = value);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // Valida che OUT sia dopo IN
            if (_outDateTime != null && _outDateTime!.isBefore(_inDateTime)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ L\'uscita deve essere successiva all\'ingresso'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            
            // Crea risultato con i cambiamenti
            final result = {
              'editIn': _inDateTime != widget.inRecord.timestamp.toLocal() ||
                        _inWorkSiteId != widget.inRecord.workSiteId,
              'inTimestamp': _inDateTime,
              'inWorkSiteId': _inWorkSiteId,
              
              if (widget.outRecord != null) 'editOut': 
                  _outDateTime != widget.outRecord!.timestamp.toLocal() ||
                  _outWorkSiteId != widget.outRecord!.workSiteId,
              if (widget.outRecord != null) 'outTimestamp': _outDateTime,
              if (widget.outRecord != null) 'outWorkSiteId': _outWorkSiteId,
            };
            
            Navigator.of(context).pop(result);
          },
          icon: const Icon(Icons.save),
          label: const Text('Salva'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
