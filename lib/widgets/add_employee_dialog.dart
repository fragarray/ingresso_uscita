import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class AddEmployeeDialog extends StatefulWidget {
  final Function() onEmployeeAdded;

  const AddEmployeeDialog({Key? key, required this.onEmployeeAdded}) : super(key: key);

  @override
  _AddEmployeeDialogState createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  EmployeeRole _selectedRole = EmployeeRole.employee;
  bool _allowNightShift = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newEmployee = Employee(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        allowNightShift: _allowNightShift,
      );

      final success = await ApiService.addEmployee(newEmployee);

      if (success) {
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onEmployeeAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dipendente aggiunto con successo')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'aggiunta del dipendente')),
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
      title: const Text('Aggiungi Dipendente'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire un nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (per login)',
                  prefixIcon: Icon(Icons.account_circle),
                  helperText: 'Univoco, solo lettere, numeri e underscore',
                ),
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire un username';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Solo lettere, numeri e underscore';
                  }
                  if (value.length < 3) {
                    return 'Minimo 3 caratteri';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _selectedRole == EmployeeRole.admin 
                      ? 'Email (obbligatoria per admin)' 
                      : 'Email (opzionale)',
                  prefixIcon: const Icon(Icons.email),
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
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Minimo 6 caratteri',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire una password';
                  }
                  if (value.length < 6) {
                    return 'La password deve essere di almeno 6 caratteri';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
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
                    child: Text('👷‍♂️ Capocantiere'),
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
              const SizedBox(height: 8),
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
          onPressed: _isLoading ? null : _addEmployee,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Aggiungi'),
        ),
      ],
    );
  }
}