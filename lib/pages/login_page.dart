import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingServer = false;
  bool _rememberMe = false;
  bool _isAutoLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _attemptAutoLogin();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _attemptAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('auto_login') ?? false;
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');

    if (autoLogin && savedEmail != null && savedPassword != null) {
      setState(() => _isAutoLoggingIn = true);

      try {
        final employee = await ApiService.login(savedEmail, savedPassword);
        
        if (employee != null && mounted) {
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

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserire email e password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final employee = await ApiService.login(email, password);
      
      if (employee != null) {
        // Salva le credenziali se "Ricorda" è attivo
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_email', email);
          await prefs.setString('saved_password', password);
          await prefs.setBool('remember_me', true);
          await prefs.setBool('auto_login', true);
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
          await prefs.setBool('remember_me', false);
          await prefs.setBool('auto_login', false);
        }

        if (!mounted) return;
        context.read<AppState>().setEmployee(employee);
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

  void _showServerConfigDialog() {
    final ipController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configura Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Il server predefinito non è raggiungibile.',
              style: TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text('Inserisci l\'indirizzo del server:'),
            const SizedBox(height: 8),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP o Hostname',
                hintText: 'es. 192.168.1.100 o server.local',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newIp = ipController.text.trim();
              if (newIp.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserire un indirizzo valido')),
                );
                return;
              }
              
              Navigator.pop(context);
              await _testAndSaveServer(newIp);
            },
            child: const Text('Verifica'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAndSaveServer(String ip) async {
    setState(() => _isCheckingServer = true);
    
    final result = await ApiService.pingServer(ip);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      // Server raggiungibile, salvalo
      await ApiService.setServerIp(ip);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server configurato: ${result['message']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${result['error']}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    
    setState(() => _isCheckingServer = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
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
                // Logo Sinergy Work
                Image.asset(
                  'assets/images/logo.png',
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Benvenuto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
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
                        'Ricorda le credenziali',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
                ),
              ),
              const SizedBox(height: 40),
              // Pulsante discreto per verificare il server
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
                  _isCheckingServer ? 'Verifica in corso...' : 'Verifica Server',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}