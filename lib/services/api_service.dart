import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/work_site.dart';

class ApiService {
  static const String _defaultBaseUrl = 'http://fragarray.freeddns.it:3000/api';
  static String? _cachedBaseUrl;

  // Get base URL from SharedPreferences or use default
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;

    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('serverIp');
    final savedPort = prefs.getInt('serverPort') ?? 3000;
    
    _cachedBaseUrl = savedIp != null
        ? 'http://$savedIp:$savedPort/api'
        : _defaultBaseUrl;
    return _cachedBaseUrl!;
  }

  // Set new server IP
  static Future<void> setServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIp', ip);
    
    final savedPort = prefs.getInt('serverPort') ?? 3000;
    _cachedBaseUrl = 'http://$ip:$savedPort/api';
  }

  // Set new server port
  static Future<void> setServerPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('serverPort', port);
    
    final savedIp = prefs.getString('serverIp');
    if (savedIp != null) {
      _cachedBaseUrl = 'http://$savedIp:$port/api';
    } else {
      // Usa il default IP con la nuova porta
      final uri = Uri.parse(_defaultBaseUrl);
      _cachedBaseUrl = 'http://${uri.host}:$port/api';
    }
  }

  // Get default server IP (without port)
  static String getDefaultServerIp() {
    // Estrae l'IP da _defaultBaseUrl
    final uri = Uri.parse(_defaultBaseUrl);
    return uri.host;
  }

  // Test server connection and validate identity
  static Future<Map<String, dynamic>> pingServer(String ip, [int? port]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverPort = port ?? prefs.getInt('serverPort') ?? 3000;
      
      final testUrl = 'http://$ip:$serverPort/api/ping';
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Verifica che sia il nostro server
        if (data['serverIdentity'] == 'ingresso-uscita-server') {
          return {
            'success': true,
            'message': data['message'] ?? 'Server connesso',
            'version': data['version'] ?? 'N/A',
            'timestamp': data['timestamp'] ?? '',
          };
        } else {
          return {
            'success': false,
            'error': 'Server non riconosciuto (identità non valida)',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server risponde con codice ${response.statusCode}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Impossibile raggiungere il server (connessione rifiutata)',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Timeout: il server non risponde entro 5 secondi',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Errore di connessione: ${e.toString()}',
      };
    }
  }

  static Future<Employee?> login(String email, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Employee.fromMap(data);
      } else if (response.statusCode == 403) {
        // Account eliminato (soft delete)
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Account non più attivo');
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      rethrow; // Rilancia l'eccezione per gestirla nel widget
    }
  }

  static Future<bool> recordAttendance(AttendanceRecord record) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(record.toMap()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Record attendance error: $e');
      return false;
    }
  }

  static Future<bool> forceAttendance({
    required int employeeId,
    required int workSiteId,
    required String type,
    required int adminId,
    String? notes,
    DateTime? timestamp,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      print('=== FORCE ATTENDANCE API CALL ===');
      print('Employee ID: $employeeId');
      print('WorkSite ID: $workSiteId');
      print('Type: $type');
      print('Admin ID: $adminId');
      print('Notes: $notes');
      print('Custom Timestamp: $timestamp');

      final requestBody = {
        'employeeId': employeeId,
        'workSiteId': workSiteId,
        'type': type,
        'adminId': adminId,
        'notes': notes,
        'timestamp': timestamp?.toIso8601String(),
      };
      print('Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/force'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final success = response.statusCode == 200;
      print('Force attendance success: $success');
      return success;
    } catch (e) {
      print('Force attendance error: $e');
      return false;
    }
  }

  // Modifica una timbratura esistente
  static Future<bool> editAttendance({
    required int recordId,
    required int adminId,
    DateTime? timestamp,
    int? workSiteId,
    String? notes,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      print('=== EDIT ATTENDANCE API CALL ===');
      print('Record ID: $recordId');
      print('Admin ID: $adminId');
      print('New Timestamp: $timestamp');
      print('New WorkSite ID: $workSiteId');
      print('New Notes: $notes');

      final requestBody = {
        'adminId': adminId,
        if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        if (workSiteId != null) 'workSiteId': workSiteId,
        if (notes != null) 'notes': notes,
      };
      print('Request body: ${json.encode(requestBody)}');

      final response = await http.put(
        Uri.parse('$baseUrl/attendance/$recordId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final success = response.statusCode == 200;
      print('Edit attendance success: $success');
      return success;
    } catch (e) {
      print('Edit attendance error: $e');
      return false;
    }
  }

  // Elimina una timbratura esistente
  static Future<bool> deleteAttendance({
    required int recordId,
    required int adminId,
    bool deleteOutToo = false,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      print('=== DELETE ATTENDANCE API CALL ===');
      print('Record ID: $recordId');
      print('Admin ID: $adminId');
      print('Delete OUT too: $deleteOutToo');

      final requestBody = {
        'adminId': adminId,
        'deleteOutToo': deleteOutToo,
      };
      print('Request body: ${json.encode(requestBody)}');

      final response = await http.delete(
        Uri.parse('$baseUrl/attendance/$recordId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final success = response.statusCode == 200;
      print('Delete attendance success: $success');
      return success;
    } catch (e) {
      print('Delete attendance error: $e');
      return false;
    }
  }

  static Future<List<Employee>> getEmployees({
    bool includeInactive = false,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = includeInactive
          ? Uri.parse('$baseUrl/employees?includeInactive=true')
          : Uri.parse('$baseUrl/employees');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Employee.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get employees error: $e');
      return [];
    }
  }

  static Future<List<WorkSite>> getWorkSites() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/worksites'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WorkSite.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get worksites error: $e');
      return [];
    }
  }

  static Future<bool> addWorkSite(WorkSite workSite) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/worksites'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(workSite.toMap()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Add worksite error: $e');
      return false;
    }
  }

  static Future<bool> updateWorkSite(WorkSite workSite) async {
    try {
      final baseUrl = await getBaseUrl();
      print('Updating worksite: ${workSite.id}');
      final workSiteData = workSite.toMap();
      print('WorkSite data: ${json.encode(workSiteData)}');

      final response = await http.put(
        Uri.parse('$baseUrl/worksites/${workSite.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(workSiteData),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Update worksite error: $e');
      return false;
    }
  }

  static Future<bool> deleteWorkSite(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.delete(Uri.parse('$baseUrl/worksites/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Delete worksite error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getWorkSiteDetails(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/worksites/$id/details'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Get worksite details error: $e');
      return null;
    }
  }

  static Future<List<AttendanceRecord>> getAttendanceRecords({
    int? employeeId,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final Uri uri = employeeId != null
          ? Uri.parse('$baseUrl/attendance?employeeId=$employeeId')
          : Uri.parse('$baseUrl/attendance');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AttendanceRecord.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get attendance records error: $e');
      return [];
    }
  }

  static Future<bool> addEmployee(Employee employee) async {
    try {
      final baseUrl = await getBaseUrl();
      print('Attempting to add employee: ${employee.name} (${employee.email})');
      print('Request URL: $baseUrl/employees');
      final employeeData = employee.toMap();
      print('Request body: ${json.encode(employeeData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(employeeData),
      );

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      print('Add employee error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> updateEmployee(Employee employee) async {
    try {
      final baseUrl = await getBaseUrl();
      print(
        'Attempting to update employee: ${employee.name} (${employee.email})',
      );
      print('Request URL: $baseUrl/employees/${employee.id}');
      final employeeData = employee.toMap();
      print('Request body: ${json.encode(employeeData)}');

      final response = await http.put(
        Uri.parse('$baseUrl/employees/${employee.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(employeeData),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      print('Update employee error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> removeEmployee(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.delete(Uri.parse('$baseUrl/employees/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Remove employee error: $e');
      return false;
    }
  }

  static Future<String?> downloadExcelReport() async {
    try {
      final baseUrl = await getBaseUrl();
      print('Downloading report from: $baseUrl/attendance/report');
      final response = await http.get(Uri.parse('$baseUrl/attendance/report'));
      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('Response size: ${bytes.length} bytes');

        final dir = await getApplicationDocumentsDirectory();
        print('Saving to directory: ${dir.path}');

        final file = File('${dir.path}/report_presenze.xlsx');
        await file.writeAsBytes(bytes);
        print('File saved to: ${file.path}');

        return file.path;
      } else {
        print('Error response body: ${response.body}');
      }
      return null;
    } catch (e, stackTrace) {
      print('Download report error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<String?> downloadExcelReportFiltered({
    int? employeeId,
    int? workSiteId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeInactive = false,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{};
      if (employeeId != null) queryParams['employeeId'] = employeeId.toString();
      if (workSiteId != null) queryParams['workSiteId'] = workSiteId.toString();
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (includeInactive) queryParams['includeInactive'] = 'true';

      final uri = Uri.parse(
        '$baseUrl/attendance/report',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/report_presenze_filtered.xlsx');
        await file.writeAsBytes(bytes);
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download filtered report error: $e');
      return null;
    }
  }

  // Download report ore dipendente con calcolo ore lavorate
  static Future<String?> downloadEmployeeHoursReport({
    required int employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{'employeeId': employeeId.toString()};
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/attendance/hours-report',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/report_ore_dipendente_$timestamp.xlsx');
        await file.writeAsBytes(bytes);
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download hours report error: $e');
      return null;
    }
  }

  // Download report cantiere con statistiche avanzate
  static Future<String?> downloadWorkSiteReport({
    int? workSiteId,
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{};
      if (workSiteId != null) queryParams['workSiteId'] = workSiteId.toString();
      if (employeeId != null) queryParams['employeeId'] = employeeId.toString();
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/worksite/report',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/report_cantiere_$timestamp.xlsx');
        await file.writeAsBytes(bytes);
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download worksite report error: $e');
      return null;
    }
  }

  // Download report timbrature forzate
  static Future<String?> downloadForcedAttendanceReport({
    int? employeeId,
    int? workSiteId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{};
      if (employeeId != null) queryParams['employeeId'] = employeeId.toString();
      if (workSiteId != null) queryParams['workSiteId'] = workSiteId.toString();
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/attendance/forced-report',
      ).replace(queryParameters: queryParams);

      print('Requesting forced attendance report: $uri');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File(
          '${dir.path}/report_timbrature_forzate_$timestamp.xlsx',
        );
        await file.writeAsBytes(bytes);
        print('Forced attendance report saved: ${file.path}');
        return file.path;
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Download forced attendance report error: $e');
      return null;
    }
  }

  // Download report audit amministratore
  static Future<String?> downloadAdminAuditReport({
    required int adminId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{
        'adminId': adminId.toString(),
      };
      if (startDate != null) {
        queryParams['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      final uri = Uri.parse(
        '$baseUrl/admin/audit-report',
      ).replace(queryParameters: queryParams);

      print('📋 Requesting admin audit report: $uri');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File(
          '${dir.path}/report_audit_admin_$timestamp.xlsx',
        );
        await file.writeAsBytes(bytes);
        print('✅ Admin audit report saved: ${file.path}');
        return file.path;
      } else {
        print('❌ Error response: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Download admin audit report error: $e');
      return null;
    }
  }

  // ==================== APP SETTINGS (GPS ACCURACY, ETC.) ====================

  // Ottieni impostazione dal server
  static Future<String?> getSetting(String key) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/settings/$key'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['value'] as String?;
      }
      return null;
    } catch (e) {
      print('Get setting error: $e');
      return null;
    }
  }

  // Aggiorna impostazione sul server (solo admin)
  static Future<bool> updateSetting({
    required String key,
    required String value,
    required int adminId,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/settings/$key'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'value': value,
          'adminId': adminId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Setting updated: ${data['updatedBy']} changed $key to $value');
        return true;
      }
      return false;
    } catch (e) {
      print('Update setting error: $e');
      return false;
    }
  }

  // Ottieni tutte le impostazioni
  static Future<Map<String, dynamic>?> getAllSettings() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/settings'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get all settings error: $e');
      return null;
    }
  }

  // ==================== BACKUP DATABASE ====================

  static Future<Map<String, dynamic>?> getBackupSettings() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/backup/settings'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Get backup settings error: $e');
      return null;
    }
  }

  static Future<bool> saveBackupSettings({
    required bool autoBackupEnabled,
    required int autoBackupDays,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/backup/settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'autoBackupEnabled': autoBackupEnabled,
          'autoBackupDays': autoBackupDays,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Save backup settings error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createBackup() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(Uri.parse('$baseUrl/backup/create'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Create backup error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/backup/list'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('List backups error: $e');
      return [];
    }
  }

  static Future<String?> downloadBackup(String fileName) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/backup/download/$fileName'),
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      }
      return null;
    } catch (e) {
      print('Download backup error: $e');
      return null;
    }
  }

  static Future<bool> deleteBackup(String fileName) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.delete(
        Uri.parse('$baseUrl/backup/$fileName'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete backup error: $e');
      return false;
    }
  }

  // Restore database from backup file
  static Future<Map<String, dynamic>?> restoreBackup(List<int> fileBytes, String fileName) async {
    try {
      final baseUrl = await getBaseUrl();

      // Verifica estensione .db
      if (!fileName.toLowerCase().endsWith('.db')) {
        return {'success': false, 'error': 'Il file deve avere estensione .db'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/backup/restore'),
      );

      // Usa fromBytes invece di fromPath per compatibilità cross-platform
      request.files.add(
        http.MultipartFile.fromBytes(
          'database',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Errore sconosciuto',
        };
      }
    } catch (e) {
      print('Restore backup error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
