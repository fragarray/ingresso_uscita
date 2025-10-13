import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/attendance_record.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'dart:io';
import '../main.dart';

class EmployeePage extends StatefulWidget {
  @override
  _EmployeePageState createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  LocationData? _currentLocation;
  bool _isClockedIn = false;
  bool _isLoading = false;
  List<AttendanceRecord> _recentRecords = [];
  List<WorkSite> _workSites = [];
  WorkSite? _selectedWorkSite;
  String? _distanceInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadWorkSites();
    await _loadLastRecord();
    await _updateLocation();
  }

  Future<void> _loadWorkSites() async {
    try {
      final workSites = await ApiService.getWorkSites();
      if (!mounted) return;
      setState(() {
        _workSites = workSites.where((ws) => ws.isActive).toList();
      });
    } catch (e) {
      debugPrint('Error loading work sites: $e');
    }
  }

  Future<void> _loadLastRecord() async {
    final employee = context.read<AppState>().currentEmployee;
    if (employee == null) return;

    final records = await ApiService.getAttendanceRecords(employeeId: employee.id!);
    if (records.isNotEmpty) {
      setState(() {
        _isClockedIn = records.first.type == 'in';
        _recentRecords = records.take(5).toList();
        
        // Se l'ultimo record ha un cantiere, selezionalo
        if (records.first.workSiteId != null && _workSites.isNotEmpty) {
          try {
            _selectedWorkSite = _workSites.firstWhere(
              (ws) => ws.id == records.first.workSiteId,
            );
          } catch (e) {
            // Cantiere non trovato, usa il primo disponibile
            _selectedWorkSite = _workSites.first;
          }
        }
      });
    }
  }

  Future<void> _updateLocation() async {
    try {
      final location = await _getCurrentLocation();
      if (location != null && mounted) {
        setState(() {
          _currentLocation = location;
        });
        
        // Suggerisci il cantiere più vicino se non ne è selezionato uno
        if (_selectedWorkSite == null && _workSites.isNotEmpty) {
          final nearest = LocationService.findNearestWorkSite(location, _workSites);
          if (nearest != null) {
            setState(() {
              _selectedWorkSite = nearest;
            });
          }
        }
        
        // Aggiorna info distanza
        if (_selectedWorkSite != null) {
          setState(() {
            _distanceInfo = LocationService.getDistanceDescription(location, _selectedWorkSite!);
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<LocationData?> _getCurrentLocation() async {
    return LocationService.getCurrentLocation();
  }

  Future<void> _clockInOut() async {
    if (_isLoading) return;
    
    // Verifica che sia selezionato un cantiere
    if (_selectedWorkSite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un cantiere prima di timbrare')),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final employee = context.read<AppState>().currentEmployee;
      if (employee == null) return;

      final locationData = await _getCurrentLocation();
      if (locationData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile ottenere la posizione')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Verifica se la posizione è entro il raggio del cantiere
      final isWithinRange = LocationService.isWithinWorkSite(locationData, _selectedWorkSite!);
      
      if (!isWithinRange && !Platform.isWindows && !kIsWeb) {
        if (!mounted) return;
        final distance = LocationService.calculateDistance(
          locationData.latitude!,
          locationData.longitude!,
          _selectedWorkSite!.latitude,
          _selectedWorkSite!.longitude,
        );
        
        // Mostra dialog di conferma se fuori range
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fuori dal raggio del cantiere'),
            content: Text(
              'Sei a ${distance.toStringAsFixed(0)} metri dal cantiere selezionato.\n'
              'Il raggio massimo consentito è ${LocationService.maxDistanceMeters} metri.\n\n'
              'Vuoi comunque registrare la timbratura?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continua'),
              ),
            ],
          ),
        );
        
        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final record = AttendanceRecord(
        employeeId: employee.id!,
        workSiteId: _selectedWorkSite!.id,
        timestamp: DateTime.now(),
        type: _isClockedIn ? 'out' : 'in',
        deviceInfo: '${Platform.operatingSystem} - ${Platform.operatingSystemVersion}',
        latitude: locationData.latitude ?? 0.0,
        longitude: locationData.longitude ?? 0.0,
      );

      final success = await ApiService.recordAttendance(record);
      
      if (success) {
        setState(() {
          _isClockedIn = !_isClockedIn;
        });
        
        await _loadLastRecord();  // Ricarica i record recenti
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isClockedIn ? 
            'Timbratura ingresso registrata' : 'Timbratura uscita registrata')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la registrazione')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = context.read<AppState>().currentEmployee;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Dipendente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateLocation,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Benvenuto ${employee?.name}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isClockedIn ? 'Sei timbrato IN' : 'Sei timbrato OUT',
                      style: TextStyle(
                        fontSize: 20,
                        color: _isClockedIn ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Selezione Cantiere
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleziona Cantiere',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WorkSite>(
                      value: _selectedWorkSite,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        hintText: 'Scegli un cantiere',
                      ),
                      items: _workSites.map((workSite) {
                        return DropdownMenuItem<WorkSite>(
                          value: workSite,
                          child: Text(workSite.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWorkSite = value;
                          if (value != null && _currentLocation != null) {
                            _distanceInfo = LocationService.getDistanceDescription(
                              _currentLocation!,
                              value,
                            );
                          }
                        });
                      },
                    ),
                    if (_distanceInfo != null && _selectedWorkSite != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            LocationService.isWithinWorkSite(
                              _currentLocation ?? LocationData.fromMap({}),
                              _selectedWorkSite!,
                            ) ? Icons.check_circle : Icons.warning,
                            color: LocationService.isWithinWorkSite(
                              _currentLocation ?? LocationData.fromMap({}),
                              _selectedWorkSite!,
                            ) ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _distanceInfo!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _clockInOut,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: _isClockedIn ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isClockedIn ? 'TIMBRA USCITA' : 'TIMBRA INGRESSO',
                    style: const TextStyle(fontSize: 18),
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ultime Timbrature:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _recentRecords.length,
                itemBuilder: (context, index) {
                  final record = _recentRecords[index];
                  final workSite = record.workSiteId != null
                      ? _workSites.firstWhere(
                          (ws) => ws.id == record.workSiteId,
                          orElse: () => WorkSite(
                            name: 'Sconosciuto',
                            latitude: 0,
                            longitude: 0,
                            address: '',
                          ),
                        )
                      : null;
                  
                  return ListTile(
                    leading: Icon(
                      record.type == 'in' ? Icons.login : Icons.logout,
                      color: record.type == 'in' ? Colors.green : Colors.red,
                    ),
                    title: Text(record.type == 'in' ? 'Ingresso' : 'Uscita'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.timestamp.toLocal().toString().split('.')[0],
                        ),
                        if (workSite != null)
                          Text(
                            'Cantiere: ${workSite.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}