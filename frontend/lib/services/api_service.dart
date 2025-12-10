import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../models/maintenance_issue.dart';
import '../models/mahal_booking.dart';
import '../models/billing_details.dart';
import '../models/catering_details.dart';
import '../models/expense_details.dart';
import '../models/vehicle_license.dart';
import '../models/driver_license.dart';
import '../models/engine_oil_service.dart';

import '../config/env_config.dart';

class ApiService {
  static String get baseUrl => EnvConfig.apiEndpoint;

  // Authentication
  static Future<Map<String, dynamic>> login(String username, String password, {String? company}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
        if (company != null) 'company': company,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    String errorMessage = 'Login failed';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      } else {
        errorMessage = response.body;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Login failed';
    }
    throw Exception(errorMessage);
  }

  // Employees
  static Future<List<Employee>> getEmployees() async {
    try {
      final url = '$baseUrl/employees';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final employees = data.map((json) => Employee.fromJson(json)).toList();
        return employees;
      } else {
        throw Exception('Failed to load employees: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Employee>> getEmployeesBySector(String sectorCode) async {
    final response = await http.get(Uri.parse('$baseUrl/employees/sector/$sectorCode'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Employee.fromJson(json)).toList();
    }
    throw Exception('Failed to load employees by sector');
  }

  static Future<Employee> createEmployee(Employee employee) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employees'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(employee.toJson()),
    );
    if (response.statusCode == 201) {
      return Employee.fromJson(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to create employee';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      } else {
        errorMessage = response.body;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create employee';
    }
    throw Exception(errorMessage);
  }

  static Future<Employee> updateEmployee(Employee employee) async {
    final response = await http.put(
      Uri.parse('$baseUrl/employees/${employee.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(employee.toJson()),
    );
    if (response.statusCode == 200) {
      return Employee.fromJson(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to update employee';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      } else {
        errorMessage = response.body;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update employee';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteEmployee(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/employees/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete employee';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete employee';
    }
    throw Exception(errorMessage);
  }

  // Sectors
  static Future<List<Sector>> getSectors() async {
    final response = await http.get(Uri.parse('$baseUrl/sectors'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Sector.fromJson(json)).toList();
    }
    throw Exception('Failed to load sectors');
  }

  static Future<Sector> createSector(Sector sector) async {
    try {
      
      final response = await http.post(
        Uri.parse('$baseUrl/sectors'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': sector.code, 'name': sector.name}),
      );
      
      
      if (response.statusCode == 201) {
        return Sector.fromJson(json.decode(response.body));
      }
      
      // Extract error message from response body
      String errorMessage = 'Failed to create sector';
      String fullErrorDetails = 'Status: ${response.statusCode}\nBody: ${response.body}';
      
      try {
        if (response.body.isNotEmpty) {
          final errorBody = json.decode(response.body);
          
          if (errorBody is Map<String, dynamic>) {
            // Try message first (most common format)
            if (errorBody.containsKey('message') && errorBody['message'] != null) {
              errorMessage = errorBody['message'].toString();
            } 
            // Try error field
            else if (errorBody.containsKey('error') && errorBody['error'] != null) {
              errorMessage = errorBody['error'].toString();
            } 
            // Try any string value in the map
            else if (errorBody.isNotEmpty) {
              for (var value in errorBody.values) {
                if (value is String && value.isNotEmpty) {
                  errorMessage = value;
                  break;
                }
              }
            }
            // Include full error details
            fullErrorDetails = 'Status: ${response.statusCode}\n${errorBody.toString()}';
          } else if (errorBody is String) {
            errorMessage = errorBody;
            fullErrorDetails = 'Status: ${response.statusCode}\n$errorBody';
          } else {
            errorMessage = response.body;
          }
        } else {
          errorMessage = 'Failed to create sector (HTTP ${response.statusCode})';
        }
      } catch (e) {
        errorMessage = response.body.isNotEmpty 
            ? response.body 
            : 'Failed to create sector (HTTP ${response.statusCode})';
        fullErrorDetails = 'Status: ${response.statusCode}\nParse Error: $e\nBody: ${response.body}';
      }
      
      // Store full details in exception message for debugging
      throw Exception('$errorMessage\n\n[Debug: $fullErrorDetails]');
    } on SocketException {
      throw Exception('Network error: Unable to connect to server. Please check your internet connection and ensure the backend is running at $baseUrl');
    } on HttpException catch (e) {
      throw Exception('HTTP error: ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: ${e.toString()}');
    }
  }

  static Future<void> deleteSector(String code) async {
    final response = await http.delete(Uri.parse('$baseUrl/sectors/$code'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete sector');
    }
  }

  // Attendance
  static Future<List<Map<String, dynamic>>> getAttendance({
    String? sector,
    int? month,
    String? date,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (month != null) queryParams['month'] = month.toString();
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$baseUrl/attendance').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load attendance');
  }

  static Future<double> getOutstandingAdvance(String employeeId, String date) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/outstanding/$employeeId/$date'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['outstanding_advance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0; // Return 0 if no previous record found
  }

  static Future<double> getBulkAdvance(String employeeId, String date) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/bulk-advance/$employeeId/$date'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['bulk_advance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0; // Return 0 if no previous record found
  }

  static Future<Map<String, dynamic>> saveAttendance(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to save attendance');
  }

  static Future<List<Map<String, dynamic>>> bulkSaveAttendance(
    List<Map<String, dynamic>> records,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'attendance_records': records}),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to bulk save attendance');
  }

  // Salary Expenses
  static Future<List<Map<String, dynamic>>> getSalaryExpenses({
    String? sector,
    String? weekStart,
    String? weekEnd,
    String? employeeId,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (weekStart != null) queryParams['week_start'] = weekStart;
    if (weekEnd != null) queryParams['week_end'] = weekEnd;
    if (employeeId != null) queryParams['employee_id'] = employeeId;

    final uri = Uri.parse('$baseUrl/salary-expenses').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load salary expenses');
  }

  static Future<Map<String, dynamic>> saveSalaryExpense(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/salary-expenses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to save salary expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save salary expense';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteSalaryExpense(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/salary-expenses/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Extract error message from response body
    String errorMessage = 'Failed to delete salary expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete salary expense';
    }
    throw Exception(errorMessage);
  }

  static Future<List<Map<String, dynamic>>> bulkSaveSalaryExpenses(
    List<Map<String, dynamic>> records,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/salary-expenses/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'salary_records': records}),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to save salary expenses';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save salary expenses';
    }
    throw Exception(errorMessage);
  }

  // Daily Production
  static Future<List<Map<String, dynamic>>> getDailyProduction({String? month, String? date}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$baseUrl/daily-production').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load daily production');
  }

  static Future<Map<String, dynamic>> saveDailyProduction(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-production'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to save daily production';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save daily production';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteDailyProduction(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/daily-production/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Extract error message from response body
    String errorMessage = 'Failed to delete daily production';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete daily production';
    }
    throw Exception(errorMessage);
  }

  // Contract Employees
  static Future<List<Map<String, dynamic>>> getContractEmployees({String? date}) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$baseUrl/contract-employees').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load contract employees');
  }

  static Future<Map<String, dynamic>> createContractEmployee(Map<String, dynamic> contractEmployee) async {
    final response = await http.post(
      Uri.parse('$baseUrl/contract-employees'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contractEmployee),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to create contract employee';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create contract employee';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateContractEmployee(String id, Map<String, dynamic> contractEmployee) async {
    final response = await http.put(
      Uri.parse('$baseUrl/contract-employees/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contractEmployee),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to update contract employee';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update contract employee';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteContractEmployee(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/contract-employees/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete contract employee');
    }
  }

  // Products
  static Future<List<Map<String, dynamic>>> getProducts({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load products');
  }

  static Future<Map<String, dynamic>> createProduct(String productName, String sectorCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'product_name': productName,
        'sector_code': sectorCode,
      }),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to create product';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create product';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateProduct(String id, String productName, String sectorCode) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'product_name': productName,
        'sector_code': sectorCode,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to update product';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update product';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteProduct(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/products/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Extract error message from response body
    String errorMessage = 'Failed to delete product';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete product';
    }
    throw Exception(errorMessage);
  }

  // Rent Vehicles
  static Future<List<Map<String, dynamic>>> getRentVehicles({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/rent-vehicles').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load rent vehicles');
  }

  static Future<Map<String, dynamic>> createRentVehicle(String vehicleName, String sectorCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rent-vehicles'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'vehicle_name': vehicleName,
        'sector_code': sectorCode,
      }),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to create rent vehicle';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create rent vehicle';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateRentVehicle(String id, String vehicleName, String sectorCode) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rent-vehicles/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'vehicle_name': vehicleName,
        'sector_code': sectorCode,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to update rent vehicle';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update rent vehicle';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteRentVehicle(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/rent-vehicles/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Extract error message from response body
    String errorMessage = 'Failed to delete rent vehicle';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete rent vehicle';
    }
    throw Exception(errorMessage);
  }

  // Rent Vehicle Attendance
  static Future<List<Map<String, dynamic>>> getRentVehicleAttendance({String? sector, int? month, String? date}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (month != null) queryParams['month'] = month.toString();
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$baseUrl/rent-vehicle-attendance').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load rent vehicle attendance');
  }

  static Future<Map<String, dynamic>> saveRentVehicleAttendance({
    required int vehicleId,
    required String vehicleName,
    required String sectorCode,
    required String date,
    String? status,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rent-vehicle-attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'vehicle_id': vehicleId,
        'vehicle_name': vehicleName,
        'sector_code': sectorCode,
        'date': date,
        'status': status,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    throw Exception('Failed to save rent vehicle attendance');
  }

  static Future<List<Map<String, dynamic>>> bulkSaveRentVehicleAttendance(List<Map<String, dynamic>> records) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rent-vehicle-attendance/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'records': records}),
    );
    if (response.statusCode == 201) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to bulk save rent vehicle attendance');
  }

  // Daily Expenses
  static Future<List<Map<String, dynamic>>> getDailyExpenses({String? month, String? date, String? sector}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (date != null) queryParams['date'] = date;
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/daily-expenses').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load daily expenses');
  }

  static Future<Map<String, dynamic>> saveDailyExpense(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-expenses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    // Extract error message from response body
    String errorMessage = 'Failed to save daily expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save daily expense';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteDailyExpense(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/daily-expenses/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    // Extract error message from response body
    String errorMessage = 'Failed to delete daily expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete daily expense';
    }
    throw Exception(errorMessage);
  }

  // Maintenance Issues
  static Future<List<MaintenanceIssue>> getMaintenanceIssues({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/maintenance-issues').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => MaintenanceIssue.fromJson(json)).toList();
    }
    throw Exception('Failed to load maintenance issues');
  }

  static Future<MaintenanceIssue> createMaintenanceIssue({
    String? issueDescription,
    DateTime? dateCreated,
    File? imageFile,
    String? status,
    DateTime? dateResolved,
    required String sectorCode,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/maintenance-issues'),
    );

    request.fields['issue_description'] = issueDescription ?? '';
    if (dateCreated != null) {
      request.fields['date_created'] = dateCreated.toIso8601String().split('T')[0];
    }
    request.fields['status'] = status ?? 'Not resolved';
    if (dateResolved != null) {
      request.fields['date_resolved'] = dateResolved.toIso8601String().split('T')[0];
    }
    request.fields['sector_code'] = sectorCode;

    if (imageFile != null && await imageFile.exists()) {
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return MaintenanceIssue.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create maintenance issue';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create maintenance issue';
    }
    throw Exception(errorMessage);
  }

  static Future<MaintenanceIssue> updateMaintenanceIssue({
    required int id,
    String? issueDescription,
    DateTime? dateCreated,
    String? status,
    DateTime? dateResolved,
    required String sectorCode,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/maintenance-issues/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'issue_description': issueDescription,
        'date_created': dateCreated?.toIso8601String().split('T')[0],
        'status': status ?? 'Not resolved',
        'date_resolved': dateResolved?.toIso8601String().split('T')[0],
        'sector_code': sectorCode,
      }),
    );
    if (response.statusCode == 200) {
      return MaintenanceIssue.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update maintenance issue';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update maintenance issue';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteMaintenanceIssue(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance-issues/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete maintenance issue';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete maintenance issue';
    }
    throw Exception(errorMessage);
  }

  // Upload multiple photos for a maintenance issue
  static Future<List<Map<String, dynamic>>> uploadMaintenanceIssuePhotos({
    required int issueId,
    required List<File> photoFiles,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/maintenance-issues/$issueId/photos'),
    );

    for (final file in photoFiles) {
      if (await file.exists()) {
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final multipartFile = http.MultipartFile(
          'photos',
          fileStream,
          fileLength,
          filename: file.path.split('/').last.split('\\').last,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return List<Map<String, dynamic>>.from(responseData['photos'] ?? []);
    }
    String errorMessage = 'Failed to upload photos';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to upload photos';
    }
    throw Exception(errorMessage);
  }

  // Get photos for a maintenance issue
  static Future<List<Map<String, dynamic>>> getMaintenanceIssuePhotos(int issueId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance-issues/$issueId/photos'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => json as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load photos');
  }

  // Delete a photo
  static Future<void> deleteMaintenanceIssuePhoto(int photoId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance-issues/photos/$photoId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete photo';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete photo';
    }
    throw Exception(errorMessage);
  }

  // Mahal Bookings API methods
  static Future<List<MahalBooking>> getMahalBookings({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/mahal-bookings').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => MahalBooking.fromJson(json)).toList();
    }
    throw Exception('Failed to load mahal bookings');
  }

  static Future<MahalBooking> createMahalBooking(MahalBooking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mahal-bookings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(booking.toJson()),
    );
    if (response.statusCode == 201) {
      return MahalBooking.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create mahal booking';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create mahal booking';
    }
    throw Exception(errorMessage);
  }

  static Future<MahalBooking> updateMahalBooking(MahalBooking booking) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mahal-bookings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(booking.toJson()),
    );
    if (response.statusCode == 201) {
      return MahalBooking.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update mahal booking';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update mahal booking';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteMahalBooking(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/mahal-bookings/$bookingId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete event details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete event details';
    }
    throw Exception(errorMessage);
  }

  // Billing Details API methods
  static Future<List<BillingDetails>> getBillingDetails({String? bookingId}) async {
    final queryParams = <String, String>{};
    if (bookingId != null) queryParams['booking_id'] = bookingId;

    final uri = Uri.parse('$baseUrl/billing-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BillingDetails.fromJson(json)).toList();
    }
    throw Exception('Failed to load billing details');
  }

  static Future<BillingDetails> createBillingDetails(BillingDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/billing-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return BillingDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create billing details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create billing details';
    }
    throw Exception(errorMessage);
  }

  static Future<BillingDetails> updateBillingDetails(BillingDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/billing-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return BillingDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update billing details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update billing details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteBillingDetails(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/billing-details/$bookingId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete billing details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete billing details';
    }
    throw Exception(errorMessage);
  }

  // Catering Details API methods
  static Future<List<CateringDetails>> getCateringDetails({String? bookingId}) async {
    final queryParams = <String, String>{};
    if (bookingId != null) queryParams['booking_id'] = bookingId;

    final uri = Uri.parse('$baseUrl/catering-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CateringDetails.fromJson(json)).toList();
    }
    throw Exception('Failed to load catering details');
  }

  static Future<CateringDetails> createCateringDetails(CateringDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/catering-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return CateringDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create catering details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create catering details';
    }
    throw Exception(errorMessage);
  }

  static Future<CateringDetails> updateCateringDetails(CateringDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/catering-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return CateringDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update catering details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update catering details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteCateringDetails(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/catering-details/$bookingId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete catering details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete catering details';
    }
    throw Exception(errorMessage);
  }

  // Expense Details API methods
  static Future<List<ExpenseDetails>> getExpenseDetails({String? bookingId}) async {
    final queryParams = <String, String>{};
    if (bookingId != null) queryParams['booking_id'] = bookingId;

    final uri = Uri.parse('$baseUrl/expense-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ExpenseDetails.fromJson(json)).toList();
    }
    throw Exception('Failed to load expense details');
  }

  static Future<ExpenseDetails> createExpenseDetails(ExpenseDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expense-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return ExpenseDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create expense details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create expense details';
    }
    throw Exception(errorMessage);
  }

  static Future<ExpenseDetails> updateExpenseDetails(ExpenseDetails details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expense-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(details.toJson()),
    );
    if (response.statusCode == 201) {
      return ExpenseDetails.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update expense details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update expense details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteExpenseDetails(String bookingId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/expense-details/$bookingId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete expense details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete expense details';
    }
    throw Exception(errorMessage);
  }

  // Credit Details
  static Future<List<Map<String, dynamic>>> getCreditDetails({
    String? sector,
    String? date,
    String? month,
    String? companyStaff,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (date != null) queryParams['date'] = date;
    if (month != null) queryParams['month'] = month;
    if (companyStaff != null) queryParams['company_staff'] = companyStaff;

    final uri = Uri.parse('$baseUrl/credit-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to load credit details');
  }

  static Future<Map<String, dynamic>> saveCreditDetails(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/credit-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save credit details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save credit details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteCreditDetails(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/credit-details/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete credit details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete credit details';
    }
    throw Exception(errorMessage);
  }

  // Sales Details
  static Future<List<Map<String, dynamic>>> getSalesDetails({
    String? sector,
    String? date,
    String? month,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (date != null) queryParams['date'] = date;
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/sales-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch sales details: ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> getCreditDetailsFromSales({
    String? sector,
    String? companyStaff,
    String? month,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (companyStaff != null) queryParams['company_staff'] = companyStaff;
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/sales-details/credits').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch credit details from sales: ${response.body}');
  }

  static Future<Map<String, dynamic>> saveSalesDetails(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save sales details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save sales details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteSalesDetails(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sales-details/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete sales details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete sales details';
    }
    throw Exception(errorMessage);
  }

  // Company Purchase Details
  static Future<List<Map<String, dynamic>>> getCompanyPurchaseDetails({
    String? sector,
    String? date,
    String? month,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (date != null) queryParams['date'] = date;
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/company-purchase-details').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch company purchase details: ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> getCreditDetailsFromCompanyPurchases({
    String? sector,
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/company-purchase-details/credits').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch credit details from company purchases: ${response.body}');
  }

  static Future<Map<String, dynamic>> saveCompanyPurchaseDetails(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/company-purchase-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save company purchase details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save company purchase details';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteCompanyPurchaseDetails(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/company-purchase-details/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete company purchase details';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete company purchase details';
    }
    throw Exception(errorMessage);
  }

  // Upload photos for company purchase
  static Future<List<Map<String, dynamic>>> uploadCompanyPurchasePhotos({
    required int purchaseId,
    required List<File> photoFiles,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/company-purchase-details/$purchaseId/photos'),
    );

    for (final file in photoFiles) {
      if (await file.exists()) {
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        final multipartFile = http.MultipartFile(
          'photos',
          fileStream,
          fileLength,
          filename: file.path.split('/').last.split('\\').last,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return List<Map<String, dynamic>>.from(responseData['photos'] ?? []);
    }
    String errorMessage = 'Failed to upload photos';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to upload photos';
    }
    throw Exception(errorMessage);
  }

  // Get photos for company purchase
  static Future<List<Map<String, dynamic>>> getCompanyPurchasePhotos(int purchaseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company-purchase-details/$purchaseId/photos'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch photos: ${response.body}');
  }

  // Delete a photo
  static Future<void> deleteCompanyPurchasePhoto(int photoId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/company-purchase-details/photos/$photoId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete photo';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete photo';
    }
    throw Exception(errorMessage);
  }

  // Sales Balance Payments
  static Future<List<Map<String, dynamic>>> getSalesBalancePayments(int saleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sales-details/$saleId/balance-payments'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch sales balance payments: ${response.body}');
  }

  static Future<Map<String, dynamic>> saveSalesBalancePayment(Map<String, dynamic> payment) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales-details/balance-payments'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payment),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save sales balance payment';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save sales balance payment';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteSalesBalancePayment(int paymentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sales-details/balance-payments/$paymentId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete sales balance payment';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete sales balance payment';
    }
    throw Exception(errorMessage);
  }

  // Balance Payments (Company Purchase)
  static Future<List<Map<String, dynamic>>> getBalancePayments(int purchaseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company-purchase-details/$purchaseId/balance-payments'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to fetch balance payments: ${response.body}');
  }

  static Future<Map<String, dynamic>> saveBalancePayment(Map<String, dynamic> payment) async {
    final response = await http.post(
      Uri.parse('$baseUrl/company-purchase-details/balance-payments'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payment),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save balance payment';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save balance payment';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteBalancePayment(int paymentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/company-purchase-details/balance-payments/$paymentId'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete balance payment';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete photo';
    }
    throw Exception(errorMessage);
  }

  // Vehicle License
  static Future<List<VehicleLicense>> getVehicleLicenses({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/vehicle-licenses').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => VehicleLicense.fromJson(json)).toList();
    }
    throw Exception('Failed to load vehicle licenses');
  }

  static Future<VehicleLicense> createVehicleLicense(VehicleLicense license) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vehicle-licenses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(license.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return VehicleLicense.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create vehicle license';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create vehicle license';
    }
    throw Exception(errorMessage);
  }

  static Future<VehicleLicense> updateVehicleLicense(VehicleLicense license) async {
    final response = await http.put(
      Uri.parse('$baseUrl/vehicle-licenses/${license.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(license.toJson()),
    );
    if (response.statusCode == 200) {
      return VehicleLicense.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update vehicle license';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update vehicle license';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteVehicleLicense(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/vehicle-licenses/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception('Failed to delete vehicle license');
  }

  // Driver License
  static Future<List<DriverLicense>> getDriverLicenses({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/driver-licenses').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => DriverLicense.fromJson(json)).toList();
    }
    throw Exception('Failed to load driver licenses');
  }

  static Future<DriverLicense> createDriverLicense(DriverLicense license) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver-licenses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(license.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DriverLicense.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create driver license';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create driver license';
    }
    throw Exception(errorMessage);
  }

  static Future<DriverLicense> updateDriverLicense(DriverLicense license) async {
    final response = await http.put(
      Uri.parse('$baseUrl/driver-licenses/${license.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(license.toJson()),
    );
    if (response.statusCode == 200) {
      return DriverLicense.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update driver license';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update driver license';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteDriverLicense(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/driver-licenses/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception('Failed to delete driver license');
  }

  // Engine Oil Service
  static Future<List<EngineOilService>> getEngineOilServices({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/engine-oil-services').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => EngineOilService.fromJson(json)).toList();
    }
    throw Exception('Failed to load engine oil services');
  }

  static Future<EngineOilService> createEngineOilService(EngineOilService service) async {
    final response = await http.post(
      Uri.parse('$baseUrl/engine-oil-services'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(service.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return EngineOilService.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to create engine oil service';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create engine oil service';
    }
    throw Exception(errorMessage);
  }

  static Future<EngineOilService> updateEngineOilService(EngineOilService service) async {
    final response = await http.put(
      Uri.parse('$baseUrl/engine-oil-services/${service.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(service.toJson()),
    );
    if (response.statusCode == 200) {
      return EngineOilService.fromJson(json.decode(response.body));
    }
    String errorMessage = 'Failed to update engine oil service';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update engine oil service';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteEngineOilService(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/engine-oil-services/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception('Failed to delete engine oil service');
  }

  // Stock Items
  static Future<List<Map<String, dynamic>>> getStockItems({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/stock-items').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load stock items');
  }

  static Future<Map<String, dynamic>> createStockItem(
    String itemName,
    String sectorCode, {
    String? vehicleType,
    String? partNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stock-items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'item_name': itemName,
        'sector_code': sectorCode,
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (partNumber != null) 'part_number': partNumber,
      }),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to create stock item';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create stock item';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateStockItem(
    String id,
    String itemName,
    String sectorCode, {
    String? vehicleType,
    String? partNumber,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/stock-items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'item_name': itemName,
        'sector_code': sectorCode,
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (partNumber != null) 'part_number': partNumber,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to update stock item';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update stock item';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteStockItem(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/stock-items/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete stock item';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete stock item';
    }
    throw Exception(errorMessage);
  }

  // Daily Stock
  static Future<List<Map<String, dynamic>>> getDailyStock({
    int? month,
    String? date,
    String? sector,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (date != null) queryParams['date'] = date;
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/daily-stock').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load daily stock');
  }

  static Future<void> updateDailyStock(List<Map<String, dynamic>> updates, {String? date}) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    
    final uri = Uri.parse('$baseUrl/daily-stock').replace(queryParameters: queryParams);
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'updates': updates}),
    );
    if (response.statusCode == 200) {
      return;
    }
    String errorMessage = 'Failed to update daily stock';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update daily stock';
    }
    throw Exception(errorMessage);
  }

  // Overall Stock
  static Future<List<Map<String, dynamic>>> getOverallStock({
    int? month,
    String? date,
    String? sector,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (date != null) queryParams['date'] = date;
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/overall-stock').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load overall stock');
  }

  static Future<void> updateOverallStock(List<Map<String, dynamic>> updates) async {
    final uri = Uri.parse('$baseUrl/overall-stock');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'updates': updates}),
    );
    if (response.statusCode == 200) {
      return;
    }
    String errorMessage = 'Failed to update overall stock';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update overall stock';
    }
    throw Exception(errorMessage);
  }

  // Stock Statement
  static Future<List<Map<String, dynamic>>> generateStockStatement({
    required String fromDate,
    required String toDate,
    String? sector,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stock-statement/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'from_date': fromDate,
        'to_date': toDate,
        if (sector != null) 'sector': sector,
      }),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to generate stock statement';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to generate stock statement';
    }
    throw Exception(errorMessage);
  }

  // Mahal Vessels API methods
  static Future<List<Map<String, dynamic>>> getMahalVessels({String? mahalDetail}) async {
    final queryParams = <String, String>{};
    if (mahalDetail != null) queryParams['mahal_detail'] = mahalDetail;

    final uri = Uri.parse('$baseUrl/mahal-vessels').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => json as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load mahal vessels');
  }

  static Future<Map<String, dynamic>> createMahalVessel({
    required String mahalDetail,
    required String itemName,
    required int count,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mahal-vessels'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mahal_detail': mahalDetail,
        'item_name': itemName,
        'count': count,
      }),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    String errorMessage = 'Failed to create mahal vessel';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create mahal vessel';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateMahalVessel({
    required int id,
    required String mahalDetail,
    required String itemName,
    required int count,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/mahal-vessels/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mahal_detail': mahalDetail,
        'item_name': itemName,
        'count': count,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    String errorMessage = 'Failed to update mahal vessel';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update mahal vessel';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteMahalVessel(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/mahal-vessels/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete mahal vessel';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete mahal vessel';
    }
    throw Exception(errorMessage);
  }

  // Ingredients API methods
  static Future<List<Map<String, dynamic>>> getIngredients({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/ingredients').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception('Failed to load ingredients');
  }

  static Future<Map<String, dynamic>> getIngredientById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/ingredients/$id'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to load ingredient';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to load ingredient';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> createIngredient({
    required String menu,
    required int membersCount,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'menu': menu,
        'members_count': membersCount,
        'ingredients': ingredients,
      }),
    );
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to create ingredient';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create ingredient';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateIngredient({
    required String id,
    required String menu,
    required int membersCount,
    required List<Map<String, dynamic>> ingredients,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ingredients/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'menu': menu,
        'members_count': membersCount,
        'ingredients': ingredients,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to update ingredient';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update ingredient';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteIngredient(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/ingredients/$id'));
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete ingredient';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete ingredient';
    }
    throw Exception(errorMessage);
  }

  // Mining Activities
  static Future<List<Map<String, dynamic>>> getMiningActivities({String? sector}) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/mining-activities').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load mining activities');
  }

  static Future<Map<String, dynamic>> createMiningActivity(
    String activityName,
    String sectorCode, {
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mining-activities'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'activity_name': activityName,
        'sector_code': sectorCode,
        if (description != null) 'description': description,
      }),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    String errorMessage = 'Failed to create mining activity';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create mining activity';
    }
    throw Exception(errorMessage);
  }

  static Future<Map<String, dynamic>> updateMiningActivity(
    String id,
    String activityName,
    String sectorCode, {
    String? description,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/mining-activities/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'activity_name': activityName,
        'sector_code': sectorCode,
        if (description != null) 'description': description,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    String errorMessage = 'Failed to update mining activity';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to update mining activity';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteMiningActivity(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/mining-activities/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete mining activity';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete mining activity';
    }
    throw Exception(errorMessage);
  }

  // Daily Mining Activities
  static Future<List<Map<String, dynamic>>> getDailyMiningActivities({
    String? date,
    String? sector,
  }) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    if (sector != null) queryParams['sector'] = sector;

    final uri = Uri.parse('$baseUrl/mining-activities/daily').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load daily mining activities');
  }

  static Future<Map<String, dynamic>> createOrUpdateDailyMiningActivity({
    required int activityId,
    required String date,
    double? quantity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/mining-activities/daily'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'activity_id': activityId,
        'date': date,
        if (quantity != null) 'quantity': quantity,
      }),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    String errorMessage = 'Failed to save daily mining activity';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save daily mining activity';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteDailyMiningActivity(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/mining-activities/daily/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete daily mining activity';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete daily mining activity';
    }
    throw Exception(errorMessage);
  }

  // Daily Income and Expense
  static Future<List<Map<String, dynamic>>> getDailyIncomeExpense({
    required String sector,
    required String date,
  }) async {
    final queryParams = <String, String>{
      'sector': sector,
      'date': date,
    };

    final uri = Uri.parse('$baseUrl/daily-income-expense').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load daily income/expense');
  }

  static Future<Map<String, dynamic>> saveDailyIncomeExpense(Map<String, dynamic> record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-income-expense'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(record),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    String errorMessage = 'Failed to save daily income/expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to save daily income/expense';
    }
    throw Exception(errorMessage);
  }

  static Future<void> deleteDailyIncomeExpense(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/daily-income-expense/$id'),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    String errorMessage = 'Failed to delete daily income/expense';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to delete daily income/expense';
    }
    throw Exception(errorMessage);
  }

  static Future<List<Map<String, dynamic>>> getOverallIncomeExpense({
    required List<String> dates,
    required List<String> months,
  }) async {
    // Build query string manually to support multiple values
    final queryParts = <String>[];
    if (dates.isNotEmpty) {
      for (var date in dates) {
        queryParts.add('dates=${Uri.encodeComponent(date)}');
      }
    }
    if (months.isNotEmpty) {
      for (var month in months) {
        queryParts.add('months=${Uri.encodeComponent(month)}');
      }
    }

    final queryString = queryParts.join('&');
    final uri = Uri.parse('$baseUrl/daily-income-expense/overall?$queryString');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load overall income/expense');
  }
}

