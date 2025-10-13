import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/attendance_record.dart';
import 'package:location/location.dart';
import 'dart:io';

class LocalService {
  static Database? _database;
  static final Location _location = Location();

  static Future<void> init() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE employees(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT UNIQUE,
            isAdmin INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employeeId INTEGER,
            timestamp TEXT,
            type TEXT,
            deviceInfo TEXT,
            latitude REAL,
            longitude REAL,
            FOREIGN KEY (employeeId) REFERENCES employees (id)
          )
        ''');

        // Create default admin account
        await db.insert('employees', {
          'name': 'Admin',
          'email': 'admin@example.com',
          'isAdmin': 1
        });
      },
    );
  }

  static Future<Employee?> login(String email) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'employees',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  static Future<bool> recordAttendance(Employee employee, String type) async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return false;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return false;
      }

      final LocationData locationData = await _location.getLocation();
      
      final record = AttendanceRecord(
        employeeId: employee.id!,
        timestamp: DateTime.now(),
        type: type,
        deviceInfo: '${Platform.operatingSystem} - ${Platform.operatingSystemVersion}',
        latitude: locationData.latitude ?? 0,
        longitude: locationData.longitude ?? 0,
      );

      await _database!.insert('attendance_records', record.toMap());
      return true;
    } catch (e) {
      print('Error recording attendance: $e');
      return false;
    }
  }

  static Future<List<Employee>> getAllEmployees() async {
    final List<Map<String, dynamic>> maps = await _database!.query('employees');
    return List.generate(maps.length, (i) => Employee.fromMap(maps[i]));
  }

  static Future<List<AttendanceRecord>> getAttendanceRecords({int? employeeId}) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'attendance_records',
      where: employeeId != null ? 'employeeId = ?' : null,
      whereArgs: employeeId != null ? [employeeId] : null,
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) => AttendanceRecord.fromMap(maps[i]));
  }

  static Future<bool> addEmployee(Employee employee) async {
    try {
      await _database!.insert('employees', employee.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeEmployee(int id) async {
    try {
      await _database!.delete(
        'employees',
        where: 'id = ? AND isAdmin = 0',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}