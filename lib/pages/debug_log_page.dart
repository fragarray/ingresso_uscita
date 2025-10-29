import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debug_log_service.dart';

class DebugLogPage extends StatefulWidget {
  const DebugLogPage({Key? key}) : super(key: key);

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  final _debugLog = DebugLogService();
  List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _debugLog.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    await _debugLog.clearLogs();
    await _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log cancellati')),
      );
    }
  }

  Future<void> _copyLogs() async {
    final logsText = await _debugLog.getLogsAsString();
    await Clipboard.setData(ClipboardData(text: logsText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log copiati negli appunti')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Log'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Conferma'),
                  content: const Text('Cancellare tutti i log?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annulla'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancella'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await _clearLogs();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    'Nessun log disponibile', 
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getLogColor(log),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('❌') || log.contains('ERRORE')) {
      return Colors.red.shade50;
    } else if (log.contains('⚠️')) {
      return Colors.orange.shade50;
    } else if (log.contains('✅') || log.contains('COMPLETATO')) {
      return Colors.green.shade50;
    } else if (log.contains('🎯') || log.contains('INIZIO')) {
      return Colors.blue.shade50;
    } else {
      return Colors.grey.shade100;
    }
  }
}