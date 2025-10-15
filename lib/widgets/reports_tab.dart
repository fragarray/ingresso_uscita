import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/employee.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({Key? key}) : super(key: key);

  @override
  _ReportsTabState createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  bool _isLoading = false;
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  List<WorkSite> _workSites = [];
  Employee? _selectedEmployee;
  WorkSite? _selectedWorkSite;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeInactive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Imposta date default: oggi e 7 giorni fa
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _searchController.addListener(_filterEmployees);
    _loadData();
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
        _filteredEmployees = _employees;
      } else {
        _filteredEmployees = _employees.where((emp) {
          return emp.name.toLowerCase().contains(query) ||
                 emp.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees(includeInactive: _includeInactive);
      final workSites = await ApiService.getWorkSites();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _filteredEmployees = employees;
        _workSites = workSites;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il caricamento dei dati')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    try {
      final filePath = await ApiService.downloadExcelReportFiltered(
        employeeId: _selectedEmployee?.id,
        workSiteId: _selectedWorkSite?.id,
        startDate: _startDate,
        endDate: _endDate,
        includeInactive: _includeInactive,
      );

      if (filePath != null) {
        await OpenFile.open(filePath);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la generazione del report')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la generazione del report')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateHoursReport() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona un dipendente per generare il report ore'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final filePath = await ApiService.downloadEmployeeHoursReport(
        employeeId: _selectedEmployee!.id!,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (filePath != null) {
        await OpenFile.open(filePath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report ore generato per ${_selectedEmployee!.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la generazione del report ore')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateWorkSiteReport() async {
    setState(() => _isLoading = true);
    try {
      final filePath = await ApiService.downloadWorkSiteReport(
        workSiteId: _selectedWorkSite?.id,
        employeeId: _selectedEmployee?.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (filePath != null) {
        await OpenFile.open(filePath);
        if (!mounted) return;
        final cantiereMsg = _selectedWorkSite != null 
            ? 'per ${_selectedWorkSite!.name}' 
            : 'per tutti i cantieri';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report cantiere generato $cantiereMsg'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la generazione del report cantiere')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _setQuickDateRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime.now().subtract(Duration(days: days));
    });
  }

  void _setMonthRange(int months) {
    setState(() {
      _endDate = DateTime.now();
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month - months, now.day);
    });
  }

  Future<void> _showMonthPicker() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Numero di Mesi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('1 Mese'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('2 Mesi'),
              onTap: () => Navigator.pop(context, 2),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('3 Mesi'),
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('6 Mesi'),
              onTap: () => Navigator.pop(context, 6),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('12 Mesi (1 Anno)'),
              onTap: () => Navigator.pop(context, 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (result != null) {
      _setMonthRange(result);
    }
  }

  String _getPeriodDescription() {
    if (_startDate == null || _endDate == null) return 'Nessun periodo selezionato';
    
    final difference = _endDate!.difference(_startDate!).inDays;
    
    if (difference == 7) return '📅 Ultima settimana';
    if (difference >= 28 && difference <= 31) return '📅 Ultimo mese';
    if (difference >= 89 && difference <= 92) return '📅 Ultimi 3 mesi';
    if (difference >= 179 && difference <= 183) return '📅 Ultimi 6 mesi';
    if (difference >= 365 && difference <= 366) return '📅 Ultimo anno';
    
    return '📅 $difference giorni selezionati';
  }

  Widget _buildQuickButton({
    required String label,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color[100],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color[700]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genera Report Excel',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtra per:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Campo ricerca Dipendente con checkbox inattivi
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Cerca dipendente',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _selectedEmployee = null);
                                        },
                                      )
                                    : null,
                                hintText: 'Nome o email dipendente...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: 'Includi dipendenti eliminati',
                            child: FilterChip(
                              label: const Text('Inattivi'),
                              selected: _includeInactive,
                              onSelected: (value) {
                                setState(() {
                                  _includeInactive = value;
                                  _selectedEmployee = null;
                                });
                                _loadData();
                              },
                              avatar: Icon(
                                _includeInactive ? Icons.check_circle : Icons.person_off,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Lista dipendenti filtrati
                      if (_searchController.text.isNotEmpty || _selectedEmployee != null)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              // Opzione "Tutti"
                              if (_searchController.text.isEmpty)
                                ListTile(
                                  leading: const Icon(Icons.people),
                                  title: const Text('Tutti i dipendenti'),
                                  selected: _selectedEmployee == null,
                                  onTap: () {
                                    setState(() {
                                      _selectedEmployee = null;
                                      _searchController.clear();
                                    });
                                  },
                                ),
                              // Dipendenti filtrati
                              ..._filteredEmployees.map((emp) => ListTile(
                                    leading: Icon(
                                      emp.isAdmin ? Icons.admin_panel_settings : Icons.person,
                                      color: emp.isActive ? Colors.blue : Colors.grey,
                                    ),
                                    title: Text(
                                      emp.name,
                                      style: TextStyle(
                                        color: emp.isActive ? Colors.black : Colors.grey,
                                        decoration: emp.isActive ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${emp.email}${emp.isActive ? "" : " (Eliminato)"}',
                                      style: TextStyle(
                                        color: emp.isActive ? Colors.grey[600] : Colors.grey[400],
                                      ),
                                    ),
                                    trailing: emp.isActive 
                                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                        : const Icon(Icons.cancel, color: Colors.red, size: 20),
                                    selected: _selectedEmployee?.id == emp.id,
                                    onTap: () {
                                      setState(() {
                                        _selectedEmployee = emp;
                                        _searchController.text = emp.name;
                                      });
                                    },
                                  )),
                              if (_filteredEmployees.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'Nessun dipendente trovato',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // Dipendente selezionato
                      if (_selectedEmployee != null && _searchController.text.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            avatar: Icon(
                              _selectedEmployee!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                              size: 18,
                            ),
                            label: Text(_selectedEmployee!.name),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => setState(() => _selectedEmployee = null),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dropdown Cantiere
                  DropdownButtonFormField<WorkSite?>(
                    value: _selectedWorkSite,
                    decoration: const InputDecoration(
                      labelText: 'Cantiere',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<WorkSite?>(
                        value: null,
                        child: Text('Tutti i cantieri'),
                      ),
                      ..._workSites.map((w) => DropdownMenuItem<WorkSite>(
                            value: w,
                            child: Text(w.name),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedWorkSite = value),
                  ),
                  const SizedBox(height: 16),
                  // Date Range
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Data Inizio',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _startDate == null
                                ? ''
                                : DateFormat('dd/MM/yyyy').format(_startDate!),
                          ),
                          onTap: () => _selectDate(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Data Fine',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _endDate == null
                                ? ''
                                : DateFormat('dd/MM/yyyy').format(_endDate!),
                          ),
                          onTap: () => _selectDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Periodi Rapidi
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Periodi Rapidi:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickButton(
                        label: '7 Giorni',
                        icon: Icons.calendar_today,
                        color: Colors.blue,
                        onTap: () => _setQuickDateRange(7),
                      ),
                      _buildQuickButton(
                        label: '1 Mese',
                        icon: Icons.calendar_month,
                        color: Colors.green,
                        onTap: () => _setMonthRange(1),
                      ),
                      _buildQuickButton(
                        label: '3 Mesi',
                        icon: Icons.date_range,
                        color: Colors.orange,
                        onTap: () => _setMonthRange(3),
                      ),
                      _buildQuickButton(
                        label: 'Personalizza',
                        icon: Icons.tune,
                        color: Colors.purple,
                        onTap: _showMonthPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          _getPeriodDescription(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Griglia pulsanti per generare report
                  Column(
                    children: [
                      // Prima riga: Report Timbrature + Report Ore
                      Row(
                        children: [
                          // Pulsante Report Timbrature
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generateReport,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.list_alt, size: 20),
                                label: const Text(
                                  'Report\nTimbrature',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 20,
                                  ),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Pulsante Report Ore Dipendente
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: ElevatedButton.icon(
                                onPressed: (_isLoading || _selectedEmployee == null) 
                                    ? null 
                                    : _generateHoursReport,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.access_time, size: 20),
                                label: const Text(
                                  'Report Ore\nDipendente',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 20,
                                  ),
                                  backgroundColor: _selectedEmployee != null 
                                      ? Colors.green 
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Seconda riga: Report Cantiere (full width)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generateWorkSiteReport,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.construction, size: 20),
                          label: Text(
                            _selectedWorkSite != null
                                ? 'Report Cantiere: ${_selectedWorkSite!.name}'
                                : 'Report Tutti i Cantieri',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Info tooltip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Tipi di Report Disponibili:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.list_alt,
                          Colors.blue,
                          'Timbrature:',
                          'Report professionale con 5 fogli: Statistiche generali, Dettaglio giornaliero, Classifica dipendenti (Top 3), Riepilogo cantieri, Timbrature complete'
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.access_time,
                          _selectedEmployee != null ? Colors.green : Colors.grey,
                          'Ore Dipendente:',
                          _selectedEmployee != null 
                              ? 'Calcolo ore per ${_selectedEmployee!.name}'
                              : 'Seleziona un dipendente per abilitare'
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.construction,
                          Colors.orange,
                          'Cantiere:',
                          _selectedWorkSite != null
                              ? 'Statistiche cantiere ${_selectedWorkSite!.name}'
                              : 'Statistiche di tutti i cantieri'
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}