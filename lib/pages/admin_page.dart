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
      length: 4,
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
              Tab(icon: Icon(Icons.access_time), text: 'Presenze Oggi'),
              Tab(icon: Icon(Icons.location_city), text: 'Cantieri'),
              Tab(icon: Icon(Icons.assessment), text: 'Report'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PersonnelTab(),
            TodayAttendanceTab(),
            WorkSitesTab(),
            ReportsTab(),
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

class _TodayAttendanceTabState extends State<TodayAttendanceTab> {
  bool _isLoading = false;
  List<Employee> _employees = [];
  List<AttendanceRecord> _todayAttendance = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      final attendance = await ApiService.getAttendanceRecords();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (!mounted) return;
      
      setState(() {
        _employees = employees;
        _todayAttendance = attendance.where((record) {
          final recordDate = DateTime(
            record.timestamp.year,
            record.timestamp.month,
            record.timestamp.day,
          );
          return recordDate.isAtSameMomentAs(today);
        }).toList();
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

  @override
  Widget build(BuildContext context) {
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