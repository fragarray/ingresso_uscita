// Enum per ruoli utente
enum EmployeeRole {
  admin,      // Amministratore: accesso completo
  employee,   // Dipendente: timbratura e visualizzazione proprie presenze
  foreman,    // Capocantiere: visualizza report cantieri assegnati
}

class Employee {
  final int? id;
  final String name;
  final String username;        // Username per login (REQUIRED, UNIQUE)
  final String? email;          // Email opzionale (obbligatoria solo per admin per report)
  final String? password;       // Non includiamo la password nella risposta dal server
  final EmployeeRole role;      // Ruolo: admin, employee, foreman
  final bool isAdmin;           // Deprecato: mantenuto per compatibilità, usa role invece
  final bool isActive;
  final DateTime? deletedAt;
  final bool allowNightShift;   // Autorizzazione turni notturni oltre mezzanotte

  Employee({
    this.id, 
    required this.name,
    required this.username,
    this.email,
    this.password,
    this.role = EmployeeRole.employee,
    bool? isAdmin,  // Auto-calcolato da role se null
    this.isActive = true,
    this.deletedAt,
    this.allowNightShift = false,
  }) : isAdmin = isAdmin ?? (role == EmployeeRole.admin);

  // Helper per verificare ruolo
  bool get isAdministrator => role == EmployeeRole.admin;
  bool get isRegularEmployee => role == EmployeeRole.employee;
  bool get isForeman => role == EmployeeRole.foreman;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'username': username,
      'role': role.name, // Salva come stringa: 'admin', 'employee', 'foreman'
      'isAdmin': isAdmin ? 1 : 0,  // Mantenuto per compatibilità
      'isActive': isActive ? 1 : 0,
      'allowNightShift': allowNightShift ? 1 : 0,
    };
    
    if (id != null) map['id'] = id;
    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (password != null && password!.isNotEmpty) map['password'] = password;
    if (deletedAt != null) map['deletedAt'] = deletedAt!.toIso8601String();
    
    return map;
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    // Parsing role da stringa
    EmployeeRole parsedRole = EmployeeRole.employee; // Default
    if (map['role'] != null) {
      final roleStr = map['role'].toString().toLowerCase();
      if (roleStr == 'admin') {
        parsedRole = EmployeeRole.admin;
      } else if (roleStr == 'foreman') {
        parsedRole = EmployeeRole.foreman;
      } else {
        parsedRole = EmployeeRole.employee;
      }
    } else if (map['isAdmin'] == 1) {
      // Fallback: se role non esiste ma isAdmin=1, imposta admin
      parsedRole = EmployeeRole.admin;
    }

    return Employee(
      id: map['id'],
      name: map['name'],
      username: map['username'] ?? map['email']?.split('@')[0] ?? 'user${map['id']}', // Fallback per migrazione
      email: map['email'],
      role: parsedRole,
      isAdmin: map['isAdmin'] == 1,
      isActive: (map['isActive'] ?? 1) == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt']) : null,
      allowNightShift: (map['allowNightShift'] ?? 0) == 1,
    );
  }

  // Helper per display role in UI
  String get roleDisplayName {
    switch (role) {
      case EmployeeRole.admin:
        return 'Amministratore';
      case EmployeeRole.foreman:
        return 'Capocantiere';
      case EmployeeRole.employee:
        return 'Dipendente';
    }
  }
}