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
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  late bool _isAdmin;
  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email);
    _passwordController = TextEditingController();
    _isAdmin = widget.employee.isAdmin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedEmployee = Employee(
        id: widget.employee.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _changePassword ? _passwordController.text : null,
        isAdmin: _isAdmin,
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
        const SnackBar(content: Text('Errore di connessione al server')),
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
                  labelText: 'Nome',
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
              
              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserire una email';
                  }
                  if (!value.contains('@')) {
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
                  validator: (value) {
                    if (_changePassword) {
                      if (value == null || value.isEmpty) {
                        return 'Inserire una password';
                      }
                      if (value.length < 6) {
                        return 'La password deve essere di almeno 6 caratteri';
                      }
                    }
                    return null;
                  },
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Checkbox Admin
              CheckboxListTile(
                title: const Text('Utente Admin'),
                subtitle: const Text('L\'utente avrà accesso amministrativo'),
                value: _isAdmin,
                onChanged: (value) {
                  setState(() {
                    _isAdmin = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                secondary: const Icon(Icons.admin_panel_settings, color: Colors.red),
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
