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
  List<WorkSite> _workSites = [];
  WorkSite? _selectedWorkSite;
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

  /// Determina il colore del cantiere in base allo stato e alla distanza
  Color _getWorkSiteColor(WorkSite workSite) {
    if (_isClockedIn) {
      // Dipendente timbrato IN
      if (_selectedWorkSite?.id == workSite.id) {
        return Colors.yellow[700]!; // Cantiere corrente in giallo
      }
      return Colors.red[400]!; // Altri cantieri in rosso
    } else {
      // Dipendente OUT - verifica se è timbrabile (dentro il raggio)
      if (_currentLocation != null) {
        // Verifica se questo cantiere è dentro il raggio
        final isWithinRange = LocationService.isWithinWorkSite(_currentLocation!, workSite);
        
        if (isWithinRange) {
          // Cantiere TIMBRABILE - verde acceso
          return Colors.green[700]!;
        } else {
          // In modalità debug (Windows/Web), evidenzia il cantiere più vicino
          // anche se fuori dal raggio, per facilitare i test
          if (Platform.isWindows || kIsWeb) {
            final nearest = LocationService.findNearestWorkSite(_currentLocation!, _workSites);
            if (nearest?.id == workSite.id) {
              // Cantiere PIÙ VICINO in debug - verde brillante
              return Colors.green[600]!;
            }
          }
          // Cantiere NON TIMBRABILE - grigio scuro
          return Colors.grey[600]!;
        }
      }
      // Fallback: se non c'è GPS, mostra in grigio scuro
      return Colors.grey[600]!;
    }
  }

  /// Mostra dialog di conferma e gestisce la timbratura
  Future<void> _handleWorkSiteTap(WorkSite workSite) async {
    if (_isLoading) return;

    // Se timbrato IN, permetti solo tap sul cantiere corrente
    if (_isClockedIn && _selectedWorkSite?.id != workSite.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sei già timbrato presso ${_selectedWorkSite?.name}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Imposta il cantiere selezionato
    setState(() {
      _selectedWorkSite = workSite;
    });

    // Verifica accuratezza GPS
    if (!_hasGoodAccuracy && !Platform.isWindows && !kIsWeb) {
      final accuracyPercentage = _calculateAccuracyPercentage(_gpsAccuracy);
      final minRequired = _appState?.minGpsAccuracyPercent ?? 65.0;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gps_off, color: Colors.red, size: 30),
              SizedBox(width: 12),
              Text('GPS Insufficiente'),
            ],
          ),
          content: Text(
            'Accuratezza GPS attuale: ${accuracyPercentage.toStringAsFixed(0)}%\n'
            'Richiesta: minimo ${minRequired.toInt()}%\n\n'
            'Attendi un segnale GPS migliore prima di timbrare.',
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

    // Verifica posizione (sempre, sia IN che OUT)
    if (_currentLocation != null) {
      final isWithinRange = LocationService.isWithinWorkSite(_currentLocation!, workSite);
      
      if (!isWithinRange && !Platform.isWindows && !kIsWeb) {
        final distance = LocationService.calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          workSite.latitude,
          workSite.longitude,
        );
        
        final action = _isClockedIn ? 'uscita' : 'ingresso';
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.location_off, color: Colors.red, size: 30),
                SizedBox(width: 12),
                Text('Fuori dal Cantiere'),
              ],
            ),
            content: Text(
              'Sei a ${distance.toStringAsFixed(0)} metri dal cantiere.\n\n'
              'Devi essere entro ${workSite.radiusMeters.toInt()} metri '
              'per timbrare $action.',
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

    // Mostra dialog di conferma
    final action = _isClockedIn ? 'USCITA' : 'INGRESSO';
    final actionColor = _isClockedIn ? Colors.red : Colors.green;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _isClockedIn ? Icons.logout : Icons.login,
              color: actionColor,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Conferma $action',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stai per timbrare $action presso:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: actionColor, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: actionColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      workSite.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: actionColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Confermi la timbratura?',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            child: Text('CONFERMA $action'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clockInOut();
    }
  }

  // Mostra informazioni dettagliate del cantiere (long press)
  void _showWorkSiteInfo(WorkSite workSite) {
    String? distanceText;
    if (_currentLocation != null) {
      final distance = LocationService.calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        workSite.latitude,
        workSite.longitude,
      );
      distanceText = distance < 1000
          ? '${distance.toStringAsFixed(0)} metri'
          : '${(distance / 1000).toStringAsFixed(2)} km';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_city_rounded,
              color: _getWorkSiteColor(workSite),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                workSite.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indirizzo
              const Row(
                children: [
                  Icon(Icons.place_rounded, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Indirizzo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  workSite.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Coordinate
              const Row(
                children: [
                  Icon(Icons.gps_fixed, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Coordinate GPS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lat: ${workSite.latitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'Lng: ${workSite.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Distanza
              if (distanceText != null) ...[
                const Row(
                  children: [
                    Icon(Icons.navigation_rounded, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Distanza',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    distanceText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Descrizione
              if (workSite.description != null && workSite.description!.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.description_rounded, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Descrizione',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.purple[200]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    workSite.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Raggio validità
              const Row(
                children: [
                  Icon(Icons.radar, size: 18, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text(
                    'Raggio Validità',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  '${workSite.radiusMeters.toInt()} metri',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CHIUDI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = _appState?.currentEmployee;
    final accuracyPercentage = _calculateAccuracyPercentage(_gpsAccuracy);
    
    // Determina colore pallino GPS
    Color gpsIndicatorColor;
    if (accuracyPercentage >= 80) {
      gpsIndicatorColor = Colors.green;
    } else if (accuracyPercentage >= 50) {
      gpsIndicatorColor = Colors.yellow[700]!;
    } else {
      gpsIndicatorColor = Colors.red;
    }
    
    // Determina numero di colonne in base alla larghezza schermo
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    
    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 1.5; // Ridotto per più altezza
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
      childAspectRatio = 1.3; // Ridotto per più altezza
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.0; // Ridotto per più altezza
    } else {
      // Mobile - aspect ratio RIDOTTO per card PIÙ ALTE
      crossAxisCount = 1;
      childAspectRatio = 1.4; // Ridotto per più altezza
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee?.name ?? 'Dipendente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[900]),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isClockedIn ? Colors.green[400] : Colors.red[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isClockedIn ? 'IN' : 'OUT',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isClockedIn ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Indicatore GPS compatto e moderno
          if (_currentLocation != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: gpsIndicatorColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gpsIndicatorColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    size: 14,
                    color: gpsIndicatorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${accuracyPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gpsIndicatorColor,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 22, color: Colors.grey[700]),
            tooltip: 'Aggiorna posizione',
            onPressed: _updateLocation,
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, size: 22, color: Colors.grey[700]),
            tooltip: 'Esci',
            onPressed: () async {
              if (mounted) {
                await _appState?.logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Timbratura in corso...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _workSites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nessun cantiere disponibile',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Banner istruzioni moderno
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isClockedIn
                              ? [Colors.green[400]!, Colors.green[600]!]
                              : [Colors.blue[400]!, Colors.blue[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_isClockedIn ? Colors.green : Colors.blue)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isClockedIn ? Icons.touch_app_rounded : Icons.info_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _isClockedIn
                                  ? 'Tocca il cantiere evidenziato per timbrare l\'uscita'
                                  : 'Tocca un cantiere per timbrare l\'ingresso \nTieni premuto per leggere i dettagli del cantiere',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Griglia cantieri moderna tipo desktop / Lista su mobile
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: screenWidth < 600
                            ? _buildMobileListView() // Lista adattiva su mobile
                            : _buildGridView(crossAxisCount, childAspectRatio), // Griglia su tablet/desktop
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Build ListView per mobile - card si adattano al contenuto
  Widget _buildMobileListView() {
    // Ordina i cantieri per distanza
    final sortedWorkSites = List<WorkSite>.from(_workSites);
    if (_currentLocation != null) {
      sortedWorkSites.sort((a, b) {
        final distanceA = LocationService.calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          a.latitude,
          a.longitude,
        );
        final distanceB = LocationService.calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: sortedWorkSites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final workSite = sortedWorkSites[index];
        return _buildWorkSiteCard(workSite, 1.0);
      },
    );
  }

  /// Build GridView per tablet/desktop
  Widget _buildGridView(int crossAxisCount, double childAspectRatio) {
    // Ordina i cantieri per distanza
    final sortedWorkSites = List<WorkSite>.from(_workSites);
    if (_currentLocation != null) {
      sortedWorkSites.sort((a, b) {
        final distanceA = LocationService.calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          a.latitude,
          a.longitude,
        );
        final distanceB = LocationService.calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: sortedWorkSites.length,
      itemBuilder: (context, index) {
        final workSite = sortedWorkSites[index];
        final screenWidth = MediaQuery.of(context).size.width;
        double textScaleFactor;
        if (screenWidth > 1200) {
          textScaleFactor = 1.1;
        } else if (screenWidth > 900) {
          textScaleFactor = 1.05;
        } else {
          textScaleFactor = 1.0;
        }
        return _buildWorkSiteCard(workSite, textScaleFactor);
      },
    );
  }

  /// Build singola card cantiere
  Widget _buildWorkSiteCard(WorkSite workSite, double textScaleFactor) {
    final color = _getWorkSiteColor(workSite);
    final isCurrentSite = _isClockedIn && _selectedWorkSite?.id == workSite.id;
    
    // Calcola distanza
    String? distanceText;
    if (_currentLocation != null) {
      final distance = LocationService.calculateDistance(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
        workSite.latitude,
        workSite.longitude,
      );
      distanceText = distance < 1000
          ? '${distance.toStringAsFixed(0)}m'
          : '${(distance / 1000).toStringAsFixed(1)}km';
    }
    
    return GestureDetector(
      onTap: () => _handleWorkSiteTap(workSite),
      onLongPress: () => _showWorkSiteInfo(workSite),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isCurrentSite ? color : color.withOpacity(0.3),
            width: isCurrentSite ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isCurrentSite ? 0.35 : 0.12),
              blurRadius: isCurrentSite ? 20 : 10,
              spreadRadius: isCurrentSite ? 1 : 0,
              offset: Offset(0, isCurrentSite ? 8 : 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenuto principale
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: IntrinsicHeight( // Adatta altezza al contenuto
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SINISTRA: Icona + Info cantiere
                    Expanded(
                      flex: workSite.description != null && workSite.description!.isNotEmpty ? 5 : 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icona
                          Container(
                            width: 48 * textScaleFactor,
                            height: 48 * textScaleFactor,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.8),
                                  color,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_city_rounded,
                              size: 26 * textScaleFactor,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Nome cantiere
                          Text(
                            workSite.name,
                            style: TextStyle(
                              fontSize: 15 * textScaleFactor,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                              height: 1.2,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          
                          // Indirizzo
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 14 * textScaleFactor,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  workSite.address,
                                  style: TextStyle(
                                    fontSize: 11 * textScaleFactor,
                                    color: Colors.grey[700],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          
                          // Coordinate GPS
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                size: 13 * textScaleFactor,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${workSite.latitude.toStringAsFixed(4)}, ${workSite.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 10 * textScaleFactor,
                                    color: Colors.grey[600],
                                    fontFamily: 'monospace',
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          // Badge distanza
                          if (distanceText != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * textScaleFactor,
                                vertical: 4 * textScaleFactor,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withOpacity(0.12),
                                    color.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: color.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.navigation_rounded,
                                    size: 12 * textScaleFactor,
                                    color: color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontSize: 11 * textScaleFactor,
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // DESTRA: Descrizione (se presente)
                    if (workSite.description != null && workSite.description!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.10),
                                color.withOpacity(0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14 * textScaleFactor,
                                    color: color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Info',
                                    style: TextStyle(
                                      fontSize: 11 * textScaleFactor,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Flexible(
                                child: Text(
                                  workSite.description!,
                                  style: TextStyle(
                                    fontSize: 11 * textScaleFactor,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Badge "QUI"
            if (isCurrentSite)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'QUI',
                    style: TextStyle(
                      fontSize: 11 * textScaleFactor,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}