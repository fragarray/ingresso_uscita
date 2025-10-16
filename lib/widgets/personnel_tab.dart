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
              employee.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
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

    // Determina lo stato attuale del dipendente
    final records = await ApiService.getAttendanceRecords(
      employeeId: employee.id!,
    );
    final currentlyClockedIn = records.isNotEmpty && records.first.type == 'in';

    // Dialog per selezionare cantiere e tipo
    WorkSite? selectedWorkSite = workSites.first;
    String selectedType = 'in'; // Default a INGRESSO (l'admin può cambiare)
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
                // Pulsanti per selezionare IN o OUT
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
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedType = 'out';
                          });
                        },
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
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cantiere:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<WorkSite>(
                  value: selectedWorkSite,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: workSites.map((ws) {
                    return DropdownMenuItem<WorkSite>(
                      value: ws,
                      child: Text(ws.name),
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

    // VALIDAZIONE: Se sto forzando un'uscita e il dipendente è già timbrato in ingresso,
    // verifico che l'orario di uscita non sia antecedente all'ingresso
    if (selectedType == 'out' && currentlyClockedIn && useCustomDateTime) {
      // Prendo l'orario dell'ultimo ingresso
      final lastInRecord = records.first;
      final lastInDateTime = lastInRecord.timestamp;

      // Confronto con l'orario di uscita selezionato
      if (customDateTime.isBefore(lastInDateTime)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore: L\'uscita non può essere antecedente all\'ingresso!\n'
              'Ingresso: ${lastInDateTime.day.toString().padLeft(2, '0')}/${lastInDateTime.month.toString().padLeft(2, '0')}/${lastInDateTime.year} '
              'alle ${lastInDateTime.hour.toString().padLeft(2, '0')}:${lastInDateTime.minute.toString().padLeft(2, '0')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // PRIMA: Se è un IN forzato con data diversa da oggi, chiedi se vuole aggiungere anche OUT
    DateTime? outDateTime;
    String? outNotes;

    if (selectedType == 'in' && useCustomDateTime) {
      final forcedDate = DateTime(
        customDateTime.year,
        customDateTime.month,
        customDateTime.day,
      );
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Se la data forzata è diversa da oggi, suggerisci OUT
      if (!forcedDate.isAtSameMomentAs(todayDate)) {
        if (!mounted) return;

        final shouldAddOut = await showDialog<bool>(
          context: context,
          builder: (context) => _buildSuggestOutDialog(
            context,
            employee,
            selectedWorkSite!,
            customDateTime,
          ),
        );

        if (shouldAddOut == true && mounted) {
          // Mostra dialog per selezionare l'ora di uscita e raccogli i dati
          final outData = await _collectOutData(
            employee,
            selectedWorkSite!,
            customDateTime,
          );
          if (outData != null) {
            outDateTime = outData['dateTime'] as DateTime;
            outNotes = outData['notes'] as String?;
          }
        }
      }
    }

    // DOPO: Ora salva tutto in ordine (prima IN, poi OUT se presente)
    try {
      // 1. Salva IN
      final inSuccess = await ApiService.forceAttendance(
        employeeId: employee.id!,
        workSiteId: selectedWorkSite!.id!,
        type: selectedType,
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

      // 2. Se c'è OUT da aggiungere, salvalo
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
          context.read<AppState>().triggerRefresh();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ingresso e uscita forzati per ${employee.name}\n'
                'IN: ${customDateTime.hour.toString().padLeft(2, '0')}:${customDateTime.minute.toString().padLeft(2, '0')} - '
                'OUT: ${outDateTime.hour.toString().padLeft(2, '0')}:${outDateTime.minute.toString().padLeft(2, '0')}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // IN salvato ma OUT fallito
          context.read<AppState>().triggerRefresh();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ingresso forzato salvato, ma errore durante uscita per ${employee.name}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Solo IN salvato
        context.read<AppState>().triggerRefresh();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timbratura ${selectedType == 'in' ? 'ingresso' : 'uscita'} '
              'forzata per ${employee.name}',
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

  Widget _buildSuggestOutDialog(
    BuildContext context,
    Employee employee,
    WorkSite workSite,
    DateTime inDateTime,
  ) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.help_outline, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(child: Text('Aggiungi Uscita?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ingresso Forzato',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dipendente: ${employee.name}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Cantiere: ${workSite.name}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Data: ${inDateTime.day.toString().padLeft(2, '0')}/${inDateTime.month.toString().padLeft(2, '0')}/${inDateTime.year}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Ora Ingresso: ${inDateTime.hour.toString().padLeft(2, '0')}:${inDateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hai forzato un ingresso per una data diversa da oggi.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vuoi aggiungere anche la timbratura di uscita per evitare conteggi errati delle ore?',
                    style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('NO, SOLO INGRESSO'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('SÌ, AGGIUNGI USCITA'),
        ),
      ],
    );
  }

  /// Raccoglie i dati per l'uscita senza salvarli nel database
  /// Restituisce una mappa con 'dateTime' e 'notes' oppure null se annullato
  Future<Map<String, dynamic>?> _collectOutData(
    Employee employee,
    WorkSite workSite,
    DateTime inDateTime,
  ) async {
    // Suggerisci ora di uscita (es: 8 ore dopo l'ingresso)
    final suggestedOut = inDateTime.add(const Duration(hours: 8));
    DateTime outDateTime = DateTime(
      inDateTime.year,
      inDateTime.month,
      inDateTime.day,
      suggestedOut.hour,
      suggestedOut.minute,
    );

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
                  'Seleziona ora di uscita:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
                          inDateTime.year,
                          inDateTime.month,
                          inDateTime.day,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    AddEmployeeDialog(onEmployeeAdded: _loadEmployees),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuovo Dipendente'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: Row(
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
                                                    employee.email,
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
                                itemCount: _employeeAttendance.length,
                                itemBuilder: (context, index) {
                                  final record = _employeeAttendance[index];
                                  final isForced = record.isForced;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    color: isForced ? Colors.orange[50] : null,
                                    child: ListTile(
                                      leading: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            record.type == 'in'
                                                ? Icons.login
                                                : Icons.logout,
                                            color: record.type == 'in'
                                                ? Colors.green
                                                : Colors.red,
                                            size: 32,
                                          ),
                                          if (isForced)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.orange,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.warning,
                                                  color: Colors.white,
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
                                              '${DateFormat('dd/MM/yyyy HH:mm:ss').format(record.timestamp.toLocal())} - ${record.type == 'in' ? 'Ingresso' : 'Uscita'}',
                                            ),
                                          ),
                                          if (isForced) ...[
                                            const SizedBox(width: 8),
                                            Chip(
                                              label: const Text(
                                                'FORZATA',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor: Colors.orange,
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isForced
                                                ? 'Timbratura forzata (GPS: 0.0, 0.0)'
                                                : 'Lat: ${record.latitude.toStringAsFixed(6)}, Lng: ${record.longitude.toStringAsFixed(6)}',
                                          ),
                                          if (isForced &&
                                              record.deviceInfo.isNotEmpty)
                                            Text(
                                              record.deviceInfo,
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 12,
                                                color: Colors.orange,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: isForced
                                          ? const Icon(
                                              Icons.admin_panel_settings,
                                              color: Colors.orange,
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
