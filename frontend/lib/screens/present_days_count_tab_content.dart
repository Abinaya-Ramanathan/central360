import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../widgets/fixed_header_table.dart';

class PresentDaysCountTabContent extends StatefulWidget {
  final String? selectedSector;
  final bool isAdmin;

  const PresentDaysCountTabContent({
    super.key,
    this.selectedSector,
    this.isAdmin = false,
  });

  @override
  State<PresentDaysCountTabContent> createState() => _PresentDaysCountTabContentState();
}

class _PresentDaysCountTabContentState extends State<PresentDaysCountTabContent> {
  DateTime? _fromDatePresent;
  DateTime? _toDatePresent;
  List<Employee> _employees = [];
  Map<String, double> _presentDaysCount = {}; // Map of employee_id to present days count (supports 0.5 for halfday)
  Map<String, double> _totalOtHours = {}; // Map of employee_id to total OT hours
  List<Map<String, dynamic>> _rentVehicles = [];
  Map<int, double> _rentVehiclePresentDaysCount = {}; // Map of vehicle_id to present days count (supports 0.5 for halfday)
  List<Map<String, dynamic>> _miningActivities = [];
  Map<int, double> _miningActivityTotals = {}; // Map of activity_id to total quantity
  bool _isLoading = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _employeesTableScrollController = ScrollController();
  final ScrollController _rentVehiclesTableScrollController = ScrollController();
  final ScrollController _miningTableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fromDatePresent = DateTime.now();
    _toDatePresent = DateTime.now();
    if (widget.selectedSector != null || widget.isAdmin) {
      _loadEmployees();
      _loadRentVehicles();
    }
    // Load mining activities if All sector or SSBM
    if (widget.selectedSector == null || widget.selectedSector == 'SSBM') {
      _loadMiningActivities();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _employeesTableScrollController.dispose();
    _rentVehiclesTableScrollController.dispose();
    _miningTableScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PresentDaysCountTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload employees and vehicles when sector changes
    if (widget.selectedSector != oldWidget.selectedSector || widget.isAdmin != oldWidget.isAdmin) {
      if (widget.selectedSector != null || widget.isAdmin) {
        _loadEmployees();
        _loadRentVehicles();
      } else {
        // Clear data if no sector selected
        setState(() {
          _employees = [];
          _rentVehicles = [];
          _presentDaysCount = {};
          _totalOtHours = {};
          _rentVehiclePresentDaysCount = {};
        });
      }
      // Reload mining activities if All sector or SSBM
      if (widget.selectedSector == null || widget.selectedSector == 'SSBM') {
        _loadMiningActivities();
      } else {
        setState(() {
          _miningActivities = [];
          _miningActivityTotals = {};
        });
      }
    }
  }


  Future<void> _loadRentVehicles() async {
    try {
      List<Map<String, dynamic>> vehicles;
      if (widget.selectedSector == null && widget.isAdmin) {
        vehicles = await ApiService.getRentVehicles();
      } else if (widget.selectedSector != null) {
        vehicles = await ApiService.getRentVehicles(sector: widget.selectedSector);
      } else {
        vehicles = [];
      }

      if (mounted) {
        setState(() {
          _rentVehicles = vehicles;
          _rentVehiclePresentDaysCount = {for (var vehicle in vehicles) vehicle['id'] as int: 0};
        });
      }
    } catch (e) {
      if (mounted) {
        // Silently fail
      }
    }
  }

