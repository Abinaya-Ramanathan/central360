import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'month_year_picker.dart';

class SalaryExpenseScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const SalaryExpenseScreen({
    super.key,
    required this.username,
    this.selectedSector,
  });

  @override
  State<SalaryExpenseScreen> createState() => _SalaryExpenseScreenState();
}

class _SalaryExpenseScreenState extends State<SalaryExpenseScreen> {
  List<Employee> _employees = [];
  bool _isLoading = false;
  
  DateTime? _selectedMonth;
  
  // Salary data for each employee - supports multiple entries per month
  // Key: employee_id, Value: List of salary records
  final Map<String, List<Map<String, dynamic>>> _salaryData = {};
  
  int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }
  
  // Helper function to format date for API (handles both DateTime and String)
  String? _formatDateForApi(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) {
      return dateValue.toIso8601String().split('T')[0];
    }
    if (dateValue is String) {
      // If it's already a string in YYYY-MM-DD format, return it
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateValue)) {
        return dateValue;
      }
      // Try to parse it as DateTime and format it
      try {
        final dateTime = DateTime.parse(dateValue);
        return dateTime.toIso8601String().split('T')[0];
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  // Helper function to parse date from API (handles both DateTime and String)
  DateTime? _parseDateFromApi(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) {
      return dateValue;
    }
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = widget.selectedSector == null
          ? await ApiService.getEmployees() // Load all employees if no sector selected
          : await ApiService.getEmployeesBySector(widget.selectedSector!);
      setState(() {
        _employees = employees;
        // Initialize empty salary data for each employee - no auto-created entries
        for (var emp in employees) {
          if (!_salaryData.containsKey(emp.id)) {
            _salaryData[emp.id] = [];
          }
        }
      });
      // Load saved salary expenses for the current month
      await _loadSalaryExpenses();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employees: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _deleteSalaryDataForEmployee(String employeeId, int recordIndex, String recordId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Salary Record'),
        content: const Text('Are you sure you want to delete this salary record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    try {
      await ApiService.deleteSalaryExpense(recordId);
      
      // Remove from local data
      final records = _salaryData[employeeId] ?? [];
      if (recordIndex < records.length) {
        records.removeAt(recordIndex);
        if (records.isEmpty) {
          _salaryData.remove(employeeId);
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary record deleted successfully')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting salary record: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => MonthYearPicker(
        initialDate: _selectedMonth ?? now,
        firstDate: DateTime(2000),
        lastDate: now,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      // Clear salary data when month changes
      _salaryData.clear();
      // Load saved salary expenses for the selected month
      await _loadSalaryExpenses();
    }
  }

  Future<void> _saveSalaryDataForEmployee(String employeeId, int recordIndex) async {
    if (_selectedMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a month first')),
      );
      return;
    }

    final employee = _employees.firstWhere((e) => e.id == employeeId);
    final records = _salaryData[employeeId] ?? [];
    
    // Find the correct record index - use the last entry if recordIndex is invalid
    int actualIndex = recordIndex >= 0 && recordIndex < records.length 
        ? recordIndex 
        : records.length - 1;
    
    if (actualIndex < 0 || actualIndex >= records.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entry to save')),
      );
      return;
    }

    final data = records[actualIndex];
    
    setState(() => _isLoading = true);
    try {
      // Use month start and end dates
      final weekStartDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
      final weekEndDate = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);

      // Check if this is a new entry (no ID) or an update (has ID)
      final isNewEntry = data['id'] == null || data['isNew'] == true;
      
      final record = {
        // Only include ID if this is an update (not a new entry)
        if (!isNewEntry && data['id'] != null) 'id': int.parse(data['id']),
        'employee_id': int.parse(employeeId),
        'employee_name': employee.name,
        'sector': widget.selectedSector ?? employee.sector, // Use employee's sector if no sector selected
        'week_start_date': weekStartDate.toIso8601String().split('T')[0],
        'week_end_date': weekEndDate.toIso8601String().split('T')[0],
        'outstanding_advance': 0.0, // Not needed for simple view
        'days_present': 0, // Not needed for simple view
        'estimated_salary': 0.0, // Not needed for simple view
        'advance_deducted': 0, // Not needed for simple view
        'salary_issued': data['salary_issued'] ?? 0,
        'salary_issued_date': _formatDateForApi(data['salary_issued_date']),
        'selected_dates': [], // No date selection needed
      };

      // Save single record (will create or update based on ID)
      final savedRecord = await ApiService.saveSalaryExpense(record);
      
      // Update the local data with the saved record's ID
      if (savedRecord['id'] != null) {
        data['id'] = savedRecord['id'].toString();
      }
      
      // Don't reload - just update the current entry
      
      // Mark as saved
      data['isNew'] = false;
      data['isEditMode'] = false;
      
      // Note: advance_deducted is always 0 now (column removed), so no need to reload outstanding advances
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary data saved successfully')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving salary data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalaryExpenses() async {
    if (_employees.isEmpty || _selectedMonth == null) return;
    
    try {
      // Use month start and end dates
      final weekStartDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
      final weekEndDate = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
      
      final weekStartStr = weekStartDate.toIso8601String().split('T')[0];
      final weekEndStr = weekEndDate.toIso8601String().split('T')[0];
      
      // Load existing salary expenses for the selected month
      final existingRecords = await ApiService.getSalaryExpenses(
        sector: widget.selectedSector,
        weekStart: weekStartStr,
        weekEnd: weekEndStr,
      );
      
      // Group records by employee_id
      final Map<String, List<Map<String, dynamic>>> groupedRecords = {};
      for (var record in existingRecords) {
        final empId = record['employee_id'].toString();
        if (!groupedRecords.containsKey(empId)) {
          groupedRecords[empId] = [];
        }
        groupedRecords[empId]!.add(record);
      }
      
      // Helper function to parse integer values
      int parseIntValue(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) {
          // Handle empty string
          if (value.trim().isEmpty) return 0;
          final parsed = int.tryParse(value);
          return parsed ?? 0;
        }
        // Try to convert to string first, then parse
        try {
          final strValue = value.toString();
          if (strValue.trim().isEmpty) return 0;
          final parsed = int.tryParse(strValue);
          return parsed ?? 0;
        } catch (e) {
          return 0;
        }
      }
      
      // Preserve unsaved new entries (entries with isNew: true and no ID)
      final Map<String, List<Map<String, dynamic>>> unsavedEntries = {};
      for (var emp in _employees) {
        final existingUnsaved = _salaryData[emp.id]?.where((entry) => 
          (entry['isNew'] == true && entry['id'] == null)
        ).toList() ?? [];
        if (existingUnsaved.isNotEmpty) {
          unsavedEntries[emp.id] = existingUnsaved;
        }
      }
      
      // Load saved records from database
      for (var emp in _employees) {
        if (groupedRecords.containsKey(emp.id)) {
          final savedRecords = groupedRecords[emp.id]!.map((record) {
            // Safely parse salary_issued - handle both int, string, and null
            final salaryIssuedValue = record['salary_issued'];
            final salaryIssued = parseIntValue(salaryIssuedValue);
            
            return {
              'id': record['id']?.toString(),
              'salary_issued': salaryIssued,
              'salary_issued_date': _parseDateFromApi(record['salary_issued_date']),
              'isNew': false,
              'isEditMode': false,
            };
          }).toList();
          
          // Combine saved records with unsaved new entries
          final unsaved = unsavedEntries[emp.id] ?? [];
          _salaryData[emp.id] = [...savedRecords, ...unsaved];
        } else {
          // If no saved records, keep unsaved entries or create empty list
          _salaryData[emp.id] = unsavedEntries[emp.id] ?? [];
        }
      }
      
      setState(() {});
    } catch (e) {
      // Ignore errors, just continue with empty data
      debugPrint('Error loading salary expenses: $e');
    }
  }

  Future<void> _addNewEntryForEmployee(String employeeId) async {
    if (!_salaryData.containsKey(employeeId)) {
      _salaryData[employeeId] = [];
    }
    
    // Add a simple new entry - just salary and date
    _salaryData[employeeId]!.add({
      'salary_issued': 0,
      'salary_issued_date': null,
      'isNew': true,
      'isEditMode': true,
    });
    setState(() {});
  }

  List<DataRow> _buildTableRows() {
    final List<DataRow> rows = [];
    
    for (var employee in _employees) {
      final records = _salaryData[employee.id] ?? [];
      
      if (records.isEmpty) {
        // Add empty row with add button
        rows.add(_buildEmployeeRow(employee, null, -1));
      } else {
        // Add row for each record
        for (int i = 0; i < records.length; i++) {
          rows.add(_buildEmployeeRow(employee, records[i], i));
        }
        // Add "Add Entry" row at the end
        rows.add(_buildAddEntryRow(employee));
      }
    }
    
    return rows;
  }

  DataRow _buildEmployeeRow(Employee employee, Map<String, dynamic>? data, int recordIndex) {
    final isEditMode = data?['isEditMode'] == true;
    
    return DataRow(
      cells: [
        DataCell(Text(employee.name)),
        DataCell(
          isEditMode
              ? SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: (data?['salary_issued'] ?? 0).toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      final records = _salaryData[employee.id] ?? [];
                      // Find the correct record index - use the last entry if recordIndex is invalid
                      int actualIndex = recordIndex >= 0 && recordIndex < records.length 
                          ? recordIndex 
                          : records.length - 1;
                      if (actualIndex >= 0 && actualIndex < records.length) {
                        // Parse value - handle both int and string
                        int parseIntValue(String val) {
                          final parsed = int.tryParse(val);
                          return parsed ?? 0;
                        }
                        records[actualIndex]['salary_issued'] = parseIntValue(value);
                        // No need to call setState here - value is already updated in the field
                      }
                    },
                  ),
                )
              : Text('₹${_parseIntValue(data?['salary_issued'])}'),
        ),
        DataCell(
          isEditMode
              ? InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _parseDateFromApi(data?['salary_issued_date']) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final records = _salaryData[employee.id] ?? [];
                      // Find the correct record index - use the last entry if recordIndex is invalid
                      int actualIndex = recordIndex >= 0 && recordIndex < records.length 
                          ? recordIndex 
                          : records.length - 1;
                      if (actualIndex >= 0 && actualIndex < records.length) {
                        records[actualIndex]['salary_issued_date'] = picked; // Store as DateTime
                        setState(() {});
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:                       Text(
                      _formatDateForApi(data?['salary_issued_date']) ?? 'Select Date',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
              : Text(
                  _formatDateForApi(data?['salary_issued_date']) ?? '-',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEditMode)
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.green, size: 20),
                  tooltip: 'Save',
                  onPressed: () => _saveSalaryDataForEmployee(employee.id, recordIndex),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  tooltip: 'Edit',
                  onPressed: () {
                    final records = _salaryData[employee.id] ?? [];
                    
                    if (data == null || recordIndex < 0) {
                      // If no data exists, create a new entry
                      if (!_salaryData.containsKey(employee.id)) {
                        _salaryData[employee.id] = [];
                      }
                      _salaryData[employee.id]!.add({
                        'salary_issued': 0,
                        'salary_issued_date': null,
                        'isNew': true,
                        'isEditMode': true,
                      });
                    } else if (recordIndex >= 0 && recordIndex < records.length) {
                      // Edit existing entry
                      records[recordIndex]['isEditMode'] = true;
                    }
                    setState(() {});
                  },
                ),
              // Delete button (only show for saved records, not new entries)
              if (data != null && data['id'] != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  tooltip: 'Delete',
                  onPressed: () => _deleteSalaryDataForEmployee(employee.id, recordIndex, data['id']),
                ),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildAddEntryRow(Employee employee) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              const Icon(Icons.add_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('Add Entry', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            tooltip: 'Add New Entry',
            onPressed: () => _addNewEntryForEmployee(employee.id),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Expense Details'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
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
              Colors.purple.shade50,
              Colors.purple.shade100,
            ],
          ),
        ),
        child: Column(
          children: [
            // Date Selection Controls
            if (widget.selectedSector != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectMonth,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          _selectedMonth != null
                              ? '${_selectedMonth!.year}-${_selectedMonth!.month.toString().padLeft(2, '0')}'
                              : 'Select Month',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Employee Table
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.selectedSector == null && _employees.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Loading employees...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else if (_employees.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No employees in selected sector',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 15,
                      columns: const [
                        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Salary Issued', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Salary Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _buildTableRows(),
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

// Date Range Picker Dialog
class _DateRangePickerDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> initialSelectedDates;

  const _DateRangePickerDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialSelectedDates,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late Set<DateTime> _selectedDates;

  @override
  void initState() {
    super.initState();
    _selectedDates = Set.from(widget.initialSelectedDates);
  }

  void _toggleDate(DateTime date) {
    setState(() {
      if (_selectedDates.contains(date)) {
        _selectedDates.remove(date);
      } else {
        _selectedDates.add(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = widget.lastDate.day;
    final firstWeekday = widget.firstDate.weekday;

    return AlertDialog(
      title: const Text('Select Dates'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            // Month/Year Header
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${widget.firstDate.year} - ${_getMonthName(widget.firstDate.month)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((day) => SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const Divider(),
            // Calendar grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: daysInMonth + firstWeekday - 1,
                itemBuilder: (context, index) {
                  if (index < firstWeekday - 1) {
                    return const SizedBox();
                  }
                  final day = index - firstWeekday + 2;
                  final date = DateTime(widget.firstDate.year, widget.firstDate.month, day);
                  final isSelected = _selectedDates.contains(date);

                  return InkWell(
                    onTap: () => _toggleDate(date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple.shade300 : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.purple.shade700 : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('Selected: ${_selectedDates.length} dates'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedDates),
          child: const Text('Done'),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

