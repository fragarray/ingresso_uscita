import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class EditEmployeeDialog extends StatefulWidget {
  final Employee employee;
  final Function() onEmployeeUpdated;

  const EditEmployeeDialog({
    Key? key,
    required this.employee,
    required this.onEmployeeUpdated,
  }) : super(key: key);

  @override
  _EditEmployeeDialogState createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController; // ✅ NUOVO: Conferma password
  bool _isLoading = false;
  late EmployeeRole _selectedRole;
  late bool _allowNightShift;
  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _usernameController = TextEditingController(text: widget.employee.username);
    _emailController = TextEditingController(text: widget.employee.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController(); // ✅ NUOVO: Init conferma password
    _selectedRole = widget.employee.role;
    _allowNightShift = widget.employee.allowNightShift;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // ✅ NUOVO: Dispose conferma password
    super.dispose();
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedEmployee = Employee(
        id: widget.employee.id,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _changePassword ? _passwordController.text.trim() : null, // ✅ FIX: trim() per rimuovere spazi
        role: _selectedRole,
        allowNightShift: _allowNightShift,
      );

      final success = await ApiService.updateEmployee(updatedEmployee);

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onEmployeeUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dipendente aggiornato con successo')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'aggiornamento del dipendente')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifica Dipendente'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ID Dipendente (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${widget.employee.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Nome
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire un nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Username (read-only dopo creazione)
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.account_circle),
                  border: OutlineInputBorder(),
                  helperText: 'Username non modificabile dopo creazione',
                ),
                enabled: false, // Username non modificabile
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              
              // Email (opzionale, obbligatoria solo per admin)
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _selectedRole == EmployeeRole.admin 
                      ? 'Email (obbligatoria per admin)' 
                      : 'Email (opzionale)',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  helperText: _selectedRole == EmployeeRole.admin
                      ? 'Richiesta per invio report'
                      : 'Opzionale per dipendenti',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // Email obbligatoria solo per admin
                  if (_selectedRole == EmployeeRole.admin) {
                    if (value == null || value.isEmpty) {
                      return 'Email obbligatoria per amministratori';
                    }
                    if (!value.contains('@')) {
                      return 'Inserire una email valida';
                    }
                  } else if (value != null && value.isNotEmpty && !value.contains('@')) {
                    // Se fornita per dipendente, deve essere valida
                    return 'Inserire una email valida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Checkbox per cambiare password
              CheckboxListTile(
                title: const Text('Cambia Password'),
                value: _changePassword,
                onChanged: (value) {
                  setState(() {
                    _changePassword = value ?? false;
                    if (!_changePassword) {
                      _passwordController.clear();
                      _confirmPasswordController.clear(); // ✅ Pulisci anche conferma password
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              
              // Campo password (visibile solo se _changePassword è true)
              if (_changePassword) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Nuova Password',
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Minimo 6 caratteri',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) {
                    if (_changePassword) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserire una password';
                      }
                      if (value.trim().length < 6) {
                        return 'La password deve essere di almeno 6 caratteri';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // ✅ NUOVO: Campo Conferma Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Conferma Nuova Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    helperText: 'Reinserisci la password per conferma',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) {
                    if (_changePassword) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Confermare la password';
                      }
                      if (value.trim() != _passwordController.text.trim()) {
                        return 'Le password non corrispondono!';
                      }
                    }
                    return null;
                  },
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Dropdown Ruolo
              DropdownButtonFormField<EmployeeRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Ruolo',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: EmployeeRole.employee,
                    child: Text('👷 Dipendente'),
                  ),
                  DropdownMenuItem(
                    value: EmployeeRole.foreman,
                    child: Text('� Titolare'),
                  ),
                  DropdownMenuItem(
                    value: EmployeeRole.admin,
                    child: Text('👨‍💼 Amministratore'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value ?? EmployeeRole.employee;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Checkbox turni notturni
              CheckboxListTile(
                title: const Text('Autorizza turni notturni'),
                subtitle: const Text('Può lavorare oltre la mezzanotte (no auto-logout)'),
                value: _allowNightShift,
                onChanged: (value) {
                  setState(() {
                    _allowNightShift = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                secondary: const Icon(Icons.nights_stay, color: Colors.indigo),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateEmployee,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
