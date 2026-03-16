import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../utils/format_utils.dart';
import '../widgets/fixed_header_table.dart';

class AttendanceTabContent extends StatefulWidget {
  final String? selectedSector;
  /// When set (main sector page), load employees and attendance for these sector codes.
  final List<String>? includedSectorCodes;
  final DateTime? selectedDate;
  final bool isAdmin;
  final bool isEditMode;
  final ValueChanged<bool>? onEditModeChanged;
  final ValueChanged<Future<bool> Function()>? onSaveMethodReady;

  const AttendanceTabContent({
    super.key,
    this.selectedSector,
    this.includedSectorCodes,
    this.selectedDate,
    this.isAdmin = false,
    this.isEditMode = false,
    this.onEditModeChanged,
    this.onSaveMethodReady,
  });

  @override
  State<AttendanceTabContent> createState() => _AttendanceTabContentState();
}

class _AttendanceTabContentState extends State<AttendanceTabContent> {
  List<Employee> _employees = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column
  final Map<String, Map<String, dynamic>> _attendanceData = {};
  final ScrollController _horizontalScrollController = ScrollController();

  static const double _headerHeight = 48;
  static const double _colSector = 100;
  static const double _colName = 120;
  static const double _colStatus = 100;
  static const double _colOt = 100;
  static const double _colMoney = 120;
  static const double _colSpacing = 16;

