import 'dart:io';
import 'package:flutter/material.dart';
import '../services/dependency_checker.dart';

class DependencyCheckScreen extends StatefulWidget {
  const DependencyCheckScreen({Key? key}) : super(key: key);

  @override
  State<DependencyCheckScreen> createState() => _DependencyCheckScreenState();
}

class _DependencyCheckScreenState extends State<DependencyCheckScreen> {
  List<DependencyStatus>? _dependencies;
  bool _isChecking = false;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    _checkDependencies();
  }

  Future<void> _checkDependencies() async {
    setState(() {
      _isChecking = true;
      _dependencies = null;
    });

    final deps = await DependencyChecker.checkAll();

    setState(() {
      _dependencies = deps;
      _isChecking = false;
    });
  }

  Future<void> _installNodeJs() async {
    if (Platform.isWindows) {
      setState(() => _isInstalling = true);

      final result = await DependencyChecker.installNodeJsWindows();

      setState(() => _isInstalling = false);

      if (!mounted) return;

      if (result.requiresManualInstall) {
        // Apri la pagina di download
        await DependencyChecker.openNodeJsDownloadPage();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pagina di download aperta nel browser. '
              'Scarica e installa Node.js, poi riavvia questa applicazione.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (result.success) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Installazione Completata'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkDependencies();
                },
                child: const Text('Ricontrolla'),
              ),
              ElevatedButton(
                onPressed: () => exit(0),
                child: const Text('Riavvia Applicazione'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else if (Platform.isLinux) {
      _showInstructionsDialog(
        'Installazione Node.js - Linux',
        DependencyChecker.getLinuxInstallInstructions(),
      );
    } else if (Platform.isMacOS) {
      _showInstructionsDialog(
        'Installazione Node.js - macOS',
        DependencyChecker.getMacOsInstallInstructions(),
      );
    }
  }

  void _showInstructionsDialog(String title, String instructions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            instructions,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          ElevatedButton(
            onPressed: () {
              DependencyChecker.openNodeJsDownloadPage();
              Navigator.of(context).pop();
            },
            child: const Text('Apri Sito Node.js'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica Dipendenze'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isChecking
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifica dipendenze in corso...'),
                ],
              ),
            )
          : _buildDependenciesList(),
    );
  }

  Widget _buildDependenciesList() {
    if (_dependencies == null) {
      return const Center(child: Text('Errore durante la verifica'));
    }

    final allInstalled = _dependencies!.every((d) => d.isInstalled);

    return Column(
      children: [
        // Header con stato generale
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: allInstalled ? Colors.green.shade50 : Colors.orange.shade50,
          child: Column(
            children: [
              Icon(
                allInstalled ? Icons.check_circle : Icons.warning,
                size: 64,
                color: allInstalled ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                allInstalled
                    ? '✅ Tutte le dipendenze sono installate'
                    : '⚠️ Alcune dipendenze mancano',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: allInstalled ? Colors.green.shade900 : Colors.orange.shade900,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Lista dipendenze
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _dependencies!.length,
            itemBuilder: (context, index) {
              final dep = _dependencies![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            dep.isInstalled ? Icons.check_circle : Icons.cancel,
                            color: dep.isInstalled ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dep.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dep.statusText,
                                  style: TextStyle(
                                    color: dep.isInstalled ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (dep.path != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Percorso: ${dep.path}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      if (dep.message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dep.message!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Pulsanti azione
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allInstalled)
                ElevatedButton.icon(
                  onPressed: _isInstalling ? null : _installNodeJs,
                  icon: _isInstalling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isInstalling ? 'Installazione...' : 'Installa Node.js'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isChecking ? null : _checkDependencies,
                icon: const Icon(Icons.refresh),
                label: const Text('Ricontrolla'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
