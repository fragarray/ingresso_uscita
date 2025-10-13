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
  List<WorkSite> _workSites = [];
  Employee? _selectedEmployee;
  WorkSite? _selectedWorkSite;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Imposta date default: oggi e 7 giorni fa
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      final workSites = await ApiService.getWorkSites();
      if (!mounted) return;
      setState(() {
        _employees = employees;
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
                  // Dropdown Dipendente
                  DropdownButtonFormField<Employee?>(
                    value: _selectedEmployee,
                    decoration: const InputDecoration(
                      labelText: 'Dipendente',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Employee?>(
                        value: null,
                        child: Text('Tutti i dipendenti'),
                      ),
                      ..._employees.map((e) => DropdownMenuItem<Employee>(
                            value: e,
                            child: Text(e.name),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedEmployee = value),
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
                  Center(
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
                          : const Icon(Icons.file_download),
                      label: const Text('Genera Report'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
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