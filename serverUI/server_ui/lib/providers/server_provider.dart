import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_instance.dart';

class ServerProvider extends ChangeNotifier {
  List<ServerInstance> _servers = [];
  bool _isMinimized = false;

  List<ServerInstance> get servers => _servers;
  bool get isMinimized => _isMinimized;
  bool get hasRunningServers => _servers.any((s) => s.isRunning);

  // Carica i server salvati
  Future<void> loadServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = prefs.getString('servers');
      
      if (serversJson != null) {
        final List<dynamic> serversList = jsonDecode(serversJson);
        _servers = serversList
            .map((json) => ServerInstance.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Errore nel caricamento dei server: $e');
    }
  }

  // Salva i server
  Future<void> saveServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = jsonEncode(_servers.map((s) => s.toJson()).toList());
      await prefs.setString('servers', serversJson);
    } catch (e) {
      debugPrint('Errore nel salvataggio dei server: $e');
    }
  }

  // Aggiunge un nuovo server
  Future<void> addServer(ServerInstance server) async {
    _servers.add(server);
    notifyListeners();
    await saveServers();
  }

  // Rimuove un server
  Future<void> removeServer(String serverId) async {
    final server = _servers.firstWhere((s) => s.id == serverId);
    
    // Ferma il server se è in esecuzione
    if (server.isRunning) {
      await stopServer(serverId);
    }
    
    _servers.removeWhere((s) => s.id == serverId);
    notifyListeners();
    await saveServers();
  }

  // Aggiorna un server
  Future<void> updateServer(ServerInstance updatedServer) async {
    final index = _servers.indexWhere((s) => s.id == updatedServer.id);
    if (index != -1) {
      _servers[index] = updatedServer;
      notifyListeners();
      await saveServers();
    }
  }

  // Avvia un server
  Future<void> startServer(String serverId) async {
    final index = _servers.indexWhere((s) => s.id == serverId);
    if (index == -1) return;

    final server = _servers[index];
    if (server.isRunning) return;

    // Controlla se la porta è già in uso
    if (await _isPortInUse(server.port)) {
      _servers[index] = server.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Porta ${server.port} già in uso',
      );
      notifyListeners();
      await saveServers();
      return;
    }

    try {
      await server.startServer();
      notifyListeners();
      await saveServers();
    } catch (e) {
      notifyListeners();
      await saveServers();
    }
  }

  // Ferma un server
  Future<void> stopServer(String serverId) async {
    final index = _servers.indexWhere((s) => s.id == serverId);
    if (index == -1) return;

    final server = _servers[index];
    if (server.isStopped) return;

    try {
      await server.stopServer();
      notifyListeners();
      await saveServers();
    } catch (e) {
      notifyListeners();
      await saveServers();
    }
  }

  // Controlla se una porta è in uso
  Future<bool> _isPortInUse(int port) async {
    try {
      final socket = await ServerSocket.bind('localhost', port);
      await socket.close();
      return false;
    } catch (e) {
      return true;
    }
  }

  // Ferma tutti i server
  Future<void> stopAllServers() async {
    final runningServers = _servers.where((s) => s.isRunning).toList();
    
    for (final server in runningServers) {
      await stopServer(server.id);
    }
  }

  // Gestisce la minimizzazione
  void setMinimized(bool minimized) {
    _isMinimized = minimized;
    notifyListeners();
  }

  // Ottiene un server per ID
  ServerInstance? getServer(String serverId) {
    try {
      return _servers.firstWhere((s) => s.id == serverId);
    } catch (e) {
      return null;
    }
  }
}