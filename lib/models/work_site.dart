class WorkSite {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final bool isActive;
  final DateTime? createdAt;
  final double radiusMeters;  // Raggio di validità in metri

  WorkSite({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.isActive = true,
    DateTime? createdAt,
    this.radiusMeters = 100.0,  // Default 100 metri
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
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  factory WorkSite.fromMap(Map<String, dynamic> map) {
    return WorkSite(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
      isActive: map['isActive'] == 1,
      radiusMeters: map['radiusMeters']?.toDouble() ?? 100.0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }
}