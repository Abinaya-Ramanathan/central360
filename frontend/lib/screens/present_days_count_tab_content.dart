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
  int? _selectedMonth;
  List<DateTime> _selectedDates = [];
  List<Employee> _employees = [];
  Map<String, double> _presentDaysCount = {}; // Map of employee_id to present days count (supports 0.5 for halfday)
  Map<String, double> _totalOtHours = {}; // Map of employee_id to total OT hours
  List<Map<String, dynamic>> _rentVehicles = [];
  Map<int, double> _rentVehiclePresentDaysCount = {}; // Map of vehicle_id to present days count (supports 0.5 for halfday)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    if (widget.selectedSector != null || widget.isAdmin) {
      _loadEmployees();
      _loadRentVehicles();
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

  Future<void> _loadEmployees() async {
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

  Future<void> _selectMonth() async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthNumber = index + 1;
              final monthNames = [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
              return ListTile(
                title: Text(monthNames[index]),
                selected: monthNumber == _selectedMonth,
                onTap: () => Navigator.pop(context, monthNumber),
              );
            },
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _selectedDates = []; // Clear selected dates when month changes
        _presentDaysCount = {for (var emp in _employees) emp.id: 0.0}; // Reset counts
        _totalOtHours = {for (var emp in _employees) emp.id: 0.0}; // Reset OT hours
        _rentVehiclePresentDaysCount = {for (var vehicle in _rentVehicles) vehicle['id'] as int: 0.0}; // Reset rent vehicle counts
      });
    }
  }

  Future<void> _selectDates() async {
    if (_selectedMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a month first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate the year (use current year or let user select)
    final now = DateTime.now();
    final year = now.year;
    
    // Calculate number of days in selected month
    final daysInMonth = DateTime(year, _selectedMonth! + 1, 0).day;

    // Show dialog to select multiple dates
    final List<DateTime>? pickedDates = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => _DateRangePickerDialog(
        month: _selectedMonth!,
        year: year,
        daysInMonth: daysInMonth,
        initiallySelectedDates: _selectedDates,
      ),
    );

    if (pickedDates != null) {
      setState(() {
        _selectedDates = List.from(pickedDates)..sort(); // Sort dates
      });
      // Calculate present days count for selected dates
      await _calculatePresentDaysCount();
    }
  }

  Future<void> _calculatePresentDaysCount() async {
    if (_selectedDates.isEmpty) {
      return;
    }

    // Ensure employees and vehicles are loaded before calculating
    if (_employees.isEmpty && (widget.selectedSector != null || widget.isAdmin)) {
      await _loadEmployees();
    }
    if (_rentVehicles.isEmpty && (widget.selectedSector != null || widget.isAdmin)) {
      await _loadRentVehicles();
    }

    if (_employees.isEmpty && _rentVehicles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No employees or vehicles found for the selected sector'),
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

      // Query attendance for each selected date
      for (var date in _selectedDates) {
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
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      children: [
        // Month and Date Selection
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectMonth,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Month',
                      prefixIcon: const Icon(Icons.calendar_month),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedMonth != null
                          ? monthNames[_selectedMonth! - 1]
                          : 'Select Month',
                      style: TextStyle(
                        color: _selectedMonth != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectDates,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Dates',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedDates.isEmpty
                          ? 'Select Dates'
                          : _selectedDates.length == 1
                              ? '${_selectedDates.first.day}/${_selectedDates.first.month}/${_selectedDates.first.year}'
                              : '${_selectedDates.first.day}/${_selectedDates.first.month} - ${_selectedDates.last.day}/${_selectedDates.last.month} (${_selectedDates.length})',
                      style: TextStyle(
                        color: _selectedDates.isNotEmpty ? Colors.black : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedDates.isNotEmpty)
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
              : (_employees.isEmpty && _rentVehicles.isEmpty)
                  ? const Center(
                      child: Text(
                        'No employees or rent vehicles in selected sector',
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

