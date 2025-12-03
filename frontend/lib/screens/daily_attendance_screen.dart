import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format_utils.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final int? preSelectedMonth;
  final DateTime? preSelectedDate;

  const DailyAttendanceScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.preSelectedMonth,
    this.preSelectedDate,
  });

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  List<Employee> _employees = [];
  List<Sector> _sectors = [];
  DateTime? _selectedDate;
  bool _isEditMode = false;
  bool _isLoading = false;

  // Attendance data for each employee
  final Map<String, Map<String, dynamic>> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.preSelectedDate ?? DateTime.now();
    _loadSectors();
    _loadEmployees();
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await ApiService.getSectors();
      if (mounted) {
        setState(() {
          _sectors = sectors;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  String _getSectorName(String? sectorCode) {
    if (sectorCode == null) return 'All Sectors';
    final sector = _sectors.firstWhere(
      (s) => s.code == sectorCode,
      orElse: () => Sector(code: sectorCode, name: sectorCode),
    );
    return sector.name;
  }

  Future<void> _loadEmployees() async {
    if (widget.selectedSector == null) return;

    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployeesBySector(widget.selectedSector!);
      setState(() {
        _employees = employees;
        // Initialize attendance data for each employee
        // Reset status to null for all employees (status is date-specific)
        for (var emp in employees) {
          if (!_attendanceData.containsKey(emp.id)) {
            _attendanceData[emp.id] = {
              'status': null, // Default to null (select status)
              'outstanding_advance': 0.0,
              'advance_taken': 0.0,
              'advance_paid': 0.0,
              'previous_outstanding': 0.0,
            };
          } else {
            // Reset status to null when loading new date (status is date-specific)
            _attendanceData[emp.id]!['status'] = null;
          }
        }
      });
      // Load previous outstanding advance for each employee (from previous day)
      if (_selectedDate != null) {
        final dateStr = _selectedDate!.toIso8601String().split('T')[0];
        for (var emp in _employees) {
          try {
            // Get the outstanding_advance from the most recent record BEFORE the selected date
            final previousOutstanding = await ApiService.getOutstandingAdvance(emp.id, dateStr);
            if (_attendanceData.containsKey(emp.id)) {
              // Store the previous day's outstanding (this is the base for calculation)
              _attendanceData[emp.id]!['previous_outstanding'] = previousOutstanding;
              // Initially set outstanding to previous (will be recalculated after loading today's data)
              _attendanceData[emp.id]!['outstanding_advance'] = previousOutstanding;
            }
          } catch (e) {
            // Ignore errors, use 0 as default
            if (_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id]!['previous_outstanding'] = 0.0;
              _attendanceData[emp.id]!['outstanding_advance'] = 0.0;
            }
          }
        }
      }
      // Load today's attendance data (if exists) - this will load advance_taken and advance_paid
      await _loadAttendanceData();
      // Final recalculation to ensure outstanding is correct
      _recalculateOutstanding();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employees: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _recalculateOutstanding() {
    for (var emp in _employees) {
      if (_attendanceData.containsKey(emp.id)) {
        final data = _attendanceData[emp.id]!;
        final previous = FormatUtils.parseDecimal(data['previous_outstanding']);
        final taken = FormatUtils.parseDecimal(data['advance_taken']);
        final paid = FormatUtils.parseDecimal(data['advance_paid']);
        data['outstanding_advance'] = previous + taken - paid;
      }
    }
    setState(() {});
  }

  Future<void> _loadAttendanceData() async {
    if (widget.selectedSector == null || _selectedDate == null) return;

    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final records = await ApiService.getAttendance(
        sector: widget.selectedSector,
        date: dateStr,
      );

      // Create a map of loaded records by employee_id for quick lookup
      // Store both string and int versions to handle any format
      final Map<String, Map<String, dynamic>> loadedRecords = {};
      for (var record in records) {
        final empId = record['employee_id'];
        // Store with both string and int keys to handle any format
        final empIdStr = empId.toString();
        loadedRecords[empIdStr] = record;
        // Also store with int key if it's a number
        if (empId is int) {
          loadedRecords[empId.toString()] = record;
        }
      }

      // Update attendance data for all employees
      // First, reset status to null for all employees (status is date-specific)
      for (var emp in _employees) {
        // Ensure employee has an entry in _attendanceData
        if (!_attendanceData.containsKey(emp.id)) {
          _attendanceData[emp.id] = {
            'status': null,
            'outstanding_advance': 0.0,
            'advance_taken': 0.0,
            'advance_paid': 0.0,
            'previous_outstanding': 0.0,
          };
        } else {
          // Reset status to null for new date (status is date-specific)
          _attendanceData[emp.id]!['status'] = null;
        }
      }
      
      // Now load data for employees with records for this specific date
      for (var emp in _employees) {
        final data = _attendanceData[emp.id]!;
        // Keep the previous_outstanding that was loaded earlier (from previous day)
        final previousOutstanding = FormatUtils.parseDecimal(data['previous_outstanding']);
        
        // Check both string and int versions of employee_id
        final empIdStr = emp.id;
        final empIdInt = int.tryParse(emp.id);
        final hasRecord = loadedRecords.containsKey(empIdStr) || 
                         (empIdInt != null && loadedRecords.containsKey(empIdInt.toString()));
        
        if (hasRecord) {
          // Employee has saved data for this date
          final record = loadedRecords[empIdStr] ?? loadedRecords[empIdInt.toString()]!;
          
          final taken = FormatUtils.parseDecimal(record['advance_taken']);
          final paid = FormatUtils.parseDecimal(record['advance_paid']);
          final status = record['status']; // Get status from record for this specific date
          
          // Calculate outstanding: previous day's outstanding + today's taken - today's paid
          final newOutstanding = previousOutstanding + taken - paid;
          
          _attendanceData[emp.id] = {
            'status': status, // Use saved status for this date
            'previous_outstanding': previousOutstanding, // Keep previous day's value
            'outstanding_advance': newOutstanding, // Recalculate
            'advance_taken': taken,
            'advance_paid': paid,
          };
          
        } else {
          // Employee has no saved data for this date - status remains null
          _attendanceData[emp.id] = {
            'status': null, // No status selected yet for this date
            'previous_outstanding': previousOutstanding,
            'outstanding_advance': previousOutstanding, // Start with previous outstanding
            'advance_taken': 0.0,
            'advance_paid': 0.0,
          };
        }
      }
      // Recalculate outstanding for all employees after loading
      _recalculateOutstanding();
      // Force UI update to show loaded data
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading attendance data: $e');
      // Don't show error to user, just log it
    }
  }


  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // Reload previous outstanding for new date
      if (widget.selectedSector != null && _employees.isNotEmpty) {
        final dateStr = picked.toIso8601String().split('T')[0];
        for (var emp in _employees) {
          try {
            // Get the outstanding_advance from the most recent record BEFORE the new selected date
            final previousOutstanding = await ApiService.getOutstandingAdvance(emp.id, dateStr);
            // Ensure employee has an entry
            if (!_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id] = {
                'status': null,
                'outstanding_advance': 0.0,
                'advance_taken': 0.0,
                'advance_paid': 0.0,
                'previous_outstanding': 0.0,
              };
            }
            // Update previous_outstanding for the new date
            _attendanceData[emp.id]!['previous_outstanding'] = previousOutstanding;
            // Initialize advance_taken and advance_paid to 0 (will be loaded from attendance data if exists)
            _attendanceData[emp.id]!['advance_taken'] = 0.0;
            _attendanceData[emp.id]!['advance_paid'] = 0.0;
            // Initialize status to null (will be loaded from attendance data if exists)
            _attendanceData[emp.id]!['status'] = null;
          } catch (e) {
            // Ignore errors, use 0 as default
            if (!_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id] = {
                'status': null,
                'outstanding_advance': 0.0,
                'advance_taken': 0.0,
                'advance_paid': 0.0,
                'previous_outstanding': 0.0,
              };
            } else {
              _attendanceData[emp.id]!['previous_outstanding'] = 0.0;
              _attendanceData[emp.id]!['status'] = null;
            }
          }
        }
      }
      // Load attendance data for the new date (this will load status, advance_taken and advance_paid if they exist)
      await _loadAttendanceData();
      // Recalculate outstanding after loading data for the new date
      _recalculateOutstanding();
    }
  }

  Future<void> _saveAttendance() async {
    if (widget.selectedSector == null || _selectedDate == null) return;

    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      
      // Only save employees that have a status selected or have been edited
      // Filter to include employees with status or with any advance changes
      final records = _employees
          .where((emp) {
            final data = _attendanceData[emp.id];
            // Save if employee has a status OR if they have advance changes (taken/paid)
            return data != null && (
              data['status'] != null ||
              (data['advance_taken'] != null && (data['advance_taken'] ?? 0.0) > 0.0) ||
              (data['advance_paid'] != null && (data['advance_paid'] ?? 0.0) > 0.0)
            );
          })
          .map((emp) {
            final data = _attendanceData[emp.id] ?? {};
            return {
              'employee_id': int.parse(emp.id),
              'employee_name': emp.name,
              'sector': widget.selectedSector!,
              'date': dateStr,
              'status': data['status'] ?? 'present', // Default to 'present' if not set
              'outstanding_advance': data['outstanding_advance'] ?? 0.0,
              'advance_taken': data['advance_taken'] ?? 0.0,
              'advance_paid': data['advance_paid'] ?? 0.0,
            };
          })
          .toList();

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save. Please select at least one employee status or enter advance details.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      await ApiService.bulkSaveAttendance(records);
      setState(() => _isEditMode = false);
      // Reload attendance data to reflect saved changes
      await _loadAttendanceData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved successfully for ${records.length} employee(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Attendance'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Sector Display
          if (widget.selectedSector != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _getSectorName(widget.selectedSector),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'All Sectors',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          // User icon with username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 4),
                Text(
                  widget.username,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // Home icon
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                    initialSector: widget.selectedSector,
                    isAdmin: AuthService.isAdmin,
                    isMainAdmin: AuthService.isMainAdmin,
                  ),
                ),
              );
            },
          ),
          // Logout icon
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Column(
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Date Selection - only show if not pre-selected
                      if (widget.preSelectedMonth == null && widget.preSelectedDate == null)
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select Date',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _employees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.blue.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.selectedSector == null
                                    ? 'Please select a sector from Home page'
                                    : 'No employees in selected sector',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.blue.shade100,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Outstanding Advance')),
                                    DataColumn(label: Text('Advance Taken')),
                                    DataColumn(label: Text('Advance Paid')),
                                  ],
                                  rows: _employees.map((employee) {
                                    final data = _attendanceData[employee.id] ?? {
                                      'status': 'present',
                                      'outstanding_advance': 0.0,
                                      'advance_taken': 0.0,
                                      'advance_paid': 0.0,
                                    };
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(employee.name)),
                                        DataCell(
                                          _isEditMode
                                              ? DropdownButton<String>(
                                                  value: data['status'],
                                                  hint: const Text('Select Status'),
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'present',
                                                      child: Text('Present'),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'absent',
                                                      child: Text('Absent'),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'halfday',
                                                      child: Text('Half Day'),
                                                    ),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _attendanceData[employee.id]?['status'] = value;
                                                    });
                                                  },
                                                )
                                              : Text(
                                                  data['status'] != null
                                                      ? data['status'].toString().toUpperCase()
                                                      : 'Not Set',
                                                  style: TextStyle(
                                                    color: data['status'] == null ? Colors.grey : null,
                                                  ),
                                                ),
                                        ),
                                        DataCell(
                                          Text(
                                            '₹${(data['outstanding_advance'] ?? 0.0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          _isEditMode
                                              ? SizedBox(
                                                  width: 120,
                                                  child: TextFormField(
                                                    initialValue: (data['advance_taken'] ?? 0.0).toString(),
                                                    keyboardType: TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                    ],
                                                    onChanged: (value) {
                                                      _attendanceData[employee.id]?['advance_taken'] =
                                                          double.tryParse(value) ?? 0.0;
                                                      _recalculateOutstanding();
                                                    },
                                                  ),
                                                )
                                              : Text('₹${(data['advance_taken'] ?? 0.0).toStringAsFixed(2)}'),
                                        ),
                                        DataCell(
                                          _isEditMode
                                              ? SizedBox(
                                                  width: 120,
                                                  child: TextFormField(
                                                    initialValue: (data['advance_paid'] ?? 0.0).toString(),
                                                    keyboardType: TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                    ],
                                                    onChanged: (value) {
                                                      _attendanceData[employee.id]?['advance_paid'] =
                                                          double.tryParse(value) ?? 0.0;
                                                      _recalculateOutstanding();
                                                    },
                                                  ),
                                                )
                                              : Text('₹${(data['advance_paid'] ?? 0.0).toStringAsFixed(2)}'),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
            // Edit/Save Button
            if (_employees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isEditMode ? _saveAttendance : () => setState(() => _isEditMode = true),
                    icon: Icon(_isEditMode ? Icons.save : Icons.edit),
                    label: Text(_isEditMode ? 'Save Attendance' : 'Edit Attendance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

