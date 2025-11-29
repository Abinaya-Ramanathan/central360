import 'package:flutter/material.dart';
import 'attendance_tab_content.dart';
import 'present_days_count_tab_content.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AttendanceAdvanceScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isAdmin;

  const AttendanceAdvanceScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isAdmin = false,
  });

  @override
  State<AttendanceAdvanceScreen> createState() => _AttendanceAdvanceScreenState();
}

class _AttendanceAdvanceScreenState extends State<AttendanceAdvanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedMonth;
  DateTime? _selectedDate;
  List<Sector> _sectors = [];
  List<Map<String, dynamic>> _advanceDetails = [];
  bool _isLoadingAdvance = false;
  bool _sortAscendingAdvance = true; // Sort direction for Sector column

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime.now().month;
    _selectedDate = DateTime.now();
    _loadSectors();
    _loadAdvanceDetails();
    
    // Add listener to reload advance details when switching to Advance Details tab
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        // User switched to Advance Details tab
        _loadAdvanceDetails();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _loadAdvanceDetails() async {
    if (_selectedDate == null) return;
    
    setState(() => _isLoadingAdvance = true);
    try {
      // Get all employees (filtered by sector if selected)
      List<Employee> employees;
      if (widget.selectedSector == null && widget.isAdmin) {
        employees = await ApiService.getEmployees();
      } else if (widget.selectedSector != null) {
        employees = await ApiService.getEmployeesBySector(widget.selectedSector!);
      } else {
        employees = [];
      }

      // Use the selected date (same as Attendance Entry tab)
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final advanceList = <Map<String, dynamic>>[];

      // For each employee, get the most recent outstanding_advance and bulk_advance up to and including the selected date
      // This will persist across dates until it becomes 0
      for (var employee in employees) {
        try {
          // Get the most recent outstanding_advance from attendance records
          // This endpoint returns the outstanding_advance from the most recent record up to and including the date
          // The outstanding_advance field in attendance records is already calculated cumulatively
          // (previous + advance_taken - advance_paid) and persists until paid off
          final outstandingAdvance = await ApiService.getOutstandingAdvance(employee.id, dateStr);
          
          // Get the most recent bulk_advance from attendance records
          final bulkAdvance = await ApiService.getBulkAdvance(employee.id, dateStr);
          
          // Only show employees with outstanding advance > 0 or bulk advance > 0
          // Use a small epsilon to handle floating point precision issues
          if (outstandingAdvance > 0.01 || bulkAdvance > 0.01) {
            advanceList.add({
              'employee_id': employee.id,
              'employee_name': employee.name,
              'sector_code': employee.sector,
              'outstanding_advance': outstandingAdvance,
              'bulk_advance': bulkAdvance,
            });
          }
        } catch (e) {
          // Skip employees with errors
        }
      }

      if (mounted) {
        setState(() {
          _advanceDetails = advanceList;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading advance details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAdvance = false);
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
      });
      // Reload advance details when month changes
      _loadAdvanceDetails();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // Reload advance details when date changes
      _loadAdvanceDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance and Advance Details'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Attendance Entry'),
            Tab(text: 'Advance Details'),
            Tab(text: 'Present Days Count'),
          ],
        ),
        actions: [
          // Sector Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 4),
                Text(
                  widget.selectedSector != null
                      ? _getSectorName(widget.selectedSector)
                      : 'All Sectors',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 4),
                Text(widget.username, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home),
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
          IconButton(
            icon: const Icon(Icons.logout),
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
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Attendance Entry Tab
          Column(
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
                                ? [
                                    'January',
                                    'February',
                                    'March',
                                    'April',
                                    'May',
                                    'June',
                                    'July',
                                    'August',
                                    'September',
                                    'October',
                                    'November',
                                    'December'
                                  ][_selectedMonth! - 1]
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
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Select Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedDate != null
                                ? _selectedDate!.toIso8601String().split('T')[0]
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Attendance Table
              Expanded(
                child: AttendanceTabContent(
                  selectedSector: widget.selectedSector,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isAdmin: widget.isAdmin,
                ),
              ),
              // Add a listener to refresh advance details when attendance is saved
              // This will be handled by the refresh button in Advance Details tab
            ],
          ),
          // Advance Details Tab
          Column(
            children: [
              // Refresh button
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Employees with Outstanding Advance / Bulk Advance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadAdvanceDetails,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              // Advance Details Table
              Expanded(
                child: _isLoadingAdvance
                    ? const Center(child: CircularProgressIndicator())
                    : _advanceDetails.isEmpty
                        ? Center(
                            child: Text(
                              'No employees with outstanding advance',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
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
                                      Colors.green.shade100,
                                    ),
                                    sortColumnIndex: (widget.selectedSector == null && widget.isAdmin) ? 0 : null,
                                    sortAscending: _sortAscendingAdvance,
                                    columns: [
                                      if (widget.selectedSector == null && widget.isAdmin)
                                        DataColumn(
                                          label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                          onSort: (columnIndex, ascending) {
                                            setState(() {
                                              _sortAscendingAdvance = ascending;
                                              _advanceDetails.sort((a, b) {
                                                final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                                final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                                return ascending
                                                    ? aName.compareTo(bName)
                                                    : bName.compareTo(aName);
                                              });
                                            });
                                          },
                                        ),
                                      const DataColumn(
                                        label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const DataColumn(
                                        label: Text('Outstanding Advance', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      // Only show Bulk Advance column if any employee has bulk_advance > 0
                                      if (_advanceDetails.any((detail) => ((detail['bulk_advance'] as num?)?.toDouble() ?? 0.0) > 0.01))
                                        const DataColumn(
                                          label: Text('Bulk Advance', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                    rows: _advanceDetails.map((detail) {
                                      final bulkAdvance = (detail['bulk_advance'] as num?)?.toDouble() ?? 0.0;
                                      final showBulkColumn = _advanceDetails.any((d) => ((d['bulk_advance'] as num?)?.toDouble() ?? 0.0) > 0.01);
                                      return DataRow(
                                        cells: [
                                          if (widget.selectedSector == null && widget.isAdmin)
                                            DataCell(Text(_getSectorName(detail['sector_code']?.toString()))),
                                          DataCell(Text(detail['employee_name']?.toString() ?? 'N/A')),
                                          DataCell(
                                            Text(
                                              '₹${(detail['outstanding_advance'] as num).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                          // Only show Bulk Advance cell if column is shown
                                          if (showBulkColumn)
                                            DataCell(
                                              Text(
                                                bulkAdvance > 0.01
                                                    ? '₹${bulkAdvance.toStringAsFixed(2)}'
                                                    : '₹0.00',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: bulkAdvance > 0.01 ? Colors.blue.shade700 : Colors.grey,
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
          ),
          // Present Days Count Tab
          PresentDaysCountTabContent(
            selectedSector: widget.selectedSector,
            isAdmin: widget.isAdmin,
          ),
        ],
      ),
    );
  }
}

