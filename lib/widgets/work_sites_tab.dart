import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../models/work_site.dart';
import '../services/api_service.dart';

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
  
  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
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
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
      return 'Indirizzo non trovato';
    } catch (e) {
      return 'Errore nel recupero dell\'indirizzo';
    }
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
                    freshWorkSite.name,
                    style: const TextStyle(fontSize: 20),
                  ),
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
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome Cantiere'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire un nome per il cantiere';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              Text('Indirizzo: $address', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                'Coordinate: ${_newWorkSitePosition!.latitude.toStringAsFixed(6)}, ${_newWorkSitePosition!.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
            onTap: _isAddingWorkSite ? (_, point) {
              setState(() => _newWorkSitePosition = point);
            } : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
              subdomains: const ['a', 'b', 'c'],
              maxZoom: 19,
              keepBuffer: 5,
              tileProvider: NetworkTileProvider(),
            ),
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
            top: 16,
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