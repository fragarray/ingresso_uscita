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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void dispose() {
    _nameController.dispose();
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
        email: _emailController.text.trim(),
        password: _passwordController.text,
        isAdmin: _isAdmin,
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
      title: const Text('Aggiungi Dipendente'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Inserire un nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
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
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Minimo 6 caratteri',
              ),
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
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Crea come Admin'),
              subtitle: const Text('L\'utente avrà accesso amministrativo'),
              value: _isAdmin,
              onChanged: (value) {
                setState(() {
                  _isAdmin = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
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