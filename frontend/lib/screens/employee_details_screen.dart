import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../services/auth_service.dart';
import '../widgets/fixed_header_table.dart';
import 'add_employee_dialog.dart';
import 'edit_employee_dialog.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  /// When set (e.g. from main sector page), show employees from these sector codes (main + sub-sectors).
  /// When null, filter by [selectedSector] only (exact match).
  final List<String>? includedSectorCodes;
  final bool isMainAdmin;

  const EmployeeDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.includedSectorCodes,
    this.isMainAdmin = false,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _sortAscending = true; // Sort direction for Sector column
  final TextEditingController _searchController = TextEditingController();
  
  // Horizontal ScrollController for draggable scrollbar
  final ScrollController _horizontalScrollController = ScrollController();

  static const double _headerHeight = 48;
  static const double _colSector = 100;
  static const double _colName = 120;
  static const double _colContact = 100;
  static const double _colAddress = 150;
  static const double _colBank = 150;
  static const double _colRole = 80;
  static const double _colSalary = 100;
  static const double _colDate = 100;
  static const double _colAction = 132;
  static const double _colSpacing = 16;

  @override
  void initState() {
    super.initState();
    _isAdmin = AuthService.isAdmin;
    _loadSectorsAndEmployees();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _filterEmployees() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredEmployees = List.from(_employees);
      } else {
        _filteredEmployees = _employees.where((employee) {
          final sectorName = _getSectorName(employee.sector).toLowerCase();
          final name = employee.name.toLowerCase();
          return sectorName.contains(query) || name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadSectorsAndEmployees() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SectorService().loadSectorsForScreen(),
        ApiService.getEmployees(),
      ]);
      if (!mounted) return;
      setState(() {
        _sectors = results[0] as List<Sector>;
        _employees = results[1] as List<Employee>;
        _filteredEmployees = List.from(_employees);
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  int _getTotalEmployeeCount(List<Employee> employees) {
    return employees.length;
  }

  double _getTotalDailySalary(List<Employee> employees) {
    return employees.fold(0.0, (sum, emp) => sum + emp.dailySalary);
  }

  double _getTotalWeeklySalary(List<Employee> employees) {
    return employees.fold(0.0, (sum, emp) => sum + emp.weeklySalary);
  }

  double _getTotalMonthlySalary(List<Employee> employees) {
    return employees.fold(0.0, (sum, emp) => sum + emp.monthlySalary);
  }

  double _employeeTableWidth(bool showSector) {
    double w = _colName + _colContact + _colAddress + _colBank + _colRole + _colSalary * 3 + _colDate + _colAction;
    if (showSector) w += _colSector;
    // showSector=true adds both a leading Sector column and right-side Name column => 11 total columns.
    final n = showSector ? 11 : 9;
    return w + (n - 1) * _colSpacing;
  }

  Widget _buildEmptyEmployeesState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.blue.shade300),
              const SizedBox(height: 16),
              Text(
                widget.selectedSector == null ? 'No employees added yet' : 'No employees in selected sector',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeTable(List<Employee> filteredEmployees) {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final showSector = widget.selectedSector == null;
    final leadingWidth = showSector ? _colSector : _colName;
    // In single-sector mode, keep one extra spacer width on the right side to avoid
    // edge-case RenderFlex overflow from tight pixel rounding in action rows.
    final rightTotalWidth = _employeeTableWidth(showSector) - leadingWidth - (showSector ? _colSpacing : 0);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: FixedHeaderTable(
          horizontalScrollController: _horizontalScrollController,
          totalWidth: rightTotalWidth,
          headerHeight: _headerHeight,
          rowExtent: _headerHeight,
          leadingWidth: leadingWidth,
          leadingHeaderBuilder: (context) {
            if (!showSector) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text('Name', style: bold),
              );
            }
            return Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    filteredEmployees.sort((a, b) {
                      final aName = _getSectorName(a.sector).toLowerCase();
                      final bName = _getSectorName(b.sector).toLowerCase();
                      return _sortAscending ? aName.compareTo(bName) : bName.compareTo(aName);
                    });
                  });
                },
                child: const Text('Sector', style: bold),
              ),
            );
          },
          leadingRowBuilder: (context, index) {
            final isTotalRow = index == filteredEmployees.length;
            if (isTotalRow) {
              return Material(
                color: Colors.blue.shade50,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showSector
                      ? const Text('Total', style: bold)
                      : Text(
                          'Count: ${_getTotalEmployeeCount(filteredEmployees)}',
                          style: bold,
                        ),
                ),
              );
            }

            final employee = filteredEmployees[index];
            return Align(
              alignment: Alignment.centerLeft,
              child: showSector ? Text(_getSectorName(employee.sector)) : Text(employee.name),
            );
          },
          headerBuilder: (context) {
            final List<Widget> headerChildren = [];
            void addRightCol(double w, Widget c) {
              if (headerChildren.isNotEmpty) headerChildren.add(const SizedBox(width: _colSpacing));
              headerChildren.add(SizedBox(width: w, child: c));
            }
            if (showSector) {
              addRightCol(_colName, const Text('Name', style: bold));
            }
            addRightCol(_colContact, const Text('Contact', style: bold));
            addRightCol(_colAddress, const Text('Address', style: bold));
            addRightCol(_colBank, const Text('Bank Details', style: bold));
            addRightCol(_colRole, const Text('Role', style: bold));
            addRightCol(_colSalary, const Text('Daily Salary', style: bold));
            addRightCol(_colSalary, const Text('Weekly Salary', style: bold));
            addRightCol(_colSalary, const Text('Monthly Salary', style: bold));
            addRightCol(_colDate, const Text('Joining Date', style: bold));
            addRightCol(_colAction, const Text('Action', style: bold));
            return Material(color: Colors.blue.shade100, child: Row(children: headerChildren));
          },
          rowCount: filteredEmployees.length + 1,
          rowBuilder: (context, index) {
            final List<Widget> rowChildren = [];
            void addCell(double w, Widget c) {
              if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: _colSpacing));
              rowChildren.add(SizedBox(width: w, child: c));
            }
            if (index == filteredEmployees.length) {
              if (showSector) {
                addCell(_colName, Text('Count: ${_getTotalEmployeeCount(filteredEmployees)}', style: bold));
              }
              addCell(_colContact, const SizedBox.shrink());
              addCell(_colAddress, const SizedBox.shrink());
              addCell(_colBank, const SizedBox.shrink());
              addCell(_colRole, const SizedBox.shrink());
              addCell(_colSalary, Text('₹${_getTotalDailySalary(filteredEmployees).toStringAsFixed(2)}', style: bold));
              addCell(_colSalary, Text('₹${_getTotalWeeklySalary(filteredEmployees).toStringAsFixed(2)}', style: bold));
              addCell(_colSalary, Text('₹${_getTotalMonthlySalary(filteredEmployees).toStringAsFixed(2)}', style: bold));
              addCell(_colDate, const SizedBox.shrink());
              addCell(_colAction, const SizedBox.shrink());
              return Material(color: Colors.blue.shade50, child: Row(children: rowChildren));
            }
            final employee = filteredEmployees[index];
            if (showSector) addCell(_colName, Text(employee.name, maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colContact, Text(employee.contact, maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colAddress, SizedBox(width: _colAddress, child: Text(employee.address, overflow: TextOverflow.ellipsis)));
            addCell(_colBank, SizedBox(width: _colBank, child: Text(employee.bankDetails, overflow: TextOverflow.ellipsis)));
            addCell(_colRole, Text(employee.role, maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colSalary, Text(employee.dailySalary > 0 ? '₹${employee.dailySalary.toStringAsFixed(2)}/day' : '-', maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colSalary, Text(employee.weeklySalary > 0 ? '₹${employee.weeklySalary.toStringAsFixed(2)}/week' : '-', maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colSalary, Text(employee.monthlySalary > 0 ? '₹${employee.monthlySalary.toStringAsFixed(2)}/mo' : '-', maxLines: 1, overflow: TextOverflow.ellipsis));
            addCell(_colDate, Text(
              employee.joiningDate != null
                  ? '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}-${employee.joiningDate!.day.toString().padLeft(2, '0')}'
                  : employee.joiningYear != null ? employee.joiningYear.toString() : 'N/A',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ));
            IconButton compactIconButton({
              required IconData icon,
              required Color color,
              required String tooltip,
              required VoidCallback? onPressed,
            }) {
              return IconButton(
                icon: Icon(icon, color: color, size: 18),
                tooltip: tooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                splashRadius: 18,
                onPressed: onPressed,
              );
            }

            addCell(_colAction, Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                compactIconButton(
                  icon: Icons.visibility,
                  color: Colors.green,
                  tooltip: 'View',
                  onPressed: () => _viewEmployee(employee),
                ),
                compactIconButton(
                  icon: Icons.edit,
                  color: Colors.blue,
                  tooltip: 'Edit',
                  onPressed: () async {
                    final result = await showDialog<Employee>(context: context, builder: (context) => EditEmployeeDialog(employee: employee));
                    if (result != null) {
                      try {
                        final updated = await ApiService.updateEmployee(result);
                        setState(() {
                          final i = _employees.indexWhere((e) => e.id == employee.id);
                          if (i != -1) _employees[i] = updated;
                          _filterEmployees();
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating employee: $e')));
                      }
                    }
                  },
                ),
                if (widget.isMainAdmin)
                  compactIconButton(
                    icon: Icons.delete,
                    color: Colors.red,
                    tooltip: 'Delete',
                    onPressed: () => _deleteEmployee(employee),
                  ),
              ],
            ));
            return Row(children: rowChildren);
          },
        ),
      ),
    );
  }

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _filteredEmployees = List.from(employees);
        });
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employees: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _viewEmployee(Employee employee) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employee Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectedSector == null)
                _buildViewField('Sector', _getSectorName(employee.sector)),
              _buildViewField('Name', employee.name),
              _buildViewField('Contact', employee.contact),
              if (employee.contact2.isNotEmpty)
                _buildViewField('Contact 2', employee.contact2),
              _buildViewField('Address', employee.address),
              _buildViewField('Bank Details', employee.bankDetails),
              _buildViewField('Role', employee.role),
              _buildViewField('Daily Salary', employee.dailySalary > 0 ? '₹${employee.dailySalary.toStringAsFixed(2)}/day' : 'N/A'),
              _buildViewField('Weekly Salary', employee.weeklySalary > 0 ? '₹${employee.weeklySalary.toStringAsFixed(2)}/week' : 'N/A'),
              _buildViewField('Monthly Salary', employee.monthlySalary > 0 ? '₹${employee.monthlySalary.toStringAsFixed(2)}/mo' : 'N/A'),
              _buildViewField(
                'Joining Date',
                employee.joiningDate != null
                    ? '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}-${employee.joiningDate!.day.toString().padLeft(2, '0')}'
                    : employee.joiningYear != null
                        ? employee.joiningYear.toString()
                        : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(Employee employee) async {
    if (employee.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
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
      await ApiService.deleteEmployee(employee.id);
      setState(() {
        _employees.removeWhere((e) => e.id == employee.id);
        _filterEmployees(); // Refresh filtered list
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting employee: $e'),
            backgroundColor: Colors.red,
          ),
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
    final isNarrow = MediaQuery.of(context).size.width < 900;
    // Filter employees by sector: all if no sector; main+subs if includedSectorCodes set; else exact match
    final sectorFilteredEmployees = widget.selectedSector == null
        ? _filteredEmployees
        : (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)
            ? _filteredEmployees.where((e) {
                final code = e.sector.toUpperCase().trim();
                return widget.includedSectorCodes!.any((s) => s.toUpperCase().trim() == code);
              }).toList()
            : _filteredEmployees.where((e) =>
                e.sector.toUpperCase().trim() == widget.selectedSector!.toUpperCase().trim()
              ).toList();
    
    final filteredEmployees = sectorFilteredEmployees;
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Sector Display
          if (widget.selectedSector != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: _getSectorName(widget.selectedSector),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 18),
                    if (!isNarrow) const SizedBox(width: 4),
                    if (!isNarrow)
                      SizedBox(
                        width: 120,
                        child: Text(
                          _getSectorName(widget.selectedSector),
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  if (!isNarrow) const SizedBox(width: 4),
                  if (!isNarrow)
                    const Text(
                      'All Sectors',
                      style: TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
          // User icon with username
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Tooltip(
              message: widget.username,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 20),
                  if (!isNarrow) const SizedBox(width: 4),
                  if (!isNarrow)
                    SizedBox(
                      width: 110,
                      child: Text(
                        widget.username,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Home icon
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                    initialSectorCodes: AuthService.initialSectorCodes,
                    isAdmin: AuthService.isAdmin,
                    isMainAdmin: AuthService.isMainAdmin,
                  ),
                ),
                (route) => false, // Remove all previous routes
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
            // Search Bar and Add Employee Button
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search by Sector or Name',
                            hintText: 'Enter sector or name to search',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {}); // Update UI to hide clear button
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            _filterEmployees();
                            setState(() {}); // Update UI to show/hide clear button
                          },
                        );
                      },
                    ),
                  ),
                  if (_isAdmin || widget.isMainAdmin) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog<Employee>(
                          context: context,
                          builder: (context) => const AddEmployeeDialog(),
                        );
                        if (result != null) {
                          try {
                            await ApiService.createEmployee(result);
                            // Reload all employees from server to ensure consistency
                            await _loadEmployees();
                            _filterEmployees(); // Refresh filtered list
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Employee added successfully'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            // Extract error message without "Exception: " prefix
                            String errorMessage = e.toString().replaceFirst('Exception: ', '');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Employee'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Employee Table
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Reload all data from backend
                  await _loadEmployees();
                },
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredEmployees.isEmpty
                  ? _buildEmptyEmployeesState()
                  : _buildEmployeeTable(filteredEmployees),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

