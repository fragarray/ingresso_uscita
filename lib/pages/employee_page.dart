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
  double _gpsAccuracy = 0.0; // Accuratezza GPS in metri
  bool _hasGoodAccuracy = false; // Se l'accuratezza è accettabile
  AppState? _appState; // Riferimento salvato
  int _lastRefreshCounter = -1; // Traccia l'ultimo refresh processato

  @override
  void initState() {
    super.initState();
    _loadData();
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
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final currentCounter = _appState?.refreshCounter ?? -1;
    // Esegui refresh solo se il counter è cambiato
    if (currentCounter != _lastRefreshCounter && currentCounter >= 0) {
      debugPrint('=== EMPLOYEE PAGE: Refresh triggered (counter: $currentCounter) ===');
      _lastRefreshCounter = currentCounter;
      _loadData();
    }
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
      
      // Rimuovi duplicati basandosi sull'ID
      final Map<int, WorkSite> uniqueWorkSites = {};
      for (var ws in workSites.where((ws) => ws.isActive)) {
        if (ws.id != null) {
          uniqueWorkSites[ws.id!] = ws;
        }
      }
      
      setState(() {
        _workSites = uniqueWorkSites.values.toList();
      });
    } catch (e) {
      debugPrint('Error loading work sites: $e');
    }
  }

  Future<void> _loadLastRecord() async {
    // Salva il riferimento all'employee prima di operazioni async
    final employee = _appState?.currentEmployee;
    if (employee == null || !mounted) return;

    try {
      final records = await ApiService.getAttendanceRecords(employeeId: employee.id!);
      
      debugPrint('=== DEBUG LOAD LAST RECORD ===');
      debugPrint('Total records: ${records.length}');
      
      if (records.isNotEmpty) {
        debugPrint('First 3 records:');
        for (int i = 0; i < (records.length > 3 ? 3 : records.length); i++) {
          debugPrint('  [$i] type: ${records[i].type}, time: ${records[i].timestamp}, id: ${records[i].id}');
        }
        
        // I record arrivano in ordine DESC (più recente prima)
        final lastRecord = records.first;
        debugPrint('Last record type: ${lastRecord.type}');
        debugPrint('Last record timestamp: ${lastRecord.timestamp}');
        debugPrint('Last record workSiteId: ${lastRecord.workSiteId}');
        
        // Se l'ultimo record è 'in', significa che c'è un ingresso aperto
        final hasOpenClocking = lastRecord.type == 'in';
        WorkSite? lastWorkSite;
        
        if (hasOpenClocking && lastRecord.workSiteId != null && _workSites.isNotEmpty) {
          try {
            lastWorkSite = _workSites.firstWhere(
              (ws) => ws.id == lastRecord.workSiteId,
            );
            debugPrint('Found worksite: ${lastWorkSite.name}');
          } catch (e) {
            debugPrint('Cantiere non trovato: ${lastRecord.workSiteId}');
          }
        }
        
        if (mounted) {
          setState(() {
            _isClockedIn = hasOpenClocking;
            _recentRecords = records.take(5).toList();
            
            // Se c'è un ingresso aperto, seleziona il cantiere
            if (hasOpenClocking && lastWorkSite != null) {
              _selectedWorkSite = lastWorkSite;
              debugPrint('Setting selected worksite: ${lastWorkSite.name}');
            } else if (_selectedWorkSite == null && _workSites.isNotEmpty) {
              // Se non c'è un ingresso aperto, suggerisci il cantiere più vicino
              // (verrà fatto da _updateLocation)
              debugPrint('No open clocking, will suggest nearest worksite');
            }
          });
        }
        
        debugPrint('Final state - isClockedIn: $_isClockedIn');
        debugPrint('=== END DEBUG ===');
      } else {
        debugPrint('No records found for employee');
        if (mounted) {
          setState(() {
            _isClockedIn = false;
            _recentRecords = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading last record: $e');
    }
  }

  Future<void> _updateLocation() async {
    try {
      final location = await _getCurrentLocation();
      if (location != null && mounted) {
        // Calcola l'accuratezza GPS (accuracy è in metri)
        final accuracy = location.accuracy ?? 999.0;
        final accuracyPercentage = _calculateAccuracyPercentage(accuracy);
        final minRequired = _appState?.minGpsAccuracyPercent ?? 65.0;
        
        setState(() {
          _currentLocation = location;
          _gpsAccuracy = accuracy;
          _hasGoodAccuracy = accuracyPercentage >= minRequired;
        });
        
        debugPrint('GPS Accuracy: ${accuracy.toStringAsFixed(1)}m (${accuracyPercentage.toStringAsFixed(0)}%) - Required: ${minRequired.toInt()}%');
        
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
  
  /// Calcola la percentuale di accuratezza GPS
  /// 100% = 5 metri o meno
  /// 0% = 50 metri o più
  double _calculateAccuracyPercentage(double accuracy) {
    const double bestAccuracy = 5.0; // 5 metri = 100%
    const double worstAccuracy = 50.0; // 50 metri = 0%
    
    if (accuracy <= bestAccuracy) return 100.0;
    if (accuracy >= worstAccuracy) return 0.0;
    
    // Interpolazione lineare
    return 100.0 - ((accuracy - bestAccuracy) / (worstAccuracy - bestAccuracy) * 100.0);
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
    
      // Verifica accuratezza GPS
      if (!_hasGoodAccuracy && !Platform.isWindows && !kIsWeb) {
        final accuracyPercentage = _calculateAccuracyPercentage(_gpsAccuracy);
        final minRequired = _appState?.minGpsAccuracyPercent ?? 65.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Accuratezza GPS insufficiente (${accuracyPercentage.toStringAsFixed(0)}%).\n'
            'Richiesta: minimo ${minRequired.toInt()}%. Attendi un segnale GPS migliore.'
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // Salva riferimento employee prima di operazioni async
      final employee = _appState?.currentEmployee;
      if (employee == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final locationData = await _getCurrentLocation();
      if (locationData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile ottenere la posizione')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Verifica se la posizione è entro il raggio del cantiere (SEMPRE, sia IN che OUT)
      final isWithinRange = LocationService.isWithinWorkSite(locationData, _selectedWorkSite!);
      
      if (!isWithinRange && !Platform.isWindows && !kIsWeb) {
        if (!mounted) return;
        final distance = LocationService.calculateDistance(
          locationData.latitude!,
          locationData.longitude!,
          _selectedWorkSite!.latitude,
          _selectedWorkSite!.longitude,
        );
        
        // Messaggio diverso per IN e OUT
        final action = _isClockedIn ? 'uscita' : 'ingresso';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fuori dal cantiere!\n'
              'Sei a ${distance.toStringAsFixed(0)} metri dal cantiere.\n'
              'Devi essere entro ${_selectedWorkSite!.radiusMeters.toInt()} metri per timbrare $action.'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        
        setState(() => _isLoading = false);
        return;
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
      
      // Salva il tipo per il messaggio
      final recordType = record.type;

      final success = await ApiService.recordAttendance(record);
      
      if (success) {
        debugPrint('=== ATTENDANCE RECORDED ===');
        debugPrint('Record type sent: ${record.type}');
        debugPrint('Current _isClockedIn before reload: $_isClockedIn');
        
        // Piccolo delay per assicurarsi che il DB abbia processato l'insert
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Non invertire manualmente lo stato, lascia che _loadLastRecord lo calcoli dal server
        await _loadLastRecord();  // Ricarica i record e aggiorna lo stato
        
        debugPrint('Current _isClockedIn after reload: $_isClockedIn');
        debugPrint('=== END ATTENDANCE RECORDED ===');
        
        // Notifica l'admin page per aggiornare le presenze
        if (!mounted) return;
        _appState?.triggerRefresh();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(recordType == 'in' ? 
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
    final employee = _appState?.currentEmployee;
    
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
            onPressed: () {
              if (mounted) {
                _appState?.logout();
              }
            },
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
            // Indicatore Accuratezza GPS
            if (_currentLocation != null) Card(
              color: _hasGoodAccuracy ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasGoodAccuracy ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: _hasGoodAccuracy ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Segnale GPS',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Barra di progresso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _calculateAccuracyPercentage(_gpsAccuracy) / 100,
                        minHeight: 20,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _hasGoodAccuracy ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Precisione: ${_gpsAccuracy.toStringAsFixed(1)}m',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${_calculateAccuracyPercentage(_gpsAccuracy).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _hasGoodAccuracy ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (!_hasGoodAccuracy) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Consumer<AppState>(
                                builder: (context, appState, _) => Text(
                                  'Segnale GPS debole. Richiesto minimo ${appState.minGpsAccuracyPercent.toInt()}% per timbrare.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      value: _workSites.contains(_selectedWorkSite) ? _selectedWorkSite : null,
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
                      onChanged: _isClockedIn ? null : (value) {
                        // Se già timbrato IN, non permetti il cambio cantiere
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
                    if (_isClockedIn && _selectedWorkSite != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sei già timbrato presso questo cantiere. Timbra l\'uscita per cambiare cantiere.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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