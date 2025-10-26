import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../models/server_instance.dart';
import '../providers/server_provider.dart';

class AddServerScreen extends StatefulWidget {
  const AddServerScreen({Key? key}) : super(key: key);

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _portController = TextEditingController();
  
  bool _isLoading = false;

  // Percorso del server.js integrato nell'applicazione
  static const String _integratedServerPath = '/home/tom/ingrARM/ingresso_uscita/serverUI/server/server.js';
  static const String _templateDatabasePath = '/home/tom/ingrARM/ingresso_uscita/serverUI/server/database.db';

  @override
  void initState() {
    super.initState();
    // Trova una porta disponibile di default
    _findAvailablePort();
    // Imposta un nome di default
    _nameController.text = 'Server Ingresso/Uscita';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _findAvailablePort() async {
    int port = 3000;
    while (port < 4000) {
      try {
        final socket = await ServerSocket.bind('localhost', port);
        await socket.close();
        _portController.text = port.toString();
        break;
      } catch (e) {
        port++;
      }
    }
  }

  /// Crea una cartella dedicata per il server nella home dell'utente
  /// e copia il database template
  Future<String> _createServerDirectory(String serverName) async {
    // Ottieni la directory home dell'utente
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/home/tom';
    
    // Crea un nome sicuro per la cartella (rimuovi caratteri speciali)
    final safeName = serverName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    
    // Percorso della cartella del server
    final serverDir = path.join(homeDir, 'IngressoUscita_Servers', safeName);
    
    // Crea la directory se non esiste
    final directory = Directory(serverDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    
    // Percorso del database per questo server
    final dbPath = path.join(serverDir, 'database.db');
    
    // Copia il database template se non esiste
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      final templateDb = File(_templateDatabasePath);
      if (templateDb.existsSync()) {
        await templateDb.copy(dbPath);
      } else {
        // Crea un database vuoto se il template non esiste
        dbFile.createSync();
      }
    }
    
    return dbPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Nuovo Server'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configurazione Server',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      
                      // Nome del server
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Server',
                          hintText: 'Es: Server Produzione',
                          prefixIcon: Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Il nome del server è obbligatorio';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Porta
                      TextFormField(
                        controller: _portController,
                        decoration: InputDecoration(
                          labelText: 'Porta',
                          hintText: '3000',
                          prefixIcon: const Icon(Icons.network_ping),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _findAvailablePort,
                            tooltip: 'Trova porta disponibile',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La porta è obbligatoria';
                          }
                          
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Inserisci una porta valida (1-65535)';
                          }
                          
                          // Controlla se la porta è già utilizzata da un altro server
                          final provider = context.read<ServerProvider>();
                          final existingServer = provider.servers.any((s) => s.port == port);
                          if (existingServer) {
                            return 'Porta già utilizzata da un altro server';
                          }
                          
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Il server verrà creato automaticamente con:',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '• Server integrato nell\'applicazione\n'
                                    '• Database dedicato in ~/IngressoUscita_Servers/\n'
                                    '• Dipendenze npm auto-installate',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Pulsanti
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveServer,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crea Server'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serverName = _nameController.text.trim();
      final port = int.parse(_portController.text.trim());
      
      // Crea la cartella dedicata e ottieni il percorso del database
      final databasePath = await _createServerDirectory(serverName);
      
      // Crea l'istanza del server
      final server = ServerInstance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: serverName,
        port: port,
        databasePath: databasePath,
        serverPath: _integratedServerPath,
      );

      final provider = context.read<ServerProvider>();
      await provider.addServer(server);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Server "${server.name}" creato con successo!\n'
              'Database: ${path.dirname(databasePath)}'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore nella creazione del server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
