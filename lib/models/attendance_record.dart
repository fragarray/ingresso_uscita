class AttendanceRecord {
  final int? id;
  final int employeeId;
  final int? workSiteId;
  final DateTime timestamp;
  final String type; // 'in' or 'out'
  final String deviceInfo;
  final double latitude;
  final double longitude;
  final bool isForced; // Se è una timbratura forzata
  final int? forcedByAdminId; // ID admin che ha forzato

  AttendanceRecord({
    this.id,
    required this.employeeId,
    this.workSiteId,
    required this.timestamp,
    required this.type,
    required this.deviceInfo,
    required this.latitude,
    required this.longitude,
    this.isForced = false,
    this.forcedByAdminId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'workSiteId': workSiteId,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'deviceInfo': deviceInfo,
      'latitude': latitude,
      'longitude': longitude,
      'isForced': isForced ? 1 : 0,
      'forcedByAdminId': forcedByAdminId,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'],
      employeeId: map['employeeId'],
      workSiteId: map['workSiteId'],
      timestamp: DateTime.parse(map['timestamp']),
      type: map['type'],
      deviceInfo: map['deviceInfo'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      isForced: (map['isForced'] ?? 0) == 1,
      forcedByAdminId: map['forcedByAdminId'],
    );
  }
}