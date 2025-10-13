class AttendanceRecord {
  final int? id;
  final int employeeId;
  final int? workSiteId;
  final DateTime timestamp;
  final String type; // 'in' or 'out'
  final String deviceInfo;
  final double latitude;
  final double longitude;

  AttendanceRecord({
    this.id,
    required this.employeeId,
    this.workSiteId,
    required this.timestamp,
    required this.type,
    required this.deviceInfo,
    required this.latitude,
    required this.longitude,
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
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'],
      employeeId: map['employeeId'],
      workSiteId: map['workSiteId'],
      timestamp: DateTime.parse(map['timestamp']),
      type: map['type'],
      deviceInfo: map['deviceInfo'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}