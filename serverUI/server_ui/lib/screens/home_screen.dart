import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../widgets/server_card.dart';
import '../widgets/add_server_card.dart';
import '../services/tray_service.dart';
import 'add_server_screen.dart';
import 'dependency_check_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerProvider>().loadServers();
    });
  }

  /// Minimizza l'app nella tray invece di chiuderla
  Future<bool> _onWillPop() async {
    // Nascondi la finestra invece di chiuderla
    await TrayService.hideToTray();
    // Impedisci la chiusura
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Impedisci chiusura predefinita
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sinergy Work - Server Manager'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        actions: [
          Consumer<ServerProvider>(
            builder: (context, provider, child) {
              final runningCount = provider.servers.where((s) => s.isRunning).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      runningCount > 0 ? Icons.circle : Icons.circle_outlined,
                      color: runningCount > 0 ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Server attivi: $runningCount/${provider.servers.length}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'check_dependencies',
                child: Row(
                  children: [
                    Icon(Icons.fact_check, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Verifica Dipendenze'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'stop_all',
                child: Row(
                  children: [
                    Icon(Icons.stop, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Ferma tutti i server'),
                  ],
                ),
              ),
              if (TrayService.isSupported)
                const PopupMenuItem(
                  value: 'minimize',
                  child: Row(
                    children: [
                      Icon(Icons.minimize),
                      SizedBox(width: 8),
                      Text('Minimizza nel tray'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'exit',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Esci'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ServerProvider>(
        builder: (context, provider, child) {
          if (provider.servers.isEmpty) {
            return _buildEmptyState();
          }
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 carte per riga
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: provider.servers.length + 1, // +1 per la carta "Aggiungi"
              itemBuilder: (context, index) {
                if (index == provider.servers.length) {
                  return const AddServerCard();
                }
                
                return ServerCard(server: provider.servers[index]);
              },
            ),
          );
        },
      ),
      ), // Chiusura PopScope
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 128,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Nessun server configurato',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aggiungi il tuo primo server per iniziare',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openAddServerScreen(),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi Server'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    final provider = context.read<ServerProvider>();
    
    switch (value) {
      case 'check_dependencies':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DependencyCheckScreen(),
          ),
        );
        break;

      case 'stop_all':
        await provider.stopAllServers();
        await TrayService.updateTrayMenu();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tutti i server sono stati fermati')),
          );
        }
        break;
        
        case 'minimize':
        if (TrayService.isSupported) {
          // Minimizza nel tray (la finestra rimane aperta ma nascosta)
          provider.setMinimized(true);
          await TrayService.updateTrayMenu();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Applicazione minimizzata nel system tray'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        break;      case 'exit':
        await _confirmExit();
        break;
    }
  }

  Future<void> _confirmExit() async {
    final provider = context.read<ServerProvider>();
    
    if (provider.hasRunningServers) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conferma uscita'),
          content: const Text(
            'Ci sono server ancora in esecuzione. '
            'Tutti i server verranno fermati prima di uscire. Continuare?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Esci'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );
      
      if (shouldExit == true) {
        await provider.stopAllServers();
        await TrayService.dispose();
        exit(0);
      }
    } else {
      await TrayService.dispose();
      exit(0);
    }
  }

  void _openAddServerScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddServerScreen(),
      ),
    );
  }
}