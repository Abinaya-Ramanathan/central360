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
    final response = await http.get(Uri.parse('$baseUrl/employees'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Employee.fromJson(json)).toList();
    }
    throw Exception('Failed to load employees');
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
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      } else {
        errorMessage = response.body;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : 'Failed to create sector';
    }
    throw Exception(errorMessage);
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
  }) async {
    final queryParams = <String, String>{};
    if (sector != null) queryParams['sector'] = sector;
    if (date != null) queryParams['date'] = date;
    if (month != null) queryParams['month'] = month;

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
}

