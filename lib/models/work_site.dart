class WorkSite {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final bool isActive;
  final DateTime? createdAt;
  final double radiusMeters;  // Raggio di validità in metri
  final String? description;  // Descrizione del cantiere

  WorkSite({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.isActive = true,
    DateTime? createdAt,
    this.radiusMeters = 100.0,  // Default 100 metri
    this.description,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'isActive': isActive ? 1 : 0,
      'radiusMeters': radiusMeters,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  factory WorkSite.fromMap(Map<String, dynamic> map) {
    return WorkSite(
      id: map['id'],
      name: map['name'],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'],
      isActive: map['isActive'] == 1,
      radiusMeters: map['radiusMeters'] != null 
          ? (map['radiusMeters'] as num).toDouble() 
          : 100.0,
      description: map['description'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }
}