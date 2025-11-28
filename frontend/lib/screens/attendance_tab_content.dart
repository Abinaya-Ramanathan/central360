import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';

class AttendanceTabContent extends StatefulWidget {
  final String? selectedSector;
  final int? selectedMonth;
  final DateTime? selectedDate;
  final bool isAdmin;

  const AttendanceTabContent({
    super.key,
    this.selectedSector,
    this.selectedMonth,
    this.selectedDate,
    this.isAdmin = false,
  });

  @override
  State<AttendanceTabContent> createState() => _AttendanceTabContentState();
}

class _AttendanceTabContentState extends State<AttendanceTabContent> {
  List<Employee> _employees = [];
  List<Sector> _sectors = [];
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column
  final Map<String, Map<String, dynamic>> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadSectors();
    if (widget.selectedMonth != null && widget.selectedDate != null) {
      if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
  }

  @override
  void didUpdateWidget(AttendanceTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedMonth != oldWidget.selectedMonth ||
            widget.selectedDate != oldWidget.selectedDate ||
            widget.selectedSector != oldWidget.selectedSector) &&
        widget.selectedMonth != null &&
        widget.selectedDate != null) {
      if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
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

  Future<void> _loadData() async {
    if (widget.selectedDate == null) return;
    if (widget.selectedSector == null && !widget.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      List<Employee> employees;
      if (widget.selectedSector == null && widget.isAdmin) {
        // Load all employees from all sectors
        final allSectors = await ApiService.getSectors();
        employees = [];
        for (var sector in allSectors) {
          final sectorEmployees = await ApiService.getEmployeesBySector(sector.code);
          employees.addAll(sectorEmployees);
        }
      } else {
        employees = await ApiService.getEmployeesBySector(widget.selectedSector!);
      }
      setState(() {
        _employees = employees;
        for (var emp in employees) {
          if (!_attendanceData.containsKey(emp.id)) {
          _attendanceData[emp.id] = {
            'status': null,
            'outstanding_advance': 0.0,
            'advance_taken': 0.0,
            'advance_paid': 0.0,
            'previous_outstanding': 0.0,
            'bulk_advance': 0.0,
            'bulk_advance_taken': 0.0,
            'bulk_advance_paid': 0.0,
            'previous_bulk_advance': 0.0,
          };
          }
        }
      });

      // Get previous outstanding from the day BEFORE the selected date
      // This ensures we get the outstanding from the previous day, not from the current date's record
      final previousDate = widget.selectedDate!.subtract(const Duration(days: 1));
      final previousDateStr = previousDate.toIso8601String().split('T')[0];
      
      // First, reset advance_taken and advance_paid to 0 for all employees
      // Only outstanding_advance should carry forward, not advance_taken/advance_paid
      for (var emp in _employees) {
        if (_attendanceData.containsKey(emp.id)) {
          _attendanceData[emp.id]!['advance_taken'] = 0.0;
          _attendanceData[emp.id]!['advance_paid'] = 0.0;
          _attendanceData[emp.id]!['bulk_advance_taken'] = 0.0;
          _attendanceData[emp.id]!['bulk_advance_paid'] = 0.0;
        }
      }
      
      for (var emp in _employees) {
        try {
          // Get outstanding from the day before the selected date
          final previousOutstanding = await ApiService.getOutstandingAdvance(emp.id, previousDateStr);
          if (_attendanceData.containsKey(emp.id)) {
            _attendanceData[emp.id]!['previous_outstanding'] = previousOutstanding;
            // Outstanding advance carries forward from previous date
            _attendanceData[emp.id]!['outstanding_advance'] = previousOutstanding;
          }
        } catch (e) {
          if (_attendanceData.containsKey(emp.id)) {
            _attendanceData[emp.id]!['previous_outstanding'] = 0.0;
            _attendanceData[emp.id]!['outstanding_advance'] = 0.0;
          }
        }
      }

      // Get previous bulk advance for each employee (from previous day)
      // This ensures bulk advance persists across dates until it's paid off
      for (var emp in _employees) {
        try {
          // Get bulk advance from the day before the selected date
          // This gets the most recent bulk_advance value up to and including the previous date
          final previousBulkAdvance = await ApiService.getBulkAdvance(emp.id, previousDateStr);
          if (_attendanceData.containsKey(emp.id)) {
            // Store the previous bulk advance for calculation
            _attendanceData[emp.id]!['previous_bulk_advance'] = previousBulkAdvance;
            // Initially set bulk_advance to previous value (will be recalculated if record exists)
            _attendanceData[emp.id]!['bulk_advance'] = previousBulkAdvance;
          }
        } catch (e) {
          // If error getting previous bulk advance, default to 0
          // But log the error for debugging
          debugPrint('Error loading previous bulk advance for ${emp.id}: $e');
          if (_attendanceData.containsKey(emp.id)) {
            _attendanceData[emp.id]!['previous_bulk_advance'] = 0.0;
            _attendanceData[emp.id]!['bulk_advance'] = 0.0;
          }
        }
      }

      final dateStr = widget.selectedDate!.toIso8601String().split('T')[0];
      final attendanceRecords = await ApiService.getAttendance(
        sector: widget.selectedSector, // null for all sectors
        date: dateStr,
      );

      // If there's an existing record for this date, load its advance_taken and advance_paid
      // Otherwise, they remain 0 (only outstanding_advance and bulk_advance carry forward)
      for (var record in attendanceRecords) {
        final empIdStr = record['employee_id'].toString();
        final emp = _employees.firstWhere((e) => e.id == empIdStr, orElse: () => _employees.first);
        if (_attendanceData.containsKey(emp.id)) {
          final data = _attendanceData[emp.id]!;
          
          // OUTSTANDING ADVANCE CALCULATION (Independent)
          final previous = _parseDecimal(data['previous_outstanding']);
          final taken = _parseDecimal(record['advance_taken']);
          final paid = _parseDecimal(record['advance_paid']);
          // Calculate: previous outstanding + advance taken - advance paid
          // This is completely independent from bulk advance
          final newOutstanding = previous + taken - paid;
          
          // BULK ADVANCE CALCULATION (Independent - NOT added to outstanding advance)
          // Use the previous_bulk_advance that was loaded (from most recent record up to previous date)
          final previousBulk = _parseDecimal(data['previous_bulk_advance']);
          final bulkTaken = _parseDecimal(record['bulk_advance_taken']);
          final bulkPaid = _parseDecimal(record['bulk_advance_paid']);
          // Calculate: previous bulk advance + bulk advance taken - bulk advance paid
          // This ensures bulk advance persists until fully paid off
          // If previousBulk is 10000, bulkTaken is 0, bulkPaid is 0, then bulk_advance = 10000
          final newBulkAdvance = previousBulk + bulkTaken - bulkPaid;
          
          final status = record['status'] as String?;

          _attendanceData[emp.id] = {
            'status': status,
            'previous_outstanding': previous,
            'outstanding_advance': newOutstanding,
            'advance_taken': taken,  // Only load if record exists for this date
            'advance_paid': paid,     // Only load if record exists for this date
            'previous_bulk_advance': previousBulk,  // Keep the previous value for recalculation
            'bulk_advance': newBulkAdvance,  // Calculated value that will be saved
            'bulk_advance_taken': bulkTaken,  // Only load if record exists for this date
            'bulk_advance_paid': bulkPaid,     // Only load if record exists for this date
          };
        }
      }
      
      // For employees without existing records, ensure bulk_advance is set to previous_bulk_advance
      // This ensures it persists even when there's no record for the current date
      for (var emp in _employees) {
        if (_attendanceData.containsKey(emp.id)) {
          final data = _attendanceData[emp.id]!;
          // If bulk_advance is not set or is 0, but previous_bulk_advance has a value, use previous
          // This handles the case where there's no existing record for this date
          final currentBulk = _parseDecimal(data['bulk_advance']);
          final prevBulk = _parseDecimal(data['previous_bulk_advance']);
          if (currentBulk == 0 && prevBulk > 0) {
            // No record exists for this date, so bulk_advance should carry forward
            data['bulk_advance'] = prevBulk;
          }
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _parseDecimal(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _recalculateOutstanding() {
    for (var emp in _employees) {
      if (_attendanceData.containsKey(emp.id)) {
        final data = _attendanceData[emp.id]!;
        final previous = _parseDecimal(data['previous_outstanding']);
        final taken = _parseDecimal(data['advance_taken']);
        final paid = _parseDecimal(data['advance_paid']);
        data['outstanding_advance'] = previous + taken - paid;
        
        // Recalculate bulk advance
        final previousBulk = _parseDecimal(data['previous_bulk_advance']);
        final bulkTaken = _parseDecimal(data['bulk_advance_taken']);
        final bulkPaid = _parseDecimal(data['bulk_advance_paid']);
        data['bulk_advance'] = previousBulk + bulkTaken - bulkPaid;
      }
    }
    setState(() {});
  }

  Future<void> _saveAttendance() async {
    if (widget.selectedSector == null || widget.selectedDate == null) return;

    final dateStr = widget.selectedDate!.toIso8601String().split('T')[0];
    final employeesWithoutStatus = _employees.where((emp) {
      final data = _attendanceData[emp.id];
      return data == null || data['status'] == null;
    }).toList();

    if (employeesWithoutStatus.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set status for all employees'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Recalculate outstanding advance and bulk advance before saving to ensure they're up to date
      _recalculateOutstanding();
      
      final attendanceRecords = _employees.map((emp) {
        final data = _attendanceData[emp.id] ?? {};
        final previousBulk = _parseDecimal(data['previous_bulk_advance']);
        final bulkTaken = _parseDecimal(data['bulk_advance_taken']);
        final bulkPaid = _parseDecimal(data['bulk_advance_paid']);
        
        // Ensure bulk_advance is calculated correctly before saving
        // It should be: previous_bulk_advance + bulk_advance_taken - bulk_advance_paid
        // This ensures bulk advance persists across dates until fully paid off
        final finalBulkAdvance = previousBulk + bulkTaken - bulkPaid;
        
        return {
          'employee_id': int.parse(emp.id),
          'employee_name': emp.name,
          'sector': widget.selectedSector ?? emp.sector,
          'date': dateStr,
          'status': data['status'] ?? 'present',
          'outstanding_advance': _parseDecimal(data['outstanding_advance']),
          'advance_taken': _parseDecimal(data['advance_taken']),
          'advance_paid': _parseDecimal(data['advance_paid']),
          'bulk_advance': finalBulkAdvance,  // Use calculated value to ensure persistence
          'bulk_advance_taken': bulkTaken,
          'bulk_advance_paid': bulkPaid,
        };
      }).toList();

      await ApiService.bulkSaveAttendance(attendanceRecords);
      setState(() => _isEditMode = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedMonth == null || widget.selectedDate == null) {
      return const Center(
        child: Text(
          'Please select month and date',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (widget.selectedSector == null && !widget.isAdmin) {
      return const Center(
        child: Text(
          'Please select a sector from Home page',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final showSectorColumn = widget.isAdmin && widget.selectedSector == null;

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? const Center(
                      child: Text(
                        'No employees in selected sector',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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
                              headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
                              sortColumnIndex: showSectorColumn ? 0 : null,
                              sortAscending: _sortAscending,
                              columns: [
                                if (showSectorColumn)
                                  DataColumn(
                                    label: const Text('Sector'),
                                    onSort: (columnIndex, ascending) {
                                      setState(() {
                                        _sortAscending = ascending;
                                        _employees.sort((a, b) {
                                          final aName = _getSectorName(a.sector).toLowerCase();
                                          final bName = _getSectorName(b.sector).toLowerCase();
                                          return ascending
                                              ? aName.compareTo(bName)
                                              : bName.compareTo(aName);
                                        });
                                      });
                                    },
                                  ),
                                const DataColumn(label: Text('Name')),
                                const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('Outstanding Advance')),
                                const DataColumn(label: Text('Advance Taken')),
                                const DataColumn(label: Text('Advance Paid')),
                                const DataColumn(label: Text('Bulk Advance')),
                                const DataColumn(label: Text('Bulk Advance Taken')),
                                const DataColumn(label: Text('Bulk Advance Paid')),
                              ],
                              rows: _employees.map((employee) {
                                final data = _attendanceData[employee.id] ?? {
                                  'status': null,
                                  'outstanding_advance': 0.0,
                                  'advance_taken': 0.0,
                                  'advance_paid': 0.0,
                                  'bulk_advance': 0.0,
                                  'bulk_advance_taken': 0.0,
                                  'bulk_advance_paid': 0.0,
                                };
                                return DataRow(
                                  cells: [
                                    if (showSectorColumn)
                                      DataCell(Text(_getSectorName(employee.sector))),
                                    DataCell(Text(employee.name)),
                                    DataCell(
                                      _isEditMode
                                          ? DropdownButton<String>(
                                              value: data['status'],
                                              hint: const Text('Select Status'),
                                              items: const [
                                                DropdownMenuItem(value: 'present', child: Text('Present')),
                                                DropdownMenuItem(value: 'absent', child: Text('Absent')),
                                                DropdownMenuItem(value: 'halfday', child: Text('Half Day')),
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
                                    DataCell(
                                      Text(
                                        '₹${(data['bulk_advance'] ?? 0.0).toStringAsFixed(2)}',
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
                                                initialValue: (data['bulk_advance_taken'] ?? 0.0).toString(),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                                onChanged: (value) {
                                                  _attendanceData[employee.id]?['bulk_advance_taken'] =
                                                      double.tryParse(value) ?? 0.0;
                                                  _recalculateOutstanding();
                                                },
                                              ),
                                            )
                                          : Text('₹${(data['bulk_advance_taken'] ?? 0.0).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      _isEditMode
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                initialValue: (data['bulk_advance_paid'] ?? 0.0).toString(),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                                onChanged: (value) {
                                                  _attendanceData[employee.id]?['bulk_advance_paid'] =
                                                      double.tryParse(value) ?? 0.0;
                                                  _recalculateOutstanding();
                                                },
                                              ),
                                            )
                                          : Text('₹${(data['bulk_advance_paid'] ?? 0.0).toStringAsFixed(2)}'),
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
    );
  }
}

