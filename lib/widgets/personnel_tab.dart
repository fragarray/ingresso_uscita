import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/attendance_record.dart';
import '../services/api_service.dart';
import '../widgets/add_employee_dialog.dart';
import '../widgets/edit_employee_dialog.dart';

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
  bool _isLoading = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _filteredEmployees = List.from(employees);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi davvero eliminare ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await ApiService.removeEmployee(employee.id!);
      if (success) {
        _loadEmployees();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'eliminazione del dipendente')),
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
              // Lista dipendenti
              SizedBox(
                width: 300,
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
                                      
                                      return Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        color: isSelected 
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : null,
                                        child: InkWell(
                                          onTap: () => _loadEmployeeAttendance(employee),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                // Avatar
                                                CircleAvatar(
                                                  child: Text(employee.name[0].toUpperCase()),
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
                                                                fontSize: 16,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
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
                                                                  fontSize: 11,
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
                                                          fontSize: 14,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
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
                                                    if (!employee.isAdmin)
                                                      IconButton(
                                                        icon: const Icon(Icons.delete),
                                                        tooltip: 'Elimina dipendente',
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
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Storico Presenze - ${_selectedEmployee!.name}',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _employeeAttendance.length,
                                    itemBuilder: (context, index) {
                                      final record = _employeeAttendance[index];
                                      return ListTile(
                                        leading: Icon(
                                          record.type == 'in'
                                              ? Icons.login
                                              : Icons.logout,
                                          color: record.type == 'in'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        title: Text(
                                          '${record.timestamp.toLocal().toString().split('.')[0]} - ${record.type == 'in' ? 'Ingresso' : 'Uscita'}',
                                        ),
                                        subtitle: Text(
                                          'Lat: ${record.latitude.toStringAsFixed(6)}, Lng: ${record.longitude.toStringAsFixed(6)}',
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