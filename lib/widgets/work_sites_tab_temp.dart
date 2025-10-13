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
  
  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _showWorkSiteDetails(WorkSite workSite) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await ApiService.getWorkSiteDetails(workSite.id!);
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
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.location_on,
                color: workSite.isActive ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  workSite.name,
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
                Text(workSite.address),
                const SizedBox(height: 16),
                
                const Text(
                  'Coordinate:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Lat: ${workSite.latitude.toStringAsFixed(6)}'),
                Text('Lng: ${workSite.longitude.toStringAsFixed(6)}'),
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
                    onPressed: () => _confirmDeleteWorkSite(workSite),
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
                width: 80,
                height: 80,
                child: GestureDetector(
                  onLongPress: () => _showWorkSiteDetails(site),
                  child: Tooltip(
                    message: '${site.name}\nLong press per dettagli',
                    child: Icon(
                      Icons.location_on,
                      color: site.isActive ? Colors.green : Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              )).toList(),
            ),
            if (_isAddingWorkSite && _newWorkSitePosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _newWorkSitePosition!,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 40,
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
        if (!_isAddingWorkSite && _workSites.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 Long press su un marker per vedere i dettagli',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}