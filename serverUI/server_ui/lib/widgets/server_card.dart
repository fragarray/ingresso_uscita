import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_instance.dart';
import '../providers/server_provider.dart';
import '../screens/server_detail_screen.dart';

class ServerCard extends StatelessWidget {
  final ServerInstance server;

  const ServerCard({
    Key? key,
    required this.server,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _openServerDetails(context),
        child: Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nome e stato
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      server.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusIcon(),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Informazioni del server
              _buildInfoRow(Icons.network_ping, 'Porta: ${server.port}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.folder, 'DB: ${_getShortPath(server.databasePath)}'),
              
              const Spacer(),
              
              // Stato e controlli
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      server.statusText,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!server.isTransitioning) _buildActionButton(context),
                ],
              ),
              
              // Messaggio di errore se presente
              if (server.hasError && server.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  server.errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;
    
    switch (server.status) {
      case ServerStatus.running:
        icon = Icons.play_circle_filled;
        color = Colors.green;
        break;
      case ServerStatus.stopped:
        icon = Icons.stop_circle;
        color = Colors.grey;
        break;
      case ServerStatus.starting:
      case ServerStatus.stopping:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case ServerStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Icon(icon, color: color, size: 24);
  }

  Widget _buildActionButton(BuildContext context) {
    final serverProvider = Provider.of<ServerProvider>(context, listen: false);
    
    if (server.isRunning) {
      return IconButton(
        icon: const Icon(Icons.stop, color: Colors.red),
        onPressed: () => serverProvider.stopServer(server.id),
        tooltip: 'Ferma server',
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.play_arrow, color: Colors.green),
        onPressed: () => serverProvider.startServer(server.id),
        tooltip: 'Avvia server',
      );
    }
  }

  Color _getStatusColor() {
    switch (server.status) {
      case ServerStatus.running:
        return Colors.green;
      case ServerStatus.stopped:
        return Colors.grey;
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return Colors.orange;
      case ServerStatus.error:
        return Colors.red;
    }
  }

  String _getShortPath(String path) {
    if (path.length <= 15) return path;
    return '...${path.substring(path.length - 12)}';
  }

  void _openServerDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServerDetailScreen(serverId: server.id),
      ),
    );
  }
}