  Future<void> _loadMiningActivities() async {
    // Load mining activities only if All sector (null) or SSBM
    if (widget.selectedSector != null && widget.selectedSector != 'SSBM') {
      if (mounted) {
        setState(() {
          _miningActivities = [];
          _miningActivityTotals = {};
        });
      }
      return;
    }

    try {
      List<Map<String, dynamic>> activities;
      if (widget.selectedSector == null && widget.isAdmin) {
        // All sectors - load all mining activities
        activities = await ApiService.getMiningActivities();
      } else if (widget.selectedSector == 'SSBM') {
        // SSBM sector - load only SSBM activities
        activities = await ApiService.getMiningActivities(sector: 'SSBM');
      } else {
        activities = [];
      }

      if (mounted) {
        setState(() {
          _miningActivities = activities;
          _miningActivityTotals = {for (var activity in activities) activity['id'] as int: 0.0};
        });
      }
    } catch (e) {
      if (mounted) {
        // Silently fail
      }
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      List<Employee> employees;
      if (widget.selectedSector == null && widget.isAdmin) {
        // Load all employees in a single call
        employees = await ApiService.getEmployees();
      } else if (widget.selectedSector != null) {
        employees = await ApiService.getEmployeesBySector(widget.selectedSector!);
      } else {
        employees = [];
      }

      if (mounted) {
        setState(() {
          _employees = employees;
          // Initialize present days count to 0 for all employees
          _presentDaysCount = {for (var emp in employees) emp.id: 0};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _selectFromDatePresent() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDatePresent ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDatePresent = picked;
      });
      if (_fromDatePresent != null && _toDatePresent != null) {
        _calculatePresentDaysCount();
      }
    }
  }

  Future<void> _selectToDatePresent() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDatePresent ?? (_fromDatePresent ?? DateTime.now()),
      firstDate: _fromDatePresent ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDatePresent = picked;
      });
      if (_fromDatePresent != null && _toDatePresent != null) {
        _calculatePresentDaysCount();
      }
    }
  }

  Future<void> _calculatePresentDaysCount() async {
    if (_fromDatePresent == null || _toDatePresent == null) {
      return;
    }

    // Generate list of dates between from and to date
    final List<DateTime> dateRange = [];
    var currentDate = DateTime(_fromDatePresent!.year, _fromDatePresent!.month, _fromDatePresent!.day);
    final endDate = DateTime(_toDatePresent!.year, _toDatePresent!.month, _toDatePresent!.day);
    
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      dateRange.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Ensure employees and vehicles are loaded before calculating
    if (_employees.isEmpty && (widget.selectedSector != null || widget.isAdmin)) {
      await _loadEmployees();
    }
    if (_rentVehicles.isEmpty && (widget.selectedSector != null || widget.isAdmin)) {
      await _loadRentVehicles();
    }
    // Ensure mining activities are loaded if All sector or SSBM
    if (_miningActivities.isEmpty && (widget.selectedSector == null || widget.selectedSector == 'SSBM')) {
      await _loadMiningActivities();
    }

    if (_employees.isEmpty && _rentVehicles.isEmpty && _miningActivities.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No employees, vehicles, or mining activities found for the selected sector'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Initialize all counts to 0
      _presentDaysCount = {for (var emp in _employees) emp.id: 0.0};
      _totalOtHours = {for (var emp in _employees) emp.id: 0.0};
      _rentVehiclePresentDaysCount = {for (var vehicle in _rentVehicles) vehicle['id'] as int: 0.0};
      _miningActivityTotals = {for (var activity in _miningActivities) activity['id'] as int: 0.0};

      // Query attendance for each date in range
      for (var date in dateRange) {
        final dateStr = FormatUtils.formatDateForApi(date);
        
        try {
          // Get employee attendance
          final attendanceRecords = await ApiService.getAttendance(
            sector: widget.selectedSector,
            date: dateStr,
          );

          // Count status for each employee (Present=1, Absent=0, Halfday=0.5)
          // Also sum OT hours for each employee
          for (var record in attendanceRecords) {
            // Handle both int and string employee_id formats
            final empIdRaw = record['employee_id'];
            final empId = empIdRaw?.toString();
            final status = record['status']?.toString().toLowerCase();
            
            if (empId != null) {
              // Count status (only if status exists)
              if (status != null) {
                double count = 0.0;
                if (status == 'present') {
                  count = 1.0;
                } else if (status == 'halfday') {
                  count = 0.5;
                } else if (status == 'absent') {
                  count = 0.0;
                }
                _presentDaysCount[empId] = (_presentDaysCount[empId] ?? 0.0) + count;
              }
              
              // Sum OT hours - handle various data types from database
              final otHoursRaw = record['ot_hours'];
              double otHours = 0.0;
              if (otHoursRaw != null) {
                if (otHoursRaw is num) {
                  otHours = otHoursRaw.toDouble();
                } else if (otHoursRaw is String) {
                  otHours = double.tryParse(otHoursRaw) ?? 0.0;
                } else {
                  otHours = double.tryParse(otHoursRaw.toString()) ?? 0.0;
                }
              }
              
              // Always accumulate OT hours (even if 0, to ensure we process all records)
              _totalOtHours[empId] = (_totalOtHours[empId] ?? 0.0) + otHours;
              
              // Debug: Print OT hours for verification
              if (otHours > 0) {
                debugPrint('Date $dateStr - Employee $empId: OT Hours = $otHours, Total = ${_totalOtHours[empId]}');
              }
            }
          }

          // Get rent vehicle attendance
          final rentVehicleAttendance = await ApiService.getRentVehicleAttendance(
            sector: widget.selectedSector,
            date: dateStr,
          );

          // Count status for each rent vehicle (Present=1, Absent=0, Halfday=0.5)
          for (var record in rentVehicleAttendance) {
            final vehicleId = record['vehicle_id'] as int?;
            final status = record['status']?.toString().toLowerCase();
            
            if (vehicleId != null && status != null) {
              double count = 0.0;
              if (status == 'present') {
                count = 1.0;
              } else if (status == 'halfday') {
                count = 0.5;
              } else if (status == 'absent') {
                count = 0.0;
              }
              _rentVehiclePresentDaysCount[vehicleId] = (_rentVehiclePresentDaysCount[vehicleId] ?? 0.0) + count;
            }
          }

          // Get daily mining activities for this date
          try {
            final dailyMiningActivities = await ApiService.getDailyMiningActivities(
              date: dateStr,
              sector: widget.selectedSector,
            );

            // Sum quantities for each activity
            for (var entry in dailyMiningActivities) {
              final activityId = entry['activity_id'] as int?;
              final quantityRaw = entry['quantity'];
              
              if (activityId != null && quantityRaw != null) {
                double quantity = 0.0;
                if (quantityRaw is num) {
                  quantity = quantityRaw.toDouble();
                } else if (quantityRaw is String) {
                  quantity = double.tryParse(quantityRaw) ?? 0.0;
                } else {
                  quantity = double.tryParse(quantityRaw.toString()) ?? 0.0;
                }
                
                _miningActivityTotals[activityId] = (_miningActivityTotals[activityId] ?? 0.0) + quantity;
              }
            }
          } catch (e) {
            debugPrint('Error loading daily mining activities for date $dateStr: $e');
            // Continue with other dates even if one fails
          }
        } catch (e) {
          debugPrint('Error loading attendance for date $dateStr: $e');
          // Continue with other dates even if one fails
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating present days: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // From Date and To Date Selection
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectFromDatePresent,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'From Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: _fromDatePresent != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _fromDatePresent = null;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _fromDatePresent != null
                                ? FormatUtils.formatDateForApi(_fromDatePresent!)
                                : 'From Date',
                            style: TextStyle(
                              color: _fromDatePresent != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectToDatePresent,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'To Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: _toDatePresent != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _toDatePresent = null;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _toDatePresent != null
                                ? FormatUtils.formatDateForApi(_toDatePresent!)
                                : 'To Date',
                            style: TextStyle(
                              color: _toDatePresent != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_fromDatePresent != null && _toDatePresent != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _calculatePresentDaysCount,
                    tooltip: 'Recalculate',
                  ),
                ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_employees.isEmpty && _rentVehicles.isEmpty && _miningActivities.isEmpty)
                  ? const Center(
                      child: Text(
                        'No employees, rent vehicles, or mining activities in selected sector',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_employees.isNotEmpty)
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildPresentEmployeesTable(),
                              ),
                            if (_rentVehicles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildPresentRentVehiclesTable(),
                              ),
                            ],
                            if (_miningActivities.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        'Daily Mining Activity',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ),
                                    _buildPresentMiningTable(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  static const double _headerHeight = 52;
  static const double _rowHeight = 96;
  static const double _colName = 150;
  static const double _colDays = 120;
  static const double _colOt = 120;
  static const double _colSalary = 130;
  static const double _colSpacing = 20;

  Widget _buildPresentEmployeesTable() {
    const totalWidth = _colName + _colSpacing + _colDays + _colSpacing + _colOt + _colSpacing + _colSalary;
    return FixedHeaderTable(
      horizontalScrollController: _employeesTableScrollController,
      totalWidth: (_colSpacing + _colDays + _colSpacing + _colOt + _colSpacing + _colSalary).toDouble(),
      headerHeight: _headerHeight,
      rowExtent: _rowHeight,
      leadingWidth: _colName,
      leadingHeaderBuilder: (context) => Material(
        color: Colors.green.shade100,
        child: const SizedBox(
          width: _colName,
          child: Align(alignment: Alignment.centerLeft, child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
      ),
      headerBuilder: (context) => Material(
        color: Colors.green.shade100,
        child: const Row(
          children: [
            SizedBox(width: _colSpacing),
            SizedBox(width: _colDays, child: Text('No.Of.Days.Present', style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: _colSpacing),
            SizedBox(width: _colOt, child: Text('Total OT in hours', style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(width: _colSpacing),
            SizedBox(width: _colSalary, child: Text('Calculated Salary', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
      rowCount: _employees.length,
      leadingRowBuilder: (context, index) {
        final employee = _employees[index];
        return SizedBox(
          width: _colName,
          child: Text(employee.name),
        );
      },
      rowBuilder: (context, index) {
        final employee = _employees[index];
        final presentDays = _presentDaysCount[employee.id] ?? 0;
        final totalOtHours = _totalOtHours[employee.id] ?? 0.0;
        final calculatedSalary = presentDays * employee.dailySalary;
        return Row(
          children: [
            const SizedBox(width: _colSpacing),
            SizedBox(width: _colDays, child: Text(presentDays.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: presentDays > 0 ? Colors.green.shade700 : Colors.grey))),
            const SizedBox(width: _colSpacing),
            SizedBox(width: _colOt, child: Text(totalOtHours.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: totalOtHours > 0 ? Colors.orange.shade700 : Colors.grey))),
            const SizedBox(width: _colSpacing),
            SizedBox(width: _colSalary, child: Text('₹${calculatedSalary.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: calculatedSalary > 0 ? Colors.blue.shade700 : Colors.grey))),
          ],
        );
      },
    );
  }

  static const double _rentColName = 150;
  static const double _rentColDays = 120;
  static const double _rentTotalWidth = _rentColName + _colSpacing + _rentColDays;

  Widget _buildPresentRentVehiclesTable() {
    return FixedHeaderTable(
      horizontalScrollController: _rentVehiclesTableScrollController,
      totalWidth: (_colSpacing + _rentColDays).toDouble(),
      headerHeight: _headerHeight,
      rowExtent: _rowHeight,
      leadingWidth: _rentColName,
      leadingHeaderBuilder: (context) => Material(
        color: Colors.teal.shade100,
        child: const SizedBox(
          width: _rentColName,
          child: Align(alignment: Alignment.centerLeft, child: Text('Vehicle Name', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
      ),
      headerBuilder: (context) => Material(
        color: Colors.teal.shade100,
        child: const Row(
          children: [
            SizedBox(width: _colSpacing),
            SizedBox(width: _rentColDays, child: Text('No.Of.Days.Present', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
      rowCount: _rentVehicles.length,
      leadingRowBuilder: (context, index) {
        final vehicle = _rentVehicles[index];
        return SizedBox(
          width: _rentColName,
          child: Text(vehicle['vehicle_name']?.toString() ?? 'N/A'),
        );
      },
      rowBuilder: (context, index) {
        final vehicle = _rentVehicles[index];
        final vehicleId = vehicle['id'] as int;
        final presentDays = _rentVehiclePresentDaysCount[vehicleId] ?? 0.0;
        return Row(
          children: [
            const SizedBox(width: _colSpacing),
            SizedBox(width: _rentColDays, child: Text(presentDays == presentDays.toInt() ? presentDays.toInt().toString() : presentDays.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: presentDays > 0 ? Colors.teal.shade700 : Colors.grey))),
          ],
        );
      },
    );
  }

  static const double _miningColName = 200;
  static const double _miningColQty = 120;
  static const double _miningTotalWidth = _miningColName + _colSpacing + _miningColQty;

  Widget _buildPresentMiningTable() {
    return FixedHeaderTable(
      horizontalScrollController: _miningTableScrollController,
      totalWidth: (_colSpacing + _miningColQty).toDouble(),
      headerHeight: _headerHeight,
      rowExtent: _rowHeight,
      leadingWidth: _miningColName,
      leadingHeaderBuilder: (context) => Material(
        color: Colors.amber.shade100,
        child: const SizedBox(
          width: _miningColName,
          child: Align(alignment: Alignment.centerLeft, child: Text('Activity Name', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
      ),
      headerBuilder: (context) => Material(
        color: Colors.amber.shade100,
        child: const Row(
          children: [
            SizedBox(width: _colSpacing),
            SizedBox(width: _miningColQty, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
      rowCount: _miningActivities.length,
      leadingRowBuilder: (context, index) {
        final activity = _miningActivities[index];
        return SizedBox(
          width: _miningColName,
          child: Text(activity['activity_name']?.toString() ?? 'N/A'),
        );
      },
      rowBuilder: (context, index) {
        final activity = _miningActivities[index];
        final activityId = activity['id'] as int;
        final totalQuantity = _miningActivityTotals[activityId] ?? 0.0;
        return Row(
          children: [
            const SizedBox(width: _colSpacing),
            SizedBox(width: _miningColQty, child: Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: totalQuantity > 0 ? Colors.amber.shade700 : Colors.grey))),
          ],
        );
      },
    );
  }
}

// Dialog widget for selecting multiple dates - compact version
class _DateRangePickerDialog extends StatefulWidget {
  final int month;
  final int year;
  final int daysInMonth;
  final List<DateTime> initiallySelectedDates;

  const _DateRangePickerDialog({
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.initiallySelectedDates,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    // Initialize selected days from initially selected dates
    _selectedDays = widget.initiallySelectedDates
        .where((date) => date.year == widget.year && date.month == widget.month)
        .map((date) => date.day)
        .toSet();
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedDays = Set.from(List.generate(widget.daysInMonth, (index) => index + 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    // Calculate the first day of the month's weekday (0 = Sunday, 6 = Saturday)
    final firstDay = DateTime(widget.year, widget.month, 1);
    final firstDayWeekday = firstDay.weekday % 7; // Convert Monday=1 to Sunday=0

    return Dialog(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title and selected count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${monthNames[widget.month - 1]} ${widget.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedDays.length} selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Weekday headers
            Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid - more compact
            SizedBox(
              height: 240, // Reduced from 400
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                itemCount: firstDayWeekday + widget.daysInMonth,
                itemBuilder: (context, index) {
                  if (index < firstDayWeekday) {
                    // Empty cells before the first day
                    return const SizedBox.shrink();
                  }
                  final day = index - firstDayWeekday + 1;
                  final date = DateTime(widget.year, widget.month, day);
                  final isSelected = _selectedDays.contains(day);
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  
                  return InkWell(
                    onTap: () => _toggleDay(day),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade700
                            : isToday
                                ? Colors.orange.shade100
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isToday
                              ? Colors.orange.shade400
                              : isSelected
                                  ? Colors.blue.shade900
                                  : Colors.transparent,
                          width: isToday || isSelected ? 1.5 : 0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDays.clear();
                    });
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: _selectAll,
                  child: const Text('Select All', style: TextStyle(fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
                FilledButton(
                  onPressed: () {
                    final selectedDates = _selectedDays.map((day) {
                      return DateTime(widget.year, widget.month, day);
                    }).toList();
                    Navigator.pop(context, selectedDates);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: Colors.blue.shade700,
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

