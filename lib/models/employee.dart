class Employee {
  final int? id;
  final String name;
  final String email;
  final String? password;  // Non includiamo la password nella risposta dal server
  final bool isAdmin;

  Employee({
    this.id, 
    required this.name, 
    required this.email, 
    this.password,
    this.isAdmin = false
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'isAdmin': isAdmin ? 1 : 0,
    };
    
    if (id != null) map['id'] = id;
    if (password != null && password!.isNotEmpty) map['password'] = password;
    
    return map;
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      isAdmin: map['isAdmin'] == 1,
    );
  }
}