import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../models/work_site.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.2:3000/api';

  static Future<Employee?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Employee.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<bool> recordAttendance(AttendanceRecord record) async {
    try {
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
  }) async {
    try {
      print('=== FORCE ATTENDANCE API CALL ===');
      print('Employee ID: $employeeId');
      print('WorkSite ID: $workSiteId');
      print('Type: $type');
      print('Admin ID: $adminId');
      print('Notes: $notes');
      
      final requestBody = {
        'employeeId': employeeId,
        'workSiteId': workSiteId,
        'type': type,
        'adminId': adminId,
        'notes': notes,
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

  static Future<List<Employee>> getEmployees({bool includeInactive = false}) async {
    try {
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
      final response = await http.delete(Uri.parse('$baseUrl/worksites/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Delete worksite error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getWorkSiteDetails(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/worksites/$id/details'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Get worksite details error: $e');
      return null;
    }
  }

  static Future<List<AttendanceRecord>> getAttendanceRecords({int? employeeId}) async {
    try {
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
      print('Attempting to update employee: ${employee.name} (${employee.email})');
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
      final response = await http.delete(Uri.parse('$baseUrl/employees/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Remove employee error: $e');
      return false;
    }
  }

  static Future<String?> downloadExcelReport() async {
    try {
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
      final queryParams = <String, String>{};
      if (employeeId != null) queryParams['employeeId'] = employeeId.toString();
      if (workSiteId != null) queryParams['workSiteId'] = workSiteId.toString();
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (includeInactive) queryParams['includeInactive'] = 'true';

      final uri = Uri.parse('$baseUrl/attendance/report').replace(queryParameters: queryParams);
      
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
}