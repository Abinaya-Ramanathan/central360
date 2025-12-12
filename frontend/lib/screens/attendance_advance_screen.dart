import 'package:flutter/material.dart';
import 'attendance_tab_content.dart';
import 'present_days_count_tab_content.dart';
import 'daily_mining_activity_tab_content.dart';
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
  DateTime? _selectedDate;
  List<Sector> _sectors = [];
  List<Map<String, dynamic>> _advanceDetails = [];
  List<Map<String, dynamic>> _filteredAdvanceDetails = [];
  final TextEditingController _advanceSearchController = TextEditingController();
  DateTime? _fromDateAdvance;
  DateTime? _toDateAdvance;
  bool _isLoadingAdvance = false;
  bool _sortAscendingAdvance = true; // Sort direction for Sector column
  List<Map<String, dynamic>> _rentVehicles = [];
  bool _isLoadingRentVehicles = false;
  Map<int, String?> _rentVehicleStatusControllers = {}; // Map of vehicle_id to status
  bool _isEditMode = false; // Edit mode for both employee and rent vehicle attendance
  Future<bool> Function()? _saveEmployeeAttendance;

  bool get _showMiningActivityTab {
    // Show tab if All sector (null) or SSBM
    return widget.selectedSector == null || widget.selectedSector == 'SSBM';
  }

  @override
  void initState() {
    super.initState();
    // Tab length: 4 base tabs + 1 mining activity tab (if visible)
    _tabController = TabController(length: _showMiningActivityTab ? 5 : 4, vsync: this);
    _selectedDate = DateTime.now();
    _loadSectors();
    _loadAdvanceDetails();
    _loadRentVehicles();
    
    // Add listener to reload data when switching tabs
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        // User switched to Advance Details tab
        _loadAdvanceDetails();
      } else if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        // User switched to Vehicle Attendance Entry tab
        _loadRentVehicles();
        _loadRentVehicleAttendance();
      } else if (_tabController.index == 4 && !_tabController.indexIsChanging && _showMiningActivityTab) {
        // User switched to Daily Mining Activity tab
        // Data will be loaded in the tab content
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _advanceSearchController.dispose();
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

  Future<void> _loadRentVehicles() async {
    setState(() => _isLoadingRentVehicles = true);
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
          // Initialize status controllers
          _rentVehicleStatusControllers = {};
          for (var vehicle in vehicles) {
            _rentVehicleStatusControllers[vehicle['id'] as int] = null;
          }
        });
        // Load attendance after vehicles are loaded
        _loadRentVehicleAttendance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rent vehicles: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRentVehicles = false);
      }
    }
  }

  Future<void> _loadRentVehicleAttendance() async {
    if (_selectedDate == null || _rentVehicles.isEmpty) return;
    
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      List<Map<String, dynamic>> attendance;
      if (widget.selectedSector == null && widget.isAdmin) {
        attendance = await ApiService.getRentVehicleAttendance(date: dateStr);
      } else if (widget.selectedSector != null) {
        attendance = await ApiService.getRentVehicleAttendance(sector: widget.selectedSector, date: dateStr);
      } else {
        attendance = [];
      }

      if (mounted) {
        setState(() {
          // Reset all vehicles to null first (to prevent carry forward from previous date)
          for (var vehicle in _rentVehicles) {
            final vehicleId = vehicle['id'] as int;
            _rentVehicleStatusControllers[vehicleId] = null;
          }
          // Update status controllers from attendance data (date-specific)
          // Only vehicles with saved attendance for this date will have a status
          for (var att in attendance) {
            final vehicleId = att['vehicle_id'] as int;
            _rentVehicleStatusControllers[vehicleId] = att['status'] as String?;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Silently fail - attendance might not exist yet
      }
    }
  }

  Future<void> _saveEmployeeAttendanceAction() async {
    if (_saveEmployeeAttendance == null) return;
    
    setState(() => _isLoadingRentVehicles = true);
    try {
      final saved = await _saveEmployeeAttendance!();
      if (saved) {
        setState(() => _isEditMode = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRentVehicles = false);
      }
    }
  }

  Future<void> _saveVehicleAttendance() async {
    if (_selectedDate == null) return;

    setState(() => _isLoadingRentVehicles = true);
    try {
      // Save rent vehicle attendance
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final records = _rentVehicles.map((vehicle) {
        return {
          'vehicle_id': vehicle['id'] as int,
          'vehicle_name': vehicle['vehicle_name'] as String,
          'sector_code': vehicle['sector_code'] as String,
          'date': dateStr,
          'status': _rentVehicleStatusControllers[vehicle['id'] as int],
        };
      }).toList();

      await ApiService.bulkSaveRentVehicleAttendance(records);
      
      // Exit edit mode
      setState(() => _isEditMode = false);
      
      // Reload rent vehicle attendance
      await _loadRentVehicleAttendance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle attendance saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving vehicle attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRentVehicles = false);
      }
    }
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

      if (employees.isNotEmpty) {
        try {
          // Use batch endpoints to fetch outstanding and bulk advances for all employees in 2 calls
          final employeeIds = employees.map((e) => e.id).toList();
          final outstandingMap = await ApiService.getOutstandingAdvanceBatch(employeeIds, dateStr);
          final bulkAdvanceMap = await ApiService.getBulkAdvanceBatch(employeeIds, dateStr);
          
          // Build advance list from batch results
          for (var employee in employees) {
            final outstandingAdvance = outstandingMap[employee.id] ?? 0.0;
            final bulkAdvance = bulkAdvanceMap[employee.id] ?? 0.0;
            
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
          }
        } catch (e) {
          debugPrint('Error loading advance details batch: $e');
        }
      }

      if (mounted) {
        setState(() {
          _advanceDetails = advanceList;
          _filterAdvanceData(_advanceSearchController.text);
        });
      }
      
      // Also trigger filter when date changes
      if (_selectedDate != null) {
        _filterAdvanceData(_advanceSearchController.text);
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

  void _filterAdvanceData(String query) {
    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_advanceDetails);
      
      // Apply date range filter if dates are selected
      if (_fromDateAdvance != null || _toDateAdvance != null) {
        filtered = filtered.where((detail) {
          // Get the date from the record - this might be in different formats
          final dateValue = detail['date'] ?? detail['attendance_date'];
          if (dateValue == null) return false;
          
          DateTime? recordDate;
          try {
            if (dateValue is DateTime) {
              recordDate = dateValue;
            } else if (dateValue is String) {
              String dateStr = dateValue;
              if (dateStr.contains('T')) {
                dateStr = dateStr.split('T')[0];
              }
              if (dateStr.contains(' ')) {
                dateStr = dateStr.split(' ')[0];
              }
              recordDate = DateTime.tryParse(dateStr);
            }
          } catch (e) {
            return false;
          }
          
          if (recordDate == null) return false;
          
          final recordDateOnly = DateTime(recordDate.year, recordDate.month, recordDate.day);
          final fromDateOnly = _fromDateAdvance != null ? DateTime(_fromDateAdvance!.year, _fromDateAdvance!.month, _fromDateAdvance!.day) : null;
          final toDateOnly = _toDateAdvance != null ? DateTime(_toDateAdvance!.year, _toDateAdvance!.month, _toDateAdvance!.day) : null;
          
          if (fromDateOnly != null && recordDateOnly.isBefore(fromDateOnly)) return false;
          if (toDateOnly != null && recordDateOnly.isAfter(toDateOnly)) return false;
          return true;
        }).toList();
      }
      
      // Apply search filter
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        filtered = filtered.where((detail) {
          final employeeName = (detail['employee_name']?.toString() ?? '').toLowerCase();
          return employeeName.contains(searchQuery);
        }).toList();
      }
      
      _filteredAdvanceDetails = filtered;
    });
  }

  Future<void> _selectFromDateAdvance() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDateAdvance ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDateAdvance = picked;
      });
      _filterAdvanceData(_advanceSearchController.text);
    }
  }

  Future<void> _selectToDateAdvance() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDateAdvance ?? (_fromDateAdvance ?? DateTime.now()),
      firstDate: _fromDateAdvance ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDateAdvance = picked;
      });
      _filterAdvanceData(_advanceSearchController.text);
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
      _loadRentVehicleAttendance();
      // Apply filters after loading
      _filterAdvanceData(_advanceSearchController.text);
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
          tabs: [
            const Tab(text: 'Staff Attendance Entry'),
            const Tab(text: 'Rent Vehicle Attendance Entry'),
            const Tab(text: 'Advance Details'),
            const Tab(text: 'Present Days Count'),
            if (_showMiningActivityTab)
              const Tab(text: 'Daily Mining Activity'),
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
          // Staff Attendance Entry Tab
          Column(
            children: [
              // Date Selection and Edit Button in same row
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
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
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isEditMode ? _saveEmployeeAttendanceAction : () => setState(() => _isEditMode = true),
                      icon: Icon(_isEditMode ? Icons.save : Icons.edit),
                      label: Text(_isEditMode ? 'Save Attendance' : 'Edit Attendance'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  selectedDate: _selectedDate,
                  isAdmin: widget.isAdmin,
                  isEditMode: _isEditMode,
                  onEditModeChanged: (bool value) {
                    setState(() {
                      _isEditMode = value;
                    });
                  },
                  onSaveMethodReady: (Future<bool> Function() saveMethod) {
                    _saveEmployeeAttendance = saveMethod;
                  },
                ),
              ),
            ],
          ),
          // Vehicle Attendance Entry Tab
          Column(
            children: [
              // Date Selection and Edit Button in same row
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
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
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isEditMode ? _saveVehicleAttendance : () => setState(() => _isEditMode = true),
                      icon: Icon(_isEditMode ? Icons.save : Icons.edit),
                      label: Text(_isEditMode ? 'Save Attendance' : 'Edit Attendance'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Rent Vehicle Details Table
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Text(
                      'Rent Vehicle Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingRentVehicles
                    ? const Center(child: CircularProgressIndicator())
                    : _rentVehicles.isEmpty
                        ? const Center(
                            child: Text(
                              'No rent vehicles found for selected sector',
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
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.teal.shade100,
                                    ),
                                    columns: const [
                                      DataColumn(
                                        label: Text('Vehicle Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataColumn(
                                        label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    rows: _rentVehicles.map((vehicle) {
                                      final vehicleId = vehicle['id'] as int;
                                      final currentStatus = _rentVehicleStatusControllers[vehicleId];
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(vehicle['vehicle_name']?.toString() ?? 'N/A')),
                                          DataCell(
                                            _isEditMode
                                                ? DropdownButton<String>(
                                                    value: currentStatus,
                                                    hint: const Text('Select Status'),
                                                    isExpanded: true,
                                                    items: const [
                                                      DropdownMenuItem<String>(
                                                        value: 'present',
                                                        child: Text('Present'),
                                                      ),
                                                      DropdownMenuItem<String>(
                                                        value: 'absent',
                                                        child: Text('Absent'),
                                                      ),
                                                      DropdownMenuItem<String>(
                                                        value: 'halfday',
                                                        child: Text('Halfday'),
                                                      ),
                                                    ],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _rentVehicleStatusControllers[vehicleId] = value;
                                                      });
                                                    },
                                                  )
                                                : Text(
                                                    currentStatus == null
                                                        ? '-'
                                                        : currentStatus == 'present'
                                                            ? 'Present'
                                                            : currentStatus == 'absent'
                                                                ? 'Absent'
                                                                : 'Halfday',
                                                    style: TextStyle(
                                                      color: currentStatus == null
                                                          ? Colors.grey
                                                          : currentStatus == 'present'
                                                              ? Colors.green.shade700
                                                              : currentStatus == 'absent'
                                                                  ? Colors.red.shade700
                                                                  : Colors.orange.shade700,
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
          // Advance Details Tab
          Column(
            children: [
              // Header, Search Bar, Download Button and Notes
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Search Bar
                          SizedBox(
                            width: 250,
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                return TextField(
                                  controller: _advanceSearchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search by Employee Name',
                                    hintText: 'Enter employee name to search',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _advanceSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _advanceSearchController.clear();
                                              _filterAdvanceData('');
                                              setState(() {}); // Update UI to hide clear button
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    _filterAdvanceData(value);
                                    setState(() {}); // Update UI to show/hide clear button
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Advance Details Table
              Expanded(
                child: _isLoadingAdvance
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredAdvanceDetails.isEmpty
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
                                      if (_filteredAdvanceDetails.any((detail) => ((detail['bulk_advance'] as num?)?.toDouble() ?? 0.0) > 0.01))
                                        const DataColumn(
                                          label: Text('Bulk Advance', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                    rows: () {
                                      // Calculate totals
                                      double totalOutstandingAdvance = 0.0;
                                      double totalBulkAdvance = 0.0;
                                      final showBulkColumn = _filteredAdvanceDetails.any((d) => ((d['bulk_advance'] as num?)?.toDouble() ?? 0.0) > 0.01);
                                      
                                      // Generate data rows and calculate totals
                                      final dataRows = _filteredAdvanceDetails.map((detail) {
                                        final outstandingAdvance = (detail['outstanding_advance'] as num?)?.toDouble() ?? 0.0;
                                        final bulkAdvance = (detail['bulk_advance'] as num?)?.toDouble() ?? 0.0;
                                        
                                        // Add to totals
                                        totalOutstandingAdvance += outstandingAdvance;
                                        totalBulkAdvance += bulkAdvance;
                                        
                                        return DataRow(
                                          cells: [
                                            if (widget.selectedSector == null && widget.isAdmin)
                                              DataCell(Text(_getSectorName(detail['sector_code']?.toString()))),
                                            DataCell(Text(detail['employee_name']?.toString() ?? 'N/A')),
                                            DataCell(
                                              Text(
                                                '₹${outstandingAdvance.toStringAsFixed(2)}',
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
                                      }).toList();
                                      
                                      // Create total row
                                      final totalRow = DataRow(
                                        color: WidgetStateProperty.all(Colors.blue.shade50),
                                        cells: [
                                          if (widget.selectedSector == null && widget.isAdmin)
                                            const DataCell(Text('')),
                                          const DataCell(
                                            Text(
                                              'TOTAL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '₹${totalOutstandingAdvance.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                          // Only show Bulk Advance total if column is shown
                                          if (showBulkColumn)
                                            DataCell(
                                              Text(
                                                '₹${totalBulkAdvance.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                      
                                      // Combine data rows and total row
                                      return [...dataRows, totalRow];
                                    }(),
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
          // Daily Mining Activity Tab (only if All sector or SSBM)
          if (_showMiningActivityTab)
            DailyMiningActivityTabContent(
              selectedSector: widget.selectedSector,
              isAdmin: widget.isAdmin,
            ),
        ],
      ),
    );
  }
}

