class Employee {
  final int? id;
  final String name;
  final String email;
  final String? password;  // Non includiamo la password nella risposta dal server
  final bool isAdmin;
  final bool isActive;
  final DateTime? deletedAt;

  Employee({
    this.id, 
    required this.name, 
    required this.email, 
    this.password,
    this.isAdmin = false,
    this.isActive = true,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'isAdmin': isAdmin ? 1 : 0,
      'isActive': isActive ? 1 : 0,
    };
    
    if (id != null) map['id'] = id;
    if (password != null && password!.isNotEmpty) map['password'] = password;
    if (deletedAt != null) map['deletedAt'] = deletedAt!.toIso8601String();
    
    return map;
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      isAdmin: map['isAdmin'] == 1,
      isActive: (map['isActive'] ?? 1) == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt']) : null,
    );
  }
}