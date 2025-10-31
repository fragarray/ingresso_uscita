import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/timbratura_qr_service.dart';
import '../models/employee.dart';
import '../main.dart';
import 'debug_log_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingServer = false;
  bool _rememberMe = false;
  bool _isAutoLoggingIn = false;
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkFirstRunAndPromptPort(); // Controlla primo avvio
    _attemptAutoLogin();
  }

  // Controlla se è il primo avvio e mostra dialog configurazione porta
  Future<void> _checkFirstRunAndPromptPort() async {
    final prefs = await SharedPreferences.getInstance();
    final hasConfiguredPort = prefs.getBool('port_configured') ?? false;
    
    if (!hasConfiguredPort) {
      // Primo avvio - mostra dialog dopo che la UI è pronta
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showServerConfigDialog(isFirstRun: true);
        }
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedUsername != null && savedPassword != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _attemptAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('auto_login') ?? false;
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');

    if (autoLogin && savedUsername != null && savedPassword != null) {
      setState(() => _isAutoLoggingIn = true);

      try {
        final employee = await ApiService.login(savedUsername, savedPassword);
        
        if (employee != null && mounted) {
          // SICUREZZA: Verifica se è un operaio
          if (employee.role == EmployeeRole.employee) {
            print('[LoginPage] 🔒 OPERAIO rilevato - Auto-login DISABILITATO per sicurezza');
            await prefs.setBool('auto_login', false);
            setState(() => _isAutoLoggingIn = false);
            return; // Forza login manuale
          }
          
          // Solo ADMIN e TITOLARI possono fare auto-login
          print('[LoginPage] 👑 ADMIN/TITOLARE - Auto-login consentito');
          context.read<AppState>().setEmployee(employee);
          // La navigazione è gestita automaticamente dal Consumer in main.dart
        } else {
          // Credenziali non più valide, disabilita auto-login
          if (mounted) {
            await prefs.setBool('auto_login', false);
            setState(() => _isAutoLoggingIn = false);
          }
        }
      } on Exception catch (e) {
        if (mounted) {
          final errorMessage = e.toString();
          
          // Se l'account è stato eliminato, disabilita auto-login e mostra messaggio
          if (errorMessage.contains('Account non più attivo')) {
            await prefs.setBool('auto_login', false);
            setState(() => _isAutoLoggingIn = false);
            
            // Mostra messaggio dopo che la UI è pronta
            Future.delayed(Duration.zero, () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      '🚫 Account Disattivato\n\n'
                      'Questo account è stato disattivato dall\'amministratore.\n'
                      'Contatta l\'amministratore per maggiori informazioni.',
                    ),
                    backgroundColor: Colors.red[700],
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
            });
          } else {
            // Altri errori (rete, server), mostra semplicemente la pagina di login
            setState(() => _isAutoLoggingIn = false);
          }
        }
      } catch (e) {
        // Errore generico di connessione, mostra la pagina di login
        if (mounted) {
          setState(() => _isAutoLoggingIn = false);
        }
      }
    }
  }



  Future<void> _executeQRTimbratura() async {
    final appState = context.read<AppState>();
    final qrData = appState.pendingQRData;
    
    if (qrData == null || appState.currentEmployee == null) {
      return;
    }

    print('[LOGIN] 🚀 Inizio chiamata al servizio timbratura QR - NESSUN ALERT!');
    final timbratureService = TimbratureQRService();
    
    try {
      final result = await timbratureService.timbraFromQR(
        qrData: qrData,
        userId: appState.currentEmployee!.id.toString(),
        authToken: 'dummy_token', // TODO: Implementare sistema auth token
      ).timeout(Duration(seconds: 30));

      print('[LOGIN] 🏁 Fine chiamata servizio, risultato: ${result.success} - NESSUN ALERT MOSTRATO');
    } catch (e) {
      print('[LOGIN] ❌ Timeout o errore servizio timbratura: $e - NESSUN ALERT MOSTRATO');
    }
    
    // Pulisci QR pending
    appState.clearPendingQRData();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserire username e password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final employee = await ApiService.login(username, password);
      
      if (employee != null) {
        // Gestione credenziali basata sul ruolo
        final prefs = await SharedPreferences.getInstance();
        
        if (employee.role == EmployeeRole.employee) {
          // OPERAIO: Salva credenziali se richiesto ma MAI auto-login
          print('[LoginPage] 🔒 OPERAIO - Salvo credenziali ma disabilito auto-login');
          if (_rememberMe) {
            await prefs.setString('saved_username', username);
            await prefs.setString('saved_password', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('saved_username');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
          }
          // SEMPRE disabilitato auto-login per operai
          await prefs.setBool('auto_login', false);
        } else {
          // ADMIN/TITOLARE: Ricorda = Auto-login completo
          print('[LoginPage] 👑 ADMIN/TITOLARE - Ricorda = Auto-login');
          if (_rememberMe) {
            await prefs.setString('saved_username', username);
            await prefs.setString('saved_password', password);
            await prefs.setBool('remember_me', true);
            await prefs.setBool('auto_login', true);
          } else {
            await prefs.remove('saved_username');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            await prefs.setBool('auto_login', false);
          }
        }

        if (!mounted) return;
        final appState = context.read<AppState>();
        appState.setEmployee(employee);
        
        // Se c'è QR pending, esegui timbratura
        if (appState.pendingQRData != null) {
          await _executeQRTimbratura();
        }
        
        // La navigazione è gestita automaticamente dal Consumer in main.dart
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenziali non valide')),
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      // Controlla se è un account eliminato
      final errorMessage = e.toString();
      if (errorMessage.contains('Account non più attivo')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '🚫 Account Disattivato\n\n'
              'Questo account è stato disattivato dall\'amministratore.\n'
              'Contatta l\'amministratore per maggiori informazioni.',
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore di connessione al server')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di connessione al server')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkServerConnection() async {
    setState(() => _isCheckingServer = true);
    
    final defaultIp = ApiService.getDefaultServerIp();
    final result = await ApiService.pingServer(defaultIp);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      // Server predefinito raggiungibile
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server raggiungibile: ${result['message']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Server non raggiungibile, chiedi nuovo IP
      _showServerConfigDialog();
    }
    
    setState(() => _isCheckingServer = false);
  }

  void _showServerConfigDialog({bool isFirstRun = false}) {
    final ipController = TextEditingController(
      text: isFirstRun ? ApiService.getDefaultServerIp() : '',
    );
    final portController = TextEditingController(
      text: ApiService.getDefaultServerPort().toString(),
    );
    
    showDialog(
      context: context,
      barrierDismissible: !isFirstRun, // Non può chiudere al primo avvio
      builder: (context) => WillPopScope(
        onWillPop: () async => !isFirstRun, // Impedisce back button al primo avvio
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings_input_antenna, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(isFirstRun ? '⚙️ Configurazione Iniziale' : 'Configura Server'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFirstRun ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFirstRun ? Colors.blue.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isFirstRun ? Icons.info : Icons.warning_amber,
                        color: isFirstRun ? Colors.blue.shade700 : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFirstRun
                              ? 'Primo avvio: configura la porta del server per iniziare.'
                              : 'Il server predefinito non è raggiungibile.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Inserisci i dati del server:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    labelText: 'Indirizzo IP o Hostname',
                    hintText: 'es. 192.168.1.100',
                    helperText: 'Indirizzo del server',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.dns),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  decoration: InputDecoration(
                    labelText: 'Porta',
                    hintText: 'es. ${ApiService.getDefaultServerPort()}',
                    helperText: 'Porta del servizio (default: ${ApiService.getDefaultServerPort()})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.power),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esempio completo:\nIP: ${ApiService.getDefaultServerIp()}\nPorta: ${ApiService.getDefaultServerPort()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isFirstRun) // Mostra Annulla solo se non è primo avvio
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                final newIp = ipController.text.trim();
                final portText = portController.text.trim();
                
                if (newIp.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserire un indirizzo IP valido')),
                  );
                  return;
                }
                
                final newPort = int.tryParse(portText);
                if (newPort == null || newPort < 1 || newPort > 65535) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserire una porta valida (1-65535)')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _testAndSaveServer(newIp, newPort, isFirstRun: isFirstRun);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Verifica e Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testAndSaveServer(String ip, int port, {bool isFirstRun = false}) async {
    setState(() => _isCheckingServer = true);
    
    final result = await ApiService.pingServer(ip, port);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      // Server raggiungibile, salvalo
      await ApiService.setServerIp(ip);
      await ApiService.setServerPort(port);
      
      // Se è il primo avvio, segna che la porta è stata configurata
      if (isFirstRun) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('port_configured', true);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFirstRun 
                    ? '✅ Configurazione completata con successo!' 
                    : '✅ Server configurato con successo!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Indirizzo: $ip:$port'),
              Text('Versione: ${result['version']}'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌ Errore di connessione',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(result['error'] ?? 'Errore sconosciuto'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Se è primo avvio e fallisce, mostra di nuovo il dialog
      if (isFirstRun && mounted) {
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) {
            _showServerConfigDialog(isFirstRun: true);
          }
        });
      }
    }
    
    setState(() => _isCheckingServer = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se stiamo tentando l'auto-login, mostra solo il logo e un indicatore di caricamento
    if (_isAutoLoggingIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinergy Work'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Sinergy Work (con debug tap nascosto)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _debugTapCount++;
                      if (_debugTapCount >= 7) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🐛 Debug mode attivato'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  },
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                

                
                // Indicatore GPS se in attesa GPS
                Consumer<AppState>(
                  builder: (context, appState, child) {
                    if (appState.isWaitingForGPS) {
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: appState.isGPSReady ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: appState.isGPSReady ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Row(
                              children: [
                                appState.isGPSReady 
                                  ? const Icon(Icons.gps_fixed, color: Colors.green, size: 20)
                                  : const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    appState.isGPSReady
                                        ? 'GPS pronto - Puoi effettuare il login'
                                        : 'Triangolazione GPS in corso...',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                const Text(
                  'Benvenuto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 10),
                // Avviso di sicurezza per operai
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Operai: Login manuale obbligatorio ad ogni accesso (auto-logout 60s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.text,
                autocorrect: false,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Checkbox "Ricorda credenziali"
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _rememberMe = !_rememberMe;
                              });
                            },
                      child: const Text(
                        'Ricorda credenziali',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  final isWaitingForGPS = appState.isWaitingForGPS && !appState.isGPSReady;
                  final isButtonDisabled = _isLoading || isWaitingForGPS;
                  
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isButtonDisabled ? null : _login,
                      child: _isLoading 
                        ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        : isWaitingForGPS 
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text('Attendi GPS...'),
                              ],
                            )
                          : const Text('Login'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Pulsanti per gestione server
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsante verifica server
                  TextButton.icon(
                    onPressed: _isCheckingServer ? null : _checkServerConnection,
                    icon: _isCheckingServer 
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_outlined, size: 16),
                    label: Text(
                      _isCheckingServer ? 'Verifica...' : 'Verifica Server',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Separatore verticale
                  Container(
                    height: 20,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 8),
                  // Pulsante configura server
                  TextButton.icon(
                    onPressed: _isCheckingServer || _isLoading ? null : _showServerConfigDialog,
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text(
                      'Configura Server',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
      floatingActionButton: _debugTapCount >= 7 
        ? FloatingActionButton(
            mini: true,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebugLogPage(),
              ),
            ),
          )
        : null,
    );
  }
}