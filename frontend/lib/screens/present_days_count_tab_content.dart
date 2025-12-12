import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

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
        final dateStr = date.toIso8601String().split('T')[0];
        
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
                                ? _fromDatePresent!.toIso8601String().split('T')[0]
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
                                ? _toDatePresent!.toIso8601String().split('T')[0]
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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Employees Table
                              if (_employees.isNotEmpty)
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                                    columns: const [
                                      DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('No.Of.Days.Present', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total OT in hours', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _employees.map((employee) {
                                      final presentDays = _presentDaysCount[employee.id] ?? 0;
                                      final totalOtHours = _totalOtHours[employee.id] ?? 0.0;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(employee.name)),
                                          DataCell(
                                            Text(
                                              presentDays.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: presentDays > 0 ? Colors.green.shade700 : Colors.grey,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              totalOtHours.toStringAsFixed(2),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: totalOtHours > 0 ? Colors.orange.shade700 : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              // Rent Vehicles Table
                              if (_rentVehicles.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(Colors.teal.shade100),
                                    columns: const [
                                      DataColumn(label: Text('Vehicle Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('No.Of.Days.Present', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _rentVehicles.map((vehicle) {
                                      final vehicleId = vehicle['id'] as int;
                                      final presentDays = _rentVehiclePresentDaysCount[vehicleId] ?? 0.0;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(vehicle['vehicle_name']?.toString() ?? 'N/A')),
                                          DataCell(
                                            Text(
                                              presentDays == presentDays.toInt() 
                                                  ? presentDays.toInt().toString()
                                                  : presentDays.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: presentDays > 0 ? Colors.teal.shade700 : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                              // Daily Mining Activity Table
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
                                      DataTable(
                                        headingRowColor: WidgetStateProperty.all(Colors.amber.shade100),
                                        columns: const [
                                          DataColumn(label: Text('Activity Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: _miningActivities.map((activity) {
                                          final activityId = activity['id'] as int;
                                          final totalQuantity = _miningActivityTotals[activityId] ?? 0.0;
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(activity['activity_name']?.toString() ?? 'N/A')),
                                              DataCell(
                                                Text(
                                                  totalQuantity.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: totalQuantity > 0 ? Colors.amber.shade700 : Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ],
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

