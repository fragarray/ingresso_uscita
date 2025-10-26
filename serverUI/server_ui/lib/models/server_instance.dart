import 'dart:io';
import 'package:path/path.dart' as path;

enum ServerStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ServerInstance {
  final String id;
  String name;
  int port;
  String databasePath;
  String serverPath;
  ServerStatus status;
  String? errorMessage;
  DateTime? lastStarted;
  DateTime? lastStopped;
  List<String> logs;
  Process? _process;

  ServerInstance({
    required this.id,
    required this.name,
    required this.port,
    required this.databasePath,
    required this.serverPath,
    this.status = ServerStatus.stopped,
    this.errorMessage,
    this.lastStarted,
    this.lastStopped,
    List<String>? logs,
    Process? process,
  }) : logs = logs ?? [], _process = process;

  // Copia del server con modifiche
  ServerInstance copyWith({
    String? name,
    int? port,
    String? databasePath,
    String? serverPath,
    ServerStatus? status,
    String? errorMessage,
    DateTime? lastStarted,
    DateTime? lastStopped,
    List<String>? logs,
    Process? process,
  }) {
    return ServerInstance(
      id: id,
      name: name ?? this.name,
      port: port ?? this.port,
      databasePath: databasePath ?? this.databasePath,
      serverPath: serverPath ?? this.serverPath,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastStarted: lastStarted ?? this.lastStarted,
      lastStopped: lastStopped ?? this.lastStopped,
      logs: logs ?? List.from(this.logs),
      process: process ?? _process,
    );
  }

  // Serializzazione JSON (senza process)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'port': port,
      'databasePath': databasePath,
      'serverPath': serverPath,
      'status': status.index,
      'errorMessage': errorMessage,
      'lastStarted': lastStarted?.toIso8601String(),
      'lastStopped': lastStopped?.toIso8601String(),
      'logs': logs,
    };
  }

  factory ServerInstance.fromJson(Map<String, dynamic> json) {
    return ServerInstance(
      id: json['id'],
      name: json['name'],
      port: json['port'],
      databasePath: json['databasePath'],
      serverPath: json['serverPath'] ?? '',
      status: ServerStatus.values[json['status'] ?? 0],
      errorMessage: json['errorMessage'],
      lastStarted: json['lastStarted'] != null 
          ? DateTime.parse(json['lastStarted']) 
          : null,
      lastStopped: json['lastStopped'] != null 
          ? DateTime.parse(json['lastStopped']) 
          : null,
      logs: List<String>.from(json['logs'] ?? []),
    );
  }

  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    logs.add('[$timestamp] $message');
    
    // Mantieni solo gli ultimi 1000 log per evitare accumulo eccessivo
    if (logs.length > 1000) {
      logs.removeRange(0, logs.length - 1000);
    }
  }

  bool get isRunning => status == ServerStatus.running;
  bool get isStopped => status == ServerStatus.stopped;
  bool get hasError => status == ServerStatus.error;
  bool get isTransitioning => 
      status == ServerStatus.starting || status == ServerStatus.stopping;

  String get statusText {
    switch (status) {
      case ServerStatus.stopped:
        return 'Fermato';
      case ServerStatus.starting:
        return 'Avvio...';
      case ServerStatus.running:
        return 'In esecuzione';
      case ServerStatus.stopping:
        return 'Arresto...';
      case ServerStatus.error:
        return 'Errore';
    }
  }

  // Avvia il server
  Future<void> startServer() async {
    if (status == ServerStatus.running) return;

    try {
      status = ServerStatus.starting;
      addLog('📦 Preparazione avvio server...');
      
      // Controlla e installa le dipendenze se necessarie
      await _checkAndInstallDependencies();
      
      // Avvia il processo Node.js
      addLog('🚀 Avvio processo Node.js...');
      _process = await Process.start(
        'node',
        ['server.js'],
        environment: {'PORT': port.toString()},
        workingDirectory: path.dirname(serverPath),
      );

      // Ascolta l'output del processo
      _process!.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        addLog(output.trim());
      });

      _process!.stderr.listen((data) {
        final output = String.fromCharCodes(data);
        addLog('ERROR: ${output.trim()}');
      });

      // Controlla quando il processo termina
      _process!.exitCode.then((exitCode) {
        if (status == ServerStatus.running) {
          status = ServerStatus.stopped;
          addLog('⚠️ Server terminato inaspettatamente (exit code: $exitCode)');
          lastStopped = DateTime.now();
        }
      });

      // Controlla se il server è effettivamente avviato
      await _waitForServerReady();
      
    } catch (e) {
      status = ServerStatus.error;
      errorMessage = e.toString();
      addLog('❌ Errore nell\'avvio del server: $e');
    }
  }

  // Ferma il server
  Future<void> stopServer() async {
    if (status == ServerStatus.stopped) return;

    try {
      status = ServerStatus.stopping;
      addLog('🛑 Arresto server in corso...');

      if (_process != null) {
        _process!.kill();
        await _process!.exitCode;
        _process = null;
      }

      status = ServerStatus.stopped;
      lastStopped = DateTime.now();
      addLog('✅ Server arrestato correttamente');
    } catch (e) {
      status = ServerStatus.error;
      errorMessage = e.toString();
      addLog('❌ Errore nell\'arresto del server: $e');
    }
  }

  // Controlla e installa le dipendenze npm
  Future<void> _checkAndInstallDependencies() async {
    final serverDir = path.dirname(serverPath);
    final nodeModulesDir = Directory(path.join(serverDir, 'node_modules'));
    
    if (!nodeModulesDir.existsSync()) {
      addLog('📦 Installazione dipendenze npm in corso...');
      
      final installProcess = await Process.run(
        'npm',
        ['install'],
        workingDirectory: serverDir,
      );
      
      if (installProcess.exitCode == 0) {
        addLog('✅ Dipendenze installate correttamente');
      } else {
        addLog('❌ Errore installazione dipendenze: ${installProcess.stderr}');
        throw Exception('Errore installazione dipendenze npm');
      }
    } else {
      addLog('✅ Dipendenze npm già presenti');
    }
  }

  // Aspetta che il server sia pronto
  Future<void> _waitForServerReady() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 secondi
    
    while (attempts < maxAttempts) {
      try {
        // Prova a fare una richiesta ping al server
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        
        final request = await client.get('localhost', port, '/api/ping');
        final response = await request.close();
        
        if (response.statusCode == 200) {
          status = ServerStatus.running;
          lastStarted = DateTime.now();
          addLog('✅ Server avviato correttamente su porta $port');
          client.close();
          return;
        }
        client.close();
      } catch (e) {
        // Server non ancora pronto, aspetta
      }
      
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
      
      if (attempts % 5 == 0) {
        addLog('⏳ Attendo che il server sia pronto... (${attempts}s)');
      }
    }
    
    status = ServerStatus.error;
    errorMessage = 'Timeout: il server non risponde dopo 30 secondi';
    addLog('❌ Timeout: il server non risponde dopo 30 secondi');
  }

  @override
  String toString() {
    return 'ServerInstance(id: $id, name: $name, port: $port, status: $status)';
  }
}