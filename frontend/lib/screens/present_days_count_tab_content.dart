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
  Map<String, int> _presentDaysCount = {}; // Map of employee_id to present days count
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    if (widget.selectedSector != null || widget.isAdmin) {
      _loadEmployees();
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
        _presentDaysCount = {for (var emp in _employees) emp.id: 0}; // Reset counts
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
    if (_selectedDates.isEmpty || _employees.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Initialize all counts to 0
      _presentDaysCount = {for (var emp in _employees) emp.id: 0};

      // Query attendance for each selected date
      for (var date in _selectedDates) {
        final dateStr = date.toIso8601String().split('T')[0];
        
        try {
          final attendanceRecords = await ApiService.getAttendance(
            sector: widget.selectedSector,
            date: dateStr,
          );

          // Count "present" status for each employee
          for (var record in attendanceRecords) {
            final empId = record['employee_id']?.toString();
            final status = record['status']?.toString().toLowerCase();
            
            if (empId != null && status == 'present') {
              _presentDaysCount[empId] = (_presentDaysCount[empId] ?? 0) + 1;
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
                              headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                              columns: const [
                                DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('No.Of.Days.Present', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _employees.map((employee) {
                                final presentDays = _presentDaysCount[employee.id] ?? 0;
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
                                  ],
                                );
                              }).toList(),
                            ),
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

