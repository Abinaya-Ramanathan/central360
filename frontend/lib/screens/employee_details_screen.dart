import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'add_employee_dialog.dart';
import 'edit_employee_dialog.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const EmployeeDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  List<Employee> _employees = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSectors();
    _loadEmployees();
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

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employees: $e'),
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
    final filteredEmployees = widget.selectedSector == null
        ? _employees
        : _employees.where((e) => e.sector == widget.selectedSector).toList();

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _getSectorName(widget.selectedSector),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'All Sectors',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
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
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                    initialSector: widget.selectedSector,
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
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.blue.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.selectedSector == null
                                    ? 'No employees added yet'
                                    : 'No employees in selected sector',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                Colors.blue.shade100,
                              ),
                              columns: [
                                if (widget.selectedSector == null)
                                  const DataColumn(label: Text('Sector')),
                                const DataColumn(label: Text('Name')),
                                const DataColumn(label: Text('Contact')),
                                const DataColumn(label: Text('Address')),
                                const DataColumn(label: Text('Bank Details')),
                                const DataColumn(label: Text('Role')),
                                const DataColumn(label: Text('Daily Salary')),
                                const DataColumn(label: Text('Weekly Salary')),
                                const DataColumn(label: Text('Monthly Salary')),
                                const DataColumn(label: Text('Joining Date')),
                                const DataColumn(label: Text('Action')),
                              ],
                              rows: [
                                ...filteredEmployees.map((employee) {
                                  return DataRow(
                                    cells: [
                                      if (widget.selectedSector == null)
                                        DataCell(Text(_getSectorName(employee.sector))),
                                      DataCell(Text(employee.name)),
                                      DataCell(Text(employee.contact)),
                                      DataCell(
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            employee.address,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 150,
                                          child: Text(
                                            employee.bankDetails,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(employee.role)),
                                      DataCell(Text(
                                        employee.dailySalary > 0
                                            ? '₹${employee.dailySalary.toStringAsFixed(2)}/day'
                                            : '-',
                                      )),
                                      DataCell(Text(
                                        employee.weeklySalary > 0
                                            ? '₹${employee.weeklySalary.toStringAsFixed(2)}/week'
                                            : '-',
                                      )),
                                      DataCell(Text(
                                        employee.monthlySalary > 0
                                            ? '₹${employee.monthlySalary.toStringAsFixed(2)}/mo'
                                            : '-',
                                      )),
                                      DataCell(Text(
                                        employee.joiningDate != null
                                            ? '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}-${employee.joiningDate!.day.toString().padLeft(2, '0')}'
                                            : employee.joiningYear != null
                                                ? employee.joiningYear.toString()
                                                : 'N/A',
                                      )),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility, color: Colors.green),
                                              tooltip: 'View',
                                              onPressed: () => _viewEmployee(employee),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              tooltip: 'Edit',
                                              onPressed: () async {
                                                final result = await showDialog<Employee>(
                                                  context: context,
                                                  builder: (context) => EditEmployeeDialog(
                                                    employee: employee,
                                                  ),
                                                );
                                                if (result != null) {
                                                  try {
                                                    final updated = await ApiService.updateEmployee(result);
                                                    setState(() {
                                                      final index = _employees.indexWhere(
                                                        (e) => e.id == employee.id,
                                                      );
                                                      if (index != -1) {
                                                        _employees[index] = updated;
                                                      }
                                                    });
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Error updating employee: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                            if (widget.isMainAdmin)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                tooltip: 'Delete',
                                                onPressed: () => _deleteEmployee(employee),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                // Summary Row
                                DataRow(
                                  color: WidgetStateProperty.all(Colors.blue.shade50),
                                  cells: [
                                    if (widget.selectedSector == null)
                                      const DataCell(
                                        Text(
                                          'Total',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    DataCell(
                                      Text(
                                        'Count: ${_getTotalEmployeeCount(filteredEmployees)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const DataCell(SizedBox.shrink()),
                                    const DataCell(SizedBox.shrink()),
                                    const DataCell(SizedBox.shrink()),
                                    const DataCell(SizedBox.shrink()),
                                    DataCell(
                                      Text(
                                        '₹${_getTotalDailySalary(filteredEmployees).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${_getTotalWeeklySalary(filteredEmployees).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${_getTotalMonthlySalary(filteredEmployees).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const DataCell(SizedBox.shrink()),
                                    const DataCell(SizedBox.shrink()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await showDialog<Employee>(
                context: context,
                builder: (context) => const AddEmployeeDialog(),
              );
              if (result != null) {
                try {
                  final created = await ApiService.createEmployee(result);
                  setState(() {
                    _employees.add(created);
                  });
                } catch (e) {
                  // Extract error message without "Exception: " prefix
                  String errorMessage = e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Add Employee'),
          ),
    );
  }
}