  @override
  void initState() {
    super.initState();
    _loadSectors();
    if (widget.selectedDate != null) {
      if (widget.includedSectorCodes != null || widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
    // Register save method with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onSaveMethodReady != null) {
        widget.onSaveMethodReady!(saveAttendance);
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AttendanceTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedDate != oldWidget.selectedDate ||
            widget.selectedSector != oldWidget.selectedSector ||
            widget.includedSectorCodes != oldWidget.includedSectorCodes) &&
        widget.selectedDate != null) {
      if (widget.includedSectorCodes != null || widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await SectorService().loadSectorsForScreen();
      if (mounted) setState(() => _sectors = sectors);
    } catch (_) {}
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
    if (widget.includedSectorCodes == null && widget.selectedSector == null && !widget.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      List<Employee> employees;
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        final all = await ApiService.getEmployees();
        employees = all.where((e) => widget.includedSectorCodes!.contains(e.sector)).toList();
      } else if (widget.selectedSector == null && widget.isAdmin) {
        employees = await ApiService.getEmployees();
      } else {
        employees = await ApiService.getEmployeesBySector(widget.selectedSector!);
      }
      setState(() {
        _employees = employees;
        for (var emp in employees) {
          if (!_attendanceData.containsKey(emp.id)) {
          _attendanceData[emp.id] = {
            'status': null,
            'ot_hours': 0.0,
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
      final previousDateStr = FormatUtils.formatDateForApi(previousDate);
      
      // First, reset status, advance_taken and advance_paid to 0/null for all employees
      // Status is date-specific and should be null for new dates
      // Only outstanding_advance should carry forward, not advance_taken/advance_paid
      for (var emp in _employees) {
        if (_attendanceData.containsKey(emp.id)) {
          _attendanceData[emp.id]!['status'] = null; // Reset status to null for new date
          _attendanceData[emp.id]!['ot_hours'] = 0.0; // Reset OT hours to 0 for new date
          _attendanceData[emp.id]!['advance_taken'] = 0.0;
          _attendanceData[emp.id]!['advance_paid'] = 0.0;
          _attendanceData[emp.id]!['bulk_advance_taken'] = 0.0;
          _attendanceData[emp.id]!['bulk_advance_paid'] = 0.0;
        }
      }
      
      // Fetch outstanding advances in batch
      if (_employees.isNotEmpty) {
        try {
          final ids = _employees.map((e) => e.id).toList();
          final outstandingMap = await ApiService.getOutstandingAdvanceBatch(ids, previousDateStr);
          for (var emp in _employees) {
            final prev = outstandingMap[emp.id] ?? 0.0;
            if (_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id]!['previous_outstanding'] = prev;
              _attendanceData[emp.id]!['outstanding_advance'] = prev;
            }
          }
        } catch (e) {
          for (var emp in _employees) {
            if (_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id]!['previous_outstanding'] = 0.0;
              _attendanceData[emp.id]!['outstanding_advance'] = 0.0;
            }
          }
        }
      }

      // Get previous bulk advance for each employee (from previous day)
      // This ensures bulk advance persists across dates until it's paid off
      // Fetch bulk advances in batch
      if (_employees.isNotEmpty) {
        try {
          final ids = _employees.map((e) => e.id).toList();
          final bulkMap = await ApiService.getBulkAdvanceBatch(ids, previousDateStr);
          for (var emp in _employees) {
            final prevBulk = bulkMap[emp.id] ?? 0.0;
            if (_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id]!['previous_bulk_advance'] = prevBulk;
              _attendanceData[emp.id]!['bulk_advance'] = prevBulk;
            }
          }
        } catch (e) {
          debugPrint('Error loading bulk advance batch: $e');
          for (var emp in _employees) {
            if (_attendanceData.containsKey(emp.id)) {
              _attendanceData[emp.id]!['previous_bulk_advance'] = 0.0;
              _attendanceData[emp.id]!['bulk_advance'] = 0.0;
            }
          }
        }
      }

      final dateStr = FormatUtils.formatDateForApi(widget.selectedDate!);
      var attendanceRecords = await ApiService.getAttendance(
        sector: widget.includedSectorCodes != null ? null : widget.selectedSector,
        date: dateStr,
      );
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        attendanceRecords = attendanceRecords.where((r) => widget.includedSectorCodes!.contains(r['sector']?.toString())).toList();
      }

      // If there's an existing record for this date, load its advance_taken and advance_paid
      // Otherwise, they remain 0 (only outstanding_advance and bulk_advance carry forward)
      for (var record in attendanceRecords) {
        final empIdStr = record['employee_id'].toString();
        final emp = _employees.firstWhere((e) => e.id == empIdStr, orElse: () => _employees.first);
        if (_attendanceData.containsKey(emp.id)) {
          final data = _attendanceData[emp.id]!;
          
          // OUTSTANDING ADVANCE CALCULATION (Independent)
          final previous = FormatUtils.parseDecimal(data['previous_outstanding']);
          final taken = FormatUtils.parseDecimal(record['advance_taken']);
          final paid = FormatUtils.parseDecimal(record['advance_paid']);
          // Calculate: previous outstanding + advance taken - advance paid
          // This is completely independent from bulk advance
          final newOutstanding = previous + taken - paid;
          
          // BULK ADVANCE CALCULATION (Independent - NOT added to outstanding advance)
          // Use the previous_bulk_advance that was loaded (from most recent record up to previous date)
          final previousBulk = FormatUtils.parseDecimal(data['previous_bulk_advance']);
          final bulkTaken = FormatUtils.parseDecimal(record['bulk_advance_taken']);
          final bulkPaid = FormatUtils.parseDecimal(record['bulk_advance_paid']);
          // Calculate: previous bulk advance + bulk advance taken - bulk advance paid
          // This ensures bulk advance persists until fully paid off
          // If previousBulk is 10000, bulkTaken is 0, bulkPaid is 0, then bulk_advance = 10000
          final newBulkAdvance = previousBulk + bulkTaken - bulkPaid;
          
          final status = record['status'] as String?;
          final otHours = FormatUtils.parseDecimal(record['ot_hours']);

          _attendanceData[emp.id] = {
            'status': status,
            'ot_hours': otHours,  // Load OT hours if record exists for this date
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
      // Also ensure status remains null if no record exists for this date
      for (var emp in _employees) {
        if (_attendanceData.containsKey(emp.id)) {
          final data = _attendanceData[emp.id]!;
          // If bulk_advance is not set or is 0, but previous_bulk_advance has a value, use previous
          // This handles the case where there's no existing record for this date
          final currentBulk = FormatUtils.parseDecimal(data['bulk_advance']);
          final prevBulk = FormatUtils.parseDecimal(data['previous_bulk_advance']);
          if (currentBulk == 0 && prevBulk > 0) {
            // No record exists for this date, so bulk_advance should carry forward
            data['bulk_advance'] = prevBulk;
          }
          // Ensure status is null if no record was found for this employee on this date
          // (This is already handled above, but double-check to be safe)
          if (data['status'] == null && !attendanceRecords.any((r) => r['employee_id'].toString() == emp.id)) {
            data['status'] = null; // Explicitly set to null for employees without records
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


  void _recalculateOutstanding() {
    for (var emp in _employees) {
      if (_attendanceData.containsKey(emp.id)) {
        final data = _attendanceData[emp.id]!;
        final previous = FormatUtils.parseDecimal(data['previous_outstanding']);
        final taken = FormatUtils.parseDecimal(data['advance_taken']);
        final paid = FormatUtils.parseDecimal(data['advance_paid']);
        data['outstanding_advance'] = previous + taken - paid;
        
        // Recalculate bulk advance
        final previousBulk = FormatUtils.parseDecimal(data['previous_bulk_advance']);
        final bulkTaken = FormatUtils.parseDecimal(data['bulk_advance_taken']);
        final bulkPaid = FormatUtils.parseDecimal(data['bulk_advance_paid']);
        data['bulk_advance'] = previousBulk + bulkTaken - bulkPaid;
      }
    }
    setState(() {});
  }

  Future<bool> saveAttendance() async {
    if (widget.selectedDate == null) return false;

    final dateStr = FormatUtils.formatDateForApi(widget.selectedDate!);

    setState(() => _isLoading = true);
    try {
      // Recalculate outstanding advance and bulk advance before saving to ensure they're up to date
      _recalculateOutstanding();
      
      // Only save employees that have a status selected or have been edited
      // Filter to include employees with status or with any advance/bulk advance/OT hours changes
      final attendanceRecords = _employees
          .where((emp) {
            final data = _attendanceData[emp.id];
            // Save if employee has a status OR if they have advance/bulk advance/OT hours changes
            return data != null && (
              data['status'] != null ||
              (data['ot_hours'] != null && (FormatUtils.parseDecimal(data['ot_hours']) > 0.0)) ||
              (data['advance_taken'] != null && (FormatUtils.parseDecimal(data['advance_taken']) > 0.0)) ||
              (data['advance_paid'] != null && (FormatUtils.parseDecimal(data['advance_paid']) > 0.0)) ||
              (data['bulk_advance_taken'] != null && (FormatUtils.parseDecimal(data['bulk_advance_taken']) > 0.0)) ||
              (data['bulk_advance_paid'] != null && (FormatUtils.parseDecimal(data['bulk_advance_paid']) > 0.0))
            );
          })
          .map((emp) {
            final data = _attendanceData[emp.id] ?? {};
            final previousBulk = FormatUtils.parseDecimal(data['previous_bulk_advance']);
            final bulkTaken = FormatUtils.parseDecimal(data['bulk_advance_taken']);
            final bulkPaid = FormatUtils.parseDecimal(data['bulk_advance_paid']);
            
            // Ensure bulk_advance is calculated correctly before saving
            // It should be: previous_bulk_advance + bulk_advance_taken - bulk_advance_paid
            // This ensures bulk advance persists across dates until fully paid off
            final finalBulkAdvance = previousBulk + bulkTaken - bulkPaid;
            
            return {
              'employee_id': int.parse(emp.id),
              'employee_name': emp.name,
              'sector': widget.selectedSector ?? emp.sector,
              'date': dateStr,
              'status': data['status'] ?? 'present', // Default to 'present' if not set
              'ot_hours': FormatUtils.parseDecimal(data['ot_hours'] ?? 0.0),
              'outstanding_advance': FormatUtils.parseDecimal(data['outstanding_advance']),
              'advance_taken': FormatUtils.parseDecimal(data['advance_taken']),
              'advance_paid': FormatUtils.parseDecimal(data['advance_paid']),
              'bulk_advance': finalBulkAdvance,  // Use calculated value to ensure persistence
              'bulk_advance_taken': bulkTaken,
              'bulk_advance_paid': bulkPaid,
            };
          })
          .toList();

      if (attendanceRecords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes to save. Please select at least one employee status, enter OT hours, or enter advance details.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return false;
      }

      await ApiService.bulkSaveAttendance(attendanceRecords);
      // Reload data to reflect saved changes
      await _loadData();
      setState(() => _isLoading = false);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDate == null) {
      return const Center(
        child: Text(
          'Please select date',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (widget.includedSectorCodes == null && widget.selectedSector == null && !widget.isAdmin) {
      return const Center(
        child: Text(
          'Please select a sector from Home page',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final showSectorColumn = (widget.isAdmin && widget.selectedSector == null) || widget.includedSectorCodes != null;

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? Center(
                      child: Text(
                        (widget.selectedSector == null && widget.isAdmin) || widget.includedSectorCodes != null
                            ? 'No employees found'
                            : 'No employees in selected sector',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildAttendanceTable(showSectorColumn),
                      ),
                    ),
        ),
      ],
    );
  }

  double _attendanceTableWidth(bool showSectorColumn) {
    final n = showSectorColumn ? 10 : 9;
    double w = showSectorColumn ? _colSector : 0;
    w += _colName + _colStatus + _colOt + _colMoney * 6;
    return w + (n - 1) * _colSpacing;
  }

  Widget _buildAttendanceTable(bool showSectorColumn) {
    final totalWidth = _attendanceTableWidth(showSectorColumn);
    final List<Widget> headerChildren = [];
    void addCol(double w, Widget c) {
      if (headerChildren.isNotEmpty) headerChildren.add(SizedBox(width: _colSpacing));
      headerChildren.add(SizedBox(width: w, child: c));
    }
    if (showSectorColumn) {
      addCol(_colSector, InkWell(
        onTap: () {
          setState(() {
            _sortAscending = !_sortAscending;
            _employees.sort((a, b) {
              final aName = _getSectorName(a.sector).toLowerCase();
              final bName = _getSectorName(b.sector).toLowerCase();
              return _sortAscending ? aName.compareTo(bName) : bName.compareTo(aName);
            });
          });
        },
        child: const Text('Sector'),
      ));
    }
    addCol(_colName, const Text('Name'));
    addCol(_colStatus, const Text('Status'));
    addCol(_colOt, const Text('OT in Hours'));
    addCol(_colMoney, const Text('Outstanding Advance'));
    addCol(_colMoney, const Text('Advance Taken'));
    addCol(_colMoney, const Text('Advance Paid'));
    addCol(_colMoney, const Text('Bulk Advance'));
    addCol(_colMoney, const Text('Bulk Advance Taken'));
    addCol(_colMoney, const Text('Bulk Advance Paid'));

    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _headerHeight,
      headerBuilder: (context) => Material(
        color: Colors.blue.shade100,
        child: Row(children: headerChildren),
      ),
      rowCount: _employees.length,
      rowBuilder: (context, index) {
        final employee = _employees[index];
        final data = _attendanceData[employee.id] ?? {
          'status': null,
          'ot_hours': 0.0,
          'outstanding_advance': 0.0,
          'advance_taken': 0.0,
          'advance_paid': 0.0,
          'bulk_advance': 0.0,
          'bulk_advance_taken': 0.0,
          'bulk_advance_paid': 0.0,
        };
        final List<Widget> rowChildren = [];
        void addCell(double w, Widget c) {
          if (rowChildren.isNotEmpty) rowChildren.add(SizedBox(width: _colSpacing));
          rowChildren.add(SizedBox(width: w, child: c));
        }
        if (showSectorColumn) addCell(_colSector, Text(_getSectorName(employee.sector)));
        addCell(_colName, Text(employee.name));
        addCell(_colStatus, widget.isEditMode
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
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['status'] = value;
                  });
                },
              )
            : Text(
                data['status'] != null ? data['status'].toString().toUpperCase() : 'Not Set',
                style: TextStyle(color: data['status'] == null ? Colors.grey : null),
              ));
        addCell(_colOt, widget.isEditMode
            ? SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (data['ot_hours'] ?? 0.0).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['ot_hours'] = double.tryParse(value) ?? 0.0;
                  },
                ),
              )
            : Text(
                '${(data['ot_hours'] ?? 0.0).toStringAsFixed(2)} hrs',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
              ));
        addCell(_colMoney, Text(
          '₹${(data['outstanding_advance'] ?? 0.0).toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
        ));
        addCell(_colMoney, widget.isEditMode
            ? SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (data['advance_taken'] ?? 0.0).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['advance_taken'] = double.tryParse(value) ?? 0.0;
                    _recalculateOutstanding();
                  },
                ),
              )
            : Text('₹${(data['advance_taken'] ?? 0.0).toStringAsFixed(2)}'));
        addCell(_colMoney, widget.isEditMode
            ? SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (data['advance_paid'] ?? 0.0).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['advance_paid'] = double.tryParse(value) ?? 0.0;
                    _recalculateOutstanding();
                  },
                ),
              )
            : Text('₹${(data['advance_paid'] ?? 0.0).toStringAsFixed(2)}'));
        addCell(_colMoney, Text(
          '₹${(data['bulk_advance'] ?? 0.0).toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
        ));
        addCell(_colMoney, widget.isEditMode
            ? SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (data['bulk_advance_taken'] ?? 0.0).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['bulk_advance_taken'] = double.tryParse(value) ?? 0.0;
                    _recalculateOutstanding();
                  },
                ),
              )
            : Text('₹${(data['bulk_advance_taken'] ?? 0.0).toStringAsFixed(2)}'));
        addCell(_colMoney, widget.isEditMode
            ? SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (data['bulk_advance_paid'] ?? 0.0).toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (value) {
                    _attendanceData[employee.id] ??= {};
                    _attendanceData[employee.id]!['bulk_advance_paid'] = double.tryParse(value) ?? 0.0;
                    _recalculateOutstanding();
                  },
                ),
              )
            : Text('₹${(data['bulk_advance_paid'] ?? 0.0).toStringAsFixed(2)}'));
        return Row(children: rowChildren);
      },
    );
  }
}

