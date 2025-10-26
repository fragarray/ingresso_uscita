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

  // Percorso della cartella del server integrato nell'applicazione
  static const String _integratedServerPath = '/home/tom/ingrARM/ingresso_uscita/serverUI/server';

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
  // Crea la cartella del server nella home dell'utente e copia tutti i file necessari
  Future<String> _createServerDirectory(String name) async {
    try {
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final serversBaseDir = Directory(path.join(homeDir, 'IngressoUscita_Servers'));
      
      // Crea la cartella base se non esiste
      if (!await serversBaseDir.exists()) {
        await serversBaseDir.create(recursive: true);
      }
      
      // Crea la cartella del server specifico
      final serverDir = Directory(path.join(serversBaseDir.path, name));
      if (await serverDir.exists()) {
        throw Exception('Un server con questo nome esiste già');
      }
      
      await serverDir.create(recursive: true);
      
      // Lista dei file essenziali da copiare
      final essentialFiles = [
        'server.js',
        'db.js',
        'config.js',
        'package.json',
        'package-lock.json',
      ];
      
      // Copia i file essenziali
      for (final fileName in essentialFiles) {
        final sourceFile = File(path.join(_integratedServerPath, fileName));
        final targetFile = File(path.join(serverDir.path, fileName));
        
        if (await sourceFile.exists()) {
          await sourceFile.copy(targetFile.path);
          print('✓ Copiato: $fileName');
        } else {
          print('⚠ File non trovato: $fileName');
        }
      }
      
      // Copia la cartella routes
      final sourceRoutesDir = Directory(path.join(_integratedServerPath, 'routes'));
      final targetRoutesDir = Directory(path.join(serverDir.path, 'routes'));
      
      if (await sourceRoutesDir.exists()) {
        await targetRoutesDir.create(recursive: true);
        await for (final file in sourceRoutesDir.list()) {
          if (file is File) {
            final fileName = path.basename(file.path);
            await file.copy(path.join(targetRoutesDir.path, fileName));
            print('✓ Copiato: routes/$fileName');
          }
        }
      }
      
      // Crea le cartelle necessarie
      final dirsToCreate = ['reports', 'temp', 'backups'];
      for (final dirName in dirsToCreate) {
        final dir = Directory(path.join(serverDir.path, dirName));
        await dir.create(recursive: true);
        print('✓ Creata cartella: $dirName');
      }
      
      // NON copiare il database - il server ne crea uno nuovo automaticamente
      // NON copiare node_modules - verrà creato da npm install
      
      // Il database verrà creato dal modulo db.js nella cartella del server
      final databasePath = path.join(serverDir.path, 'database.db');
      
      print('✅ Cartella server creata: ${serverDir.path}');
      return databasePath;
    } catch (e) {
      print('❌ Errore nella creazione della cartella: $e');
      rethrow;
    }
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
      
      // Il serverPath punta alla cartella dell'istanza del server
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final serverInstancePath = path.join(homeDir, 'IngressoUscita_Servers', serverName, 'server.js');
      
      // Crea l'istanza del server
      final server = ServerInstance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: serverName,
        port: port,
        databasePath: databasePath,
        serverPath: serverInstancePath,
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
