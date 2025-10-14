import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      debugPrint('=== PERSONNEL TAB: Refresh triggered (counter: $currentCounter) ===');
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
        const SnackBar(content: Text('Errore durante il caricamento dei dipendenti')),
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
      final attendance = await ApiService.getAttendanceRecords(employeeId: employee.id);
      if (!mounted) return;
      setState(() {
        _employeeAttendance = attendance;
        _selectedEmployee = employee;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il caricamento delle presenze')),
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
              'Per eliminare questo account admin, accedi con un altro account admin.'
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
              'Prima di eliminare questo account, crea almeno un altro amministratore.'
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
          'Vuoi continuare?'
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

    // Download obbligatorio del report
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

    String? reportPath;
    try {
      reportPath = await ApiService.downloadExcelReportFiltered(
        employeeId: employee.id!,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Chiudi loading dialog
      
      if (reportPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la generazione del report. Eliminazione annullata.'),
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
            'Conserva questo file prima di procedere con l\'eliminazione.'
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
          '• Ruolo: ${employee.isAdmin ? "Amministratore" : "Dipendente"}\n\n'
          'Il report è stato scaricato.\n\n'
          'Sei assolutamente sicuro?'
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
            content: Text('${employee.name} eliminato. Report salvato in:\n$reportPath'),
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
    final records = await ApiService.getAttendanceRecords(employeeId: employee.id!);
    final currentlyClockedIn = records.isNotEmpty && records.first.type == 'in';
    
    // Dialog per selezionare cantiere e tipo
    WorkSite? selectedWorkSite = workSites.first;
    String selectedType = currentlyClockedIn ? 'out' : 'in';
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Forza Timbratura - ${employee.name}'),
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
                // Solo l'opzione corretta in base allo stato
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: currentlyClockedIn ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentlyClockedIn ? Colors.red : Colors.green,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentlyClockedIn ? Icons.logout : Icons.login,
                        color: currentlyClockedIn ? Colors.red : Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentlyClockedIn ? 'USCITA' : 'INGRESSO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: currentlyClockedIn ? Colors.red[900] : Colors.green[900],
                        ),
                      ),
                    ],
                  ),
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
                          const Icon(Icons.warning, color: Colors.red, size: 20),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: 'Inserisci note (opzionale)...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.red[300]),
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
                            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
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
    
    // Esegui la timbratura forzata
    try {
      final notes = notesController.text.trim();
      final success = await ApiService.forceAttendance(
        employeeId: employee.id!,
        workSiteId: selectedWorkSite!.id!,
        type: selectedType,
        adminId: admin.id!,
        notes: notes.isNotEmpty ? notes : null,
      );
      
      notesController.dispose();
      
      if (!mounted) return;
      
      if (success) {
        // Notifica refresh per tutte le tab (incluso questo)
        context.read<AppState>().triggerRefresh();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timbratura ${selectedType == 'in' ? 'ingresso' : 'uscita'} '
              'forzata per ${employee.name}'
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
                builder: (context) => AddEmployeeDialog(
                  onEmployeeAdded: _loadEmployees,
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuovo Dipendente'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
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
                              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
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
                                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
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
                                      final isSelected = _selectedEmployee?.id == employee.id;
                                      final isClockedIn = _employeeClockedInStatus[employee.id] ?? false;
                                      
                                      return Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                
                                                // Nome e email
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              employee.name,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w500,
                                                                fontSize: 15,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                          if (employee.isAdmin) ...[
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.red,
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: const Text(
                                                                'ADMIN',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
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
                                                        overflow: TextOverflow.ellipsis,
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
                                                      tooltip: 'Modifica dipendente',
                                                      iconSize: 20,
                                                      padding: const EdgeInsets.all(8),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
                                                      onPressed: () => _editEmployee(employee),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete),
                                                      tooltip: employee.isAdmin ? 'Elimina amministratore' : 'Elimina dipendente',
                                                      iconSize: 20,
                                                      color: Colors.red[700],
                                                      padding: const EdgeInsets.all(8),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
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
                    double newWidth = appState.personnelTabDividerWidth + details.delta.dx;
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
                      ? const Center(
                          child: Text('Seleziona un dipendente'),
                        )
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Storico Presenze - ${_selectedEmployee!.name}',
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _forceAttendance(_selectedEmployee!),
                                        icon: const Icon(Icons.admin_panel_settings, size: 20),
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
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                    padding: const EdgeInsets.all(2),
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
                                                  '${record.timestamp.toLocal().toString().split('.')[0]} - ${record.type == 'in' ? 'Ingresso' : 'Uscita'}',
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
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ],
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isForced 
                                                    ? 'Timbratura forzata (GPS: 0.0, 0.0)'
                                                    : 'Lat: ${record.latitude.toStringAsFixed(6)}, Lng: ${record.longitude.toStringAsFixed(6)}',
                                              ),
                                              if (isForced && record.deviceInfo.isNotEmpty)
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
                                              ? const Icon(Icons.admin_panel_settings, color: Colors.orange)
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