import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../services/qr_code_service.dart';

// Tipi di mappa disponibili
enum MapType {
  street,    // Mappa stradale (meno POI)
  satellite, // Vista satellitare ibrida (foto + nomi strade)
}

class WorkSitesTab extends StatefulWidget {
  const WorkSitesTab({Key? key}) : super(key: key);

  @override
  State<WorkSitesTab> createState() => _WorkSitesTabState();
}

class _WorkSitesTabState extends State<WorkSitesTab> {
  bool _isLoading = false;
  List<WorkSite> _workSites = [];
  final _mapController = MapController();
  bool _isAddingWorkSite = false;
  LatLng? _newWorkSitePosition;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  final _descriptionController = TextEditingController();
  final _addressSearchController = TextEditingController();
  bool _isSearchingAddress = false;
  MapType _currentMapType = MapType.street; // Tipo di mappa corrente
  
  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _descriptionController.dispose();
    _addressSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadWorkSites();
  }

  Future<void> _loadWorkSites() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sites = await ApiService.getWorkSites();
      if (!mounted) return;
      setState(() => _workSites = sites);
      
      // Centra la mappa sui cantieri dopo il caricamento
      if (sites.isNotEmpty) {
        _centerMapOnWorkSites();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il caricamento dei cantieri')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _centerMapOnWorkSites() {
    if (_workSites.isEmpty) return;

    // Calcola il centro medio di tutti i cantieri
    double totalLat = 0;
    double totalLng = 0;
    
    for (var site in _workSites) {
      totalLat += site.latitude;
      totalLng += site.longitude;
    }
    
    final centerLat = totalLat / _workSites.length;
    final centerLng = totalLng / _workSites.length;
    
    // Calcola la distanza massima dal centro per determinare lo zoom
    double maxDistance = 0;
    for (var site in _workSites) {
      final distance = _calculateDistance(
        centerLat,
        centerLng,
        site.latitude,
        site.longitude,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    
    // Determina il livello di zoom basato sulla distanza (con raggio target di 100km)
    double zoom;
    if (maxDistance < 10) {
      zoom = 11.0; // Molto vicini
    } else if (maxDistance < 25) {
      zoom = 10.0; // Vicini
    } else if (maxDistance < 50) {
      zoom = 9.0; // Raggio ~50km
    } else if (maxDistance < 100) {
      zoom = 8.0; // Raggio ~100km
    } else if (maxDistance < 200) {
      zoom = 7.0; // Raggio ~200km
    } else {
      zoom = 6.0; // Molto distanti
    }
    
    // Muove la mappa al centro calcolato con animazione
    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<String> _getAddressFromCoordinates(LatLng position) async {
    try {
      final result = await GeocodingService.reverseGeocode(position);
      if (result != null) {
        return result.displayName;
      }
      return 'Indirizzo non trovato';
    } catch (e) {
      return 'Errore nel recupero dell\'indirizzo';
    }
  }

  Future<void> _searchAndCenterAddress() async {
    final address = _addressSearchController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserire un indirizzo')),
      );
      return;
    }

    setState(() => _isSearchingAddress = true);

    try {
      final results = await GeocodingService.searchAddress(address);
      print('Locations found: ${results.length}');
      
      if (results.isNotEmpty) {
        final location = results.first;
        print('Latitude: ${location.latitude}, Longitude: ${location.longitude}');
        
        final position = location.position;
        print('LatLng created: $position');
        
        // Centra la mappa sull'indirizzo trovato con zoom massimo (18.0 - oltre diventa grigio)
        print('Attempting to move map...');
        _mapController.move(position, 18.0);
        print('Map moved successfully');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trovato: ${location.shortDescription}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indirizzo non trovato'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Errore geocoding: $e');
      print('StackTrace: $stackTrace');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella ricerca: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  // Ottieni URL del tile provider in base al tipo di mappa
  String _getTileUrl() {
    switch (_currentMapType) {
      case MapType.street:
        // CartoDB Positron (pulito, professionale, gratuito per uso commerciale)
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
      case MapType.satellite:
        // ESRI World Imagery (satellitare)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  // Ottieni URL overlay labels (solo per satellite)
  String? _getLabelsUrl() {
    if (_currentMapType == MapType.satellite) {
      // CartoDB labels only (overlay trasparente con solo nomi)
      return 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png';
    }
    return null;
  }

  // Ottieni nome visualizzato del tipo di mappa
  String _getMapTypeName() {
    switch (_currentMapType) {
      case MapType.street:
        return 'Stradale';
      case MapType.satellite:
        return 'Satellite';
    }
  }

  // Cambia tipo di mappa (toggle tra 2 tipi)
  void _cycleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.street 
        ? MapType.satellite 
        : MapType.street;
    });
  }

  Future<double?> _editWorkSiteRadiusDialog(WorkSite workSite) async {
    final radiusController = TextEditingController(text: workSite.radiusMeters.toInt().toString());
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.radar, color: Colors.orange),
            SizedBox(width: 8),
            Text('Modifica Raggio'),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Imposta il raggio di validità per le timbrature in questo cantiere.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Raggio (metri)',
                    suffixText: 'm',
                    prefixIcon: Icon(Icons.straighten),
                    border: OutlineInputBorder(),
                    helperText: 'Min: 10m - Max: 1000m',
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserire il raggio';
                    }
                    final radius = double.tryParse(value);
                    if (radius == null || radius < 10 || radius > 1000) {
                      return 'Valore tra 10 e 1000 metri';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newRadius = double.parse(radiusController.text);
                Navigator.pop(context, newRadius);
              }
            },
            child: const Text('SALVA'),
          ),
        ],
      ),
    );

    // Aspetta che l'animazione del dialog sia completata prima di dispose
    await Future.delayed(const Duration(milliseconds: 100));
    radiusController.dispose();

    if (result == null) return null;

    // Aggiorna il cantiere con il nuovo raggio in background
    final updatedWorkSite = WorkSite(
      id: workSite.id,
      name: workSite.name,
      latitude: workSite.latitude,
      longitude: workSite.longitude,
      address: workSite.address,
      isActive: workSite.isActive,
      radiusMeters: result,
      createdAt: workSite.createdAt,
    );

    // Esegui l'update in modo non bloccante
    ApiService.updateWorkSite(updatedWorkSite).then((success) {
      if (mounted && success) {
        _loadWorkSites();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Raggio aggiornato a ${result.toInt()} metri')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'aggiornamento')),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore di connessione')),
        );
      }
    });

    // Restituisci subito il nuovo valore per aggiornare l'UI
    return result;
  }

  Future<String?> _editWorkSiteNameDialog(String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('Modifica Nome'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Cantiere',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire un nome';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, nameController.text);
              }
            },
            child: const Text('SALVA'),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    nameController.dispose();
    return result;
  }

  Future<String?> _editWorkSiteDescriptionDialog(String? currentDescription) async {
    final descriptionController = TextEditingController(text: currentDescription ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description, color: Colors.purple),
            SizedBox(width: 8),
            Text('Modifica Descrizione'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Descrizione visibile ai dipendenti nelle card dei cantieri.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  prefixIcon: Icon(Icons.text_fields),
                  border: OutlineInputBorder(),
                  helperText: 'Lascia vuoto per rimuovere',
                ),
                maxLines: 4,
                maxLength: 200,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = descriptionController.text.trim();
              Navigator.pop(context, text.isEmpty ? null : text);
            },
            child: const Text('SALVA'),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    descriptionController.dispose();
    return result;
  }

  Future<void> _showWorkSiteDetails(WorkSite workSite) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ricarica i dati del cantiere dal server per avere valori aggiornati
      final updatedWorkSites = await ApiService.getWorkSites();
      final freshWorkSite = updatedWorkSites.firstWhere(
        (ws) => ws.id == workSite.id,
        orElse: () => workSite,
      );
      
      final details = await ApiService.getWorkSiteDetails(freshWorkSite.id!);
      if (!mounted) return;
      
      Navigator.pop(context);

      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel caricamento dei dettagli')),
        );
        return;
      }

      final currentEmployees = details['currentEmployees'] as List<dynamic>? ?? [];
      final employeesCount = details['currentEmployeesCount'] ?? 0;

      if (!mounted) return;
      
      // Usa il raggio dal cantiere aggiornato
      double currentRadius = freshWorkSite.radiusMeters;
      String currentName = freshWorkSite.name;
      String? currentDescription = freshWorkSite.description;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: freshWorkSite.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentName,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await _editWorkSiteNameDialog(currentName);
                    if (result != null && result != currentName) {
                      // Aggiorna il nome sul server
                      final updatedWorkSite = WorkSite(
                        id: freshWorkSite.id,
                        name: result,
                        latitude: freshWorkSite.latitude,
                        longitude: freshWorkSite.longitude,
                        address: freshWorkSite.address,
                        isActive: freshWorkSite.isActive,
                        radiusMeters: currentRadius,
                        description: currentDescription,
                        createdAt: freshWorkSite.createdAt,
                      );
                      
                      final success = await ApiService.updateWorkSite(updatedWorkSite);
                      if (success && mounted) {
                        setState(() {
                          currentName = result;
                        });
                        _loadWorkSites();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nome aggiornato')),
                        );
                      }
                    }
                  },
                  tooltip: 'Modifica nome',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indirizzo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(freshWorkSite.address),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Coordinate:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('Lat: ${freshWorkSite.latitude.toStringAsFixed(6)}'),
                  Text('Lng: ${freshWorkSite.longitude.toStringAsFixed(6)}'),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      const Icon(Icons.radar, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Raggio: ${currentRadius.toInt()} metri',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final newRadius = await _editWorkSiteRadiusDialog(workSite);
                          if (newRadius != null) {
                            setState(() {
                              currentRadius = newRadius;
                            });
                          }
                        },
                        tooltip: 'Modifica raggio',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Descrizione cantiere
                  Row(
                    children: [
                      const Icon(Icons.description, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Descrizione:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final result = await _editWorkSiteDescriptionDialog(currentDescription);
                          if (result != currentDescription) {
                            // Aggiorna la descrizione sul server
                            final updatedWorkSite = WorkSite(
                              id: freshWorkSite.id,
                              name: currentName,
                              latitude: freshWorkSite.latitude,
                              longitude: freshWorkSite.longitude,
                              address: freshWorkSite.address,
                              isActive: freshWorkSite.isActive,
                              radiusMeters: currentRadius,
                              description: result,
                              createdAt: freshWorkSite.createdAt,
                            );
                            
                            final success = await ApiService.updateWorkSite(updatedWorkSite);
                            if (success && mounted) {
                              setState(() {
                                currentDescription = result;
                              });
                              _loadWorkSites();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Descrizione aggiornata')),
                              );
                            }
                          }
                        },
                        tooltip: 'Modifica descrizione',
                      ),
                    ],
                  ),
                  if (currentDescription != null && currentDescription!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!, width: 1),
                      ),
                      child: Text(
                        currentDescription!,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'Nessuna descrizione',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Dipendenti presenti: $employeesCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                
                if (currentEmployees.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: currentEmployees.map((emp) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(emp['name']),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Pulsante QR Code
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showQRCode(freshWorkSite),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('GENERA QR CODE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDeleteWorkSite(freshWorkSite),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('ELIMINA CANTIERE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _showQRCode(WorkSite workSite) async {
    try {
      // Ottieni informazioni server dalle SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('serverIp') ?? ApiService.getDefaultServerIp();
      final serverPort = prefs.getInt('serverPort') ?? ApiService.getDefaultServerPort();

      // Chiudi il dialog corrente
      Navigator.pop(context);

      // Mostra il QR code dialog
      QRCodeService().showQRDialog(
        context: context,
        workSite: workSite,
        serverHost: serverIp,
        serverPort: serverPort,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore generazione QR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteWorkSite(WorkSite workSite) async {
    Navigator.pop(context);
    
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
          'Stai per eliminare il cantiere "${workSite.name}".\n\n'
          'Questa azione non può essere annullata, ma verrà creato automaticamente '
          'un backup Excel dello storico completo del cantiere.\n\n'
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
          '• Cantiere: ${workSite.name}\n'
          '• Indirizzo: ${workSite.address}\n\n'
          'Il backup Excel verrà salvato automaticamente.\n\n'
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generazione backup e eliminazione in corso...'),
          ],
        ),
      ),
    );

    try {
      final success = await ApiService.deleteWorkSite(workSite.id!);
      
      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cantiere "${workSite.name}" eliminato.\nBackup salvato in server/reports/'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        _loadWorkSites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'eliminazione del cantiere'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  void _showSaveWorkSiteDialog() async {
    if (_newWorkSitePosition == null) return;

    final address = await _getAddressFromCoordinates(_newWorkSitePosition!);
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo Cantiere'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Cantiere',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserire un nome per il cantiere';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione (opzionale)',
                    prefixIcon: Icon(Icons.description),
                    helperText: 'Info aggiuntive visibili ai dipendenti',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Raggio validità (metri)',
                    helperText: 'Distanza massima per timbrature valide',
                    prefixIcon: Icon(Icons.radar),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserire il raggio';
                    }
                    final radius = double.tryParse(value);
                    if (radius == null || radius < 10 || radius > 1000) {
                      return 'Inserire un valore tra 10 e 1000 metri';
                    }
                    return null;
                  },
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
                          Icon(Icons.place, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Indirizzo:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.gps_fixed, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Coordinate:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_newWorkSitePosition!.latitude.toStringAsFixed(6)}\n'
                        'Lng: ${_newWorkSitePosition!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isAddingWorkSite = false;
                _newWorkSitePosition = null;
              });
              _nameController.clear();
              _descriptionController.clear();
            },
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final newWorkSite = WorkSite(
                  name: _nameController.text,
                  latitude: _newWorkSitePosition!.latitude,
                  longitude: _newWorkSitePosition!.longitude,
                  address: address,
                  radiusMeters: double.parse(_radiusController.text),
                  description: _descriptionController.text.isNotEmpty 
                      ? _descriptionController.text 
                      : null,
                );

                try {
                  await ApiService.addWorkSite(newWorkSite);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadWorkSites();
                  setState(() {
                    _isAddingWorkSite = false;
                    _newWorkSitePosition = null;
                  });
                  _nameController.clear();
                  _descriptionController.clear();
                  _radiusController.text = '100';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cantiere aggiunto con successo')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Errore durante il salvataggio del cantiere')),
                  );
                }
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(41.9028, 12.4964),
            initialZoom: 6.0,
            minZoom: 3.0,
            maxZoom: 18.0, // Oltre questo livello le tiles diventano grigie
            onTap: _isAddingWorkSite ? (_, point) {
              setState(() => _newWorkSitePosition = point);
            } : null,
          ),
          children: [
            // Layer base (stradale o satellite)
            TileLayer(
              urlTemplate: _getTileUrl(),
              userAgentPackageName: 'com.example.app',
              subdomains: _currentMapType == MapType.satellite 
                ? const [] // Satellite non usa subdomains
                : const ['a', 'b', 'c'],
              maxZoom: 19,
              keepBuffer: 5,
              tileProvider: NetworkTileProvider(),
            ),
            // Overlay nomi strade (solo su satellite)
            if (_currentMapType == MapType.satellite)
              TileLayer(
                urlTemplate: _getLabelsUrl(),
                userAgentPackageName: 'com.example.app',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 19,
                keepBuffer: 5,
                tileProvider: NetworkTileProvider(),
              ),
            // Marker cantieri
            MarkerLayer(
              markers: _workSites.map((site) => Marker(
                point: LatLng(site.latitude, site.longitude),
                width: 60,
                height: 60,
                child: _WorkSiteMarker(
                  workSite: site,
                  onTap: () => _showWorkSiteDetails(site),
                ),
              )).toList(),
            ),
            if (_isAddingWorkSite && _newWorkSitePosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _newWorkSitePosition!,
                    width: 60,
                    height: 60,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.construction,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        // Barra di ricerca indirizzo (funziona su tutte le piattaforme)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Cerca indirizzo...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _searchAndCenterAddress(),
                    ),
                  ),
                  if (_isSearchingAddress)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.navigation),
                      onPressed: _searchAndCenterAddress,
                      tooltip: 'Vai all\'indirizzo',
                    ),
                ],
            ),
          ),
        ),
        ),
        // Pulsanti Zoom e Cambio Mappa (sinistra)
        Positioned(
          left: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsante cambio tipo mappa
              FloatingActionButton.small(
                heroTag: 'change_map',
                onPressed: _cycleMapType,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                tooltip: _getMapTypeName(),
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 16), // Spazio maggiore tra cambio mappa e zoom
              FloatingActionButton.small(
                heroTag: 'zoom_in',
                onPressed: _zoomIn,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoom_out',
                onPressed: _zoomOut,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        // Pulsanti azioni cantiere (destra)
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isAddingWorkSite && _newWorkSitePosition != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: FloatingActionButton(
                    onPressed: _showSaveWorkSiteDialog,
                    backgroundColor: Colors.green,
                    heroTag: 'save_worksite',
                    child: const Icon(Icons.save),
                  ),
                ),
              FloatingActionButton(
                heroTag: 'toggle_adding',
                onPressed: () {
                  setState(() {
                    if (_isAddingWorkSite) {
                      _isAddingWorkSite = false;
                      _newWorkSitePosition = null;
                    } else {
                      _isAddingWorkSite = true;
                    }
                  });
                },
                backgroundColor: _isAddingWorkSite ? Colors.red : null,
                child: Icon(_isAddingWorkSite ? Icons.close : Icons.add_location),
              ),
            ],
          ),
        ),
        if (_isAddingWorkSite)
          Positioned(
            top: 80, // Spostato più in basso per non sovrapporsi alla barra di ricerca
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tocca un punto sulla mappa per posizionare il cantiere.\n'
                  'Usa il pulsante verde per salvare o quello rosso per annullare.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        
      ],
    );
  }
}

// Widget personalizzato per il marker del cantiere con animazione
class _WorkSiteMarker extends StatefulWidget {
  final WorkSite workSite;
  final VoidCallback onTap;

  const _WorkSiteMarker({
    required this.workSite,
    required this.onTap,
  });

  @override
  State<_WorkSiteMarker> createState() => _WorkSiteMarkerState();
}

class _WorkSiteMarkerState extends State<_WorkSiteMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isPressed
                        ? (widget.workSite.isActive
                                ? Colors.orange
                                : Colors.grey)
                            .withOpacity(0.6)
                        : Colors.black.withOpacity(0.25),
                    blurRadius: _isPressed ? 8 : 4,
                    spreadRadius: _isPressed ? 2 : 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.construction,
                color: widget.workSite.isActive ? Colors.orange : Colors.grey,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}