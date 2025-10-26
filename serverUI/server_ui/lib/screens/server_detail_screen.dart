import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/server_instance.dart';
import '../providers/server_provider.dart';

class ServerDetailScreen extends StatefulWidget {
  final String serverId;

  const ServerDetailScreen({
    Key? key,
    required this.serverId,
  }) : super(key: key);

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, provider, child) {
        final server = provider.getServer(widget.serverId);
        
        if (server == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Server non trovato'),
            ),
            body: const Center(
              child: Text('Il server richiesto non è stato trovato.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(server.name),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            actions: [
              // Stato del server
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusIcon(server),
                    const SizedBox(width: 8),
                    Text(
                      server.statusText,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              
              // Controlli del server
              if (!server.isTransitioning) ...[
                if (server.isRunning)
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () => provider.stopServer(server.id),
                    tooltip: 'Ferma server',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => provider.startServer(server.id),
                    tooltip: 'Avvia server',
                  ),
              ],
              
              // Menu opzioni
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, server, provider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Modifica'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Elimina'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'Info'),
                Tab(icon: Icon(Icons.description), text: 'Log'),
                Tab(icon: Icon(Icons.settings), text: 'Config'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(server),
              _buildLogTab(server),
              _buildConfigTab(server, provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(ServerInstance server) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informazioni Server',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow('Nome', server.name),
                  _buildInfoRow('Porta', server.port.toString()),
                  _buildInfoRow('Cartella', server.databasePath),
                  _buildInfoRow('Stato', server.statusText),
                  
                  if (server.lastStarted != null)
                    _buildInfoRow('Ultimo avvio', 
                        _formatDateTime(server.lastStarted!)),
                  
                  if (server.lastStopped != null)
                    _buildInfoRow('Ultimo arresto', 
                        _formatDateTime(server.lastStopped!)),
                  
                  if (server.hasError && server.errorMessage != null) ...[
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Errore:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                server.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Statistiche
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistiche',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow('Righe di log', server.logs.length.toString()),
                  _buildInfoRow('Stato', server.statusText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab(ServerInstance server) {
    return Column(
      children: [
        // Header con controlli log
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                'Log (${server.logs.length} righe)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: server.logs.isNotEmpty 
                    ? () => _clearLogs(server) 
                    : null,
                tooltip: 'Cancella log',
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: server.logs.isNotEmpty 
                    ? () => _copyLogs(server) 
                    : null,
                tooltip: 'Copia log',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: _scrollToBottom,
                tooltip: 'Vai in fondo',
              ),
            ],
          ),
        ),
        
        // Area dei log
        Expanded(
          child: server.logs.isEmpty
              ? const Center(
                  child: Text(
                    'Nessun log disponibile',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _logScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: server.logs.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: index.isEven 
                            ? Colors.grey[50] 
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        server.logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConfigTab(ServerInstance server, ServerProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurazione',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              const Text('Funzionalità avanzate:'),
              const SizedBox(height: 16),
              
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Riavvia Server'),
                subtitle: const Text('Ferma e riavvia il server'),
                enabled: server.isRunning && !server.isTransitioning,
                onTap: server.isRunning 
                    ? () => _restartServer(server, provider)
                    : null,
              ),
              
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup Database'),
                subtitle: const Text('Crea backup del database'),
                onTap: () => _backupDatabase(server),
              ),
              
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Ripristina Database'),
                subtitle: const Text('Ripristina database da backup'),
                onTap: () => _restoreDatabase(server),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ServerInstance server) {
    switch (server.status) {
      case ServerStatus.running:
        return const Icon(Icons.play_circle_filled, color: Colors.green);
      case ServerStatus.stopped:
        return const Icon(Icons.stop_circle, color: Colors.grey);
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ServerStatus.error:
        return const Icon(Icons.error_outline, color: Colors.red);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearLogs(ServerInstance server) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella Log'),
        content: const Text('Sei sicuro di voler cancellare tutti i log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              server.logs.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Cancella'),
          ),
        ],
      ),
    );
  }

  void _copyLogs(ServerInstance server) {
    Clipboard.setData(ClipboardData(text: server.logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copiati negli appunti')),
    );
  }

  void _handleMenuAction(String action, ServerInstance server, 
      ServerProvider provider) {
    switch (action) {
      case 'edit':
        _editServer(server, provider);
        break;
      case 'delete':
        _deleteServer(server, provider);
        break;
    }
  }

  void _editServer(ServerInstance server, ServerProvider provider) {
    // Implementa la modifica del server
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzione di modifica non ancora implementata')),
    );
  }

  void _deleteServer(ServerInstance server, ServerProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Server'),
        content: Text('Sei sicuro di voler eliminare il server "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              await provider.removeServer(server.id);
              if (mounted) {
                Navigator.pop(context); // Chiude il dialog
                Navigator.pop(context); // Torna alla home
              }
            },
            child: const Text('Elimina'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _restartServer(ServerInstance server, ServerProvider provider) async {
    await provider.stopServer(server.id);
    // Aspetta un momento per assicurarsi che il server sia fermato
    await Future.delayed(const Duration(seconds: 2));
    await provider.startServer(server.id);
  }

  void _backupDatabase(ServerInstance server) {
    // Implementa il backup del database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzione di backup non ancora implementata')),
    );
  }

  void _restoreDatabase(ServerInstance server) {
    // Implementa il ripristino del database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzione di ripristino non ancora implementata')),
    );
  }
}