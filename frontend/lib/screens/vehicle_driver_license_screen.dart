import 'package:flutter/material.dart';
import '../models/vehicle_license.dart';
import '../models/driver_license.dart';
import '../models/engine_oil_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/sector.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'add_vehicle_license_dialog.dart';
import 'add_driver_license_dialog.dart';
import 'add_engine_oil_service_dialog.dart';

class VehicleDriverLicenseScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const VehicleDriverLicenseScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<VehicleDriverLicenseScreen> createState() => _VehicleDriverLicenseScreenState();
}

class _VehicleDriverLicenseScreenState extends State<VehicleDriverLicenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<VehicleLicense> _vehicleLicenses = [];
  List<DriverLicense> _driverLicenses = [];
  List<EngineOilService> _engineOilServices = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _isAdmin = false;
  
  // Sorting state for Vehicle License tab
  String? _vehicleSortColumn;
  bool _vehicleSortAscending = true;
  
  // Sorting state for Driver License tab
  bool _driverSortAscending = true;
  
  // Sorting state for Vehicle Services tab
  String? _serviceSortColumn;
  bool _serviceSortAscending = true;
  
  // Sorting state for Sector column
  bool _sectorSortAscendingVehicle = true;
  bool _sectorSortAscendingDriver = true;
  bool _sectorSortAscendingService = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Use AuthService to get admin status (based on password, not username)
    _isAdmin = AuthService.isAdmin;
    _initializeNotifications();
    _loadSectors();
    _loadAllData();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService().initialize();
      // Request notification permission if not already granted
      await NotificationService().requestNotificationPermission();
    } catch (e) {
      // Silently handle errors (notifications might not work on all platforms)
      debugPrint('Notification initialization error: $e');
    }
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

  Future<void> _checkExpiriesAndNotify() async {
    try {
      // Check vehicle license expiries (Permit, Insurance, Fitness, Pollution, Tax dates)
      await NotificationService().checkVehicleExpiries(_vehicleLicenses);
      // Check driver license expiries (Expiry Date)
      await NotificationService().checkDriverExpiries(_driverLicenses);
      // Check engine oil service expiries (Next Service Date)
      await NotificationService().checkEngineOilServiceExpiries(_engineOilServices);
    } catch (e) {
      // Silently handle errors - notifications are non-critical
      debugPrint('Error checking expiries: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final vehicleLicenses = await ApiService.getVehicleLicenses(sector: widget.selectedSector);
      final driverLicenses = await ApiService.getDriverLicenses(sector: widget.selectedSector);
      final engineOilServices = await ApiService.getEngineOilServices(sector: widget.selectedSector);

      if (mounted) {
        setState(() {
          _vehicleLicenses = vehicleLicenses;
          _driverLicenses = driverLicenses;
          _engineOilServices = engineOilServices;
        });
        // Check for expiring dates and send notifications
        _checkExpiriesAndNotify();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle and Driver Details'),
          backgroundColor: Colors.deepOrange.shade700,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(text: 'Vehicle License'),
              Tab(text: 'Driver License'),
              Tab(text: 'Vehicle Services'),
            ],
          ),
          actions: [
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
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
        body: _isLoading && _vehicleLicenses.isEmpty && _driverLicenses.isEmpty && _engineOilServices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildVehicleLicenseTab(),
                  _buildDriverLicenseTab(),
                  _buildEngineOilServiceTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildVehicleLicenseTab() {
    List<VehicleLicense> sortedLicenses = List.from(_vehicleLicenses);
    
    if (_vehicleSortColumn != null) {
      sortedLicenses.sort((a, b) {
        DateTime? dateA;
        DateTime? dateB;
        
        switch (_vehicleSortColumn) {
          case 'permit':
            dateA = a.permitDate;
            dateB = b.permitDate;
            break;
          case 'insurance':
            dateA = a.insuranceDate;
            dateB = b.insuranceDate;
            break;
          case 'fitness':
            dateA = a.fitnessDate;
            dateB = b.fitnessDate;
            break;
          case 'pollution':
            dateA = a.pollutionDate;
            dateB = b.pollutionDate;
            break;
          case 'tax':
            dateA = a.taxDate;
            dateB = b.taxDate;
            break;
        }
        
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        final comparison = dateA.compareTo(dateB);
        return _vehicleSortAscending ? comparison : -comparison;
      });
    }
    
    return Column(
      children: [
        Expanded(
          child: _vehicleLicenses.isEmpty
              ? Center(child: Text('No vehicle license details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      sortColumnIndex: (widget.selectedSector == null && _isAdmin) ? 0 : null,
                      sortAscending: _sectorSortAscendingVehicle,
                      columns: [
                        if (widget.selectedSector == null && _isAdmin)
                          DataColumn(
                            label: const Text('Sector'),
                            onSort: (columnIndex, ascending) {
                              setState(() {
                                _sectorSortAscendingVehicle = ascending;
                                sortedLicenses.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return ascending
                                      ? aName.compareTo(bName)
                                      : bName.compareTo(aName);
                                });
                              });
                            },
                          ),
                        const DataColumn(label: Text('Name')),
                        const DataColumn(label: Text('Model')),
                        const DataColumn(label: Text('Registration Number')),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Permit Date'),
                              IconButton(
                                icon: Icon(
                                  _vehicleSortColumn == 'permit'
                                      ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_vehicleSortColumn == 'permit') {
                                      _vehicleSortAscending = !_vehicleSortAscending;
                                    } else {
                                      _vehicleSortColumn = 'permit';
                                      _vehicleSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Insurance Date'),
                              IconButton(
                                icon: Icon(
                                  _vehicleSortColumn == 'insurance'
                                      ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_vehicleSortColumn == 'insurance') {
                                      _vehicleSortAscending = !_vehicleSortAscending;
                                    } else {
                                      _vehicleSortColumn = 'insurance';
                                      _vehicleSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Fitness Date'),
                              IconButton(
                                icon: Icon(
                                  _vehicleSortColumn == 'fitness'
                                      ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_vehicleSortColumn == 'fitness') {
                                      _vehicleSortAscending = !_vehicleSortAscending;
                                    } else {
                                      _vehicleSortColumn = 'fitness';
                                      _vehicleSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Pollution Date'),
                              IconButton(
                                icon: Icon(
                                  _vehicleSortColumn == 'pollution'
                                      ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_vehicleSortColumn == 'pollution') {
                                      _vehicleSortAscending = !_vehicleSortAscending;
                                    } else {
                                      _vehicleSortColumn = 'pollution';
                                      _vehicleSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Tax Date'),
                              IconButton(
                                icon: Icon(
                                  _vehicleSortColumn == 'tax'
                                      ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_vehicleSortColumn == 'tax') {
                                      _vehicleSortAscending = !_vehicleSortAscending;
                                    } else {
                                      _vehicleSortColumn = 'tax';
                                      _vehicleSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Action')),
                      ],
                      rows: sortedLicenses.map((license) {
                        return DataRow(
                          cells: [
                            if (widget.selectedSector == null && _isAdmin)
                              DataCell(Text(_getSectorName(license.sectorCode))),
                            DataCell(Text(license.name)),
                            DataCell(Text(license.model)),
                            DataCell(Text(license.registrationNumber)),
                            DataCell(Text(license.permitDate != null ? license.permitDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(Text(license.insuranceDate != null ? license.insuranceDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(Text(license.fitnessDate != null ? license.fitnessDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(Text(license.pollutionDate != null ? license.pollutionDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(Text(license.taxDate != null ? license.taxDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
                                    tooltip: 'View',
                                    onPressed: () => _viewVehicleLicense(license),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () => _editVehicleLicense(license),
                                  ),
                                  if (_isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteVehicleLicense(license),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addVehicleLicense,
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle License Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverLicenseTab() {
    List<DriverLicense> sortedLicenses = List.from(_driverLicenses);
    sortedLicenses.sort((a, b) {
      final comparison = a.expiryDate.compareTo(b.expiryDate);
      return _driverSortAscending ? comparison : -comparison;
    });
    
    return Column(
      children: [
        Expanded(
          child: _driverLicenses.isEmpty
              ? Center(child: Text('No driver license details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      sortColumnIndex: (widget.selectedSector == null && _isAdmin) ? 0 : null,
                      sortAscending: _sectorSortAscendingDriver,
                      columns: [
                        if (widget.selectedSector == null && _isAdmin)
                          DataColumn(
                            label: const Text('Sector'),
                            onSort: (columnIndex, ascending) {
                              setState(() {
                                _sectorSortAscendingDriver = ascending;
                                sortedLicenses.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return ascending
                                      ? aName.compareTo(bName)
                                      : bName.compareTo(aName);
                                });
                              });
                            },
                          ),
                        const DataColumn(label: Text('Driver Name')),
                        const DataColumn(label: Text('License Number')),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Expiry Date'),
                              IconButton(
                                icon: Icon(
                                  _driverSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _driverSortAscending = !_driverSortAscending;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Action')),
                      ],
                      rows: sortedLicenses.map((license) {
                        return DataRow(
                          cells: [
                            if (widget.selectedSector == null && _isAdmin)
                              DataCell(Text(_getSectorName(license.sectorCode))),
                            DataCell(Text(license.driverName)),
                            DataCell(Text(license.licenseNumber)),
                            DataCell(Text(license.expiryDate.toIso8601String().split('T')[0])),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
                                    tooltip: 'View',
                                    onPressed: () => _viewDriverLicense(license),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () => _editDriverLicense(license),
                                  ),
                                  if (widget.isMainAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteDriverLicense(license),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addDriverLicense,
              icon: const Icon(Icons.add),
              label: const Text('Add Driver License Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngineOilServiceTab() {
    List<EngineOilService> sortedServices = List.from(_engineOilServices);
    
    if (_serviceSortColumn != null) {
      sortedServices.sort((a, b) {
        DateTime? dateA;
        DateTime? dateB;
        
        if (_serviceSortColumn == 'service') {
          dateA = a.serviceDate;
          dateB = b.serviceDate;
        } else if (_serviceSortColumn == 'next') {
          dateA = a.nextServiceDate;
          dateB = b.nextServiceDate;
        }
        
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        final comparison = dateA.compareTo(dateB);
        return _serviceSortAscending ? comparison : -comparison;
      });
    }
    
    return Column(
      children: [
        Expanded(
          child: _engineOilServices.isEmpty
              ? Center(child: Text('No vehicle service details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      sortColumnIndex: (widget.selectedSector == null && _isAdmin) ? 0 : null,
                      sortAscending: _sectorSortAscendingService,
                      columns: [
                        if (widget.selectedSector == null && _isAdmin)
                          DataColumn(
                            label: const Text('Sector'),
                            onSort: (columnIndex, ascending) {
                              setState(() {
                                _sectorSortAscendingService = ascending;
                                sortedServices.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return ascending
                                      ? aName.compareTo(bName)
                                      : bName.compareTo(aName);
                                });
                              });
                            },
                          ),
                        const DataColumn(label: Text('Vehicle Name')),
                        const DataColumn(label: Text('Model')),
                        const DataColumn(label: Text('Service Part Name')),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Service Date'),
                              IconButton(
                                icon: Icon(
                                  _serviceSortColumn == 'service'
                                      ? (_serviceSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_serviceSortColumn == 'service') {
                                      _serviceSortAscending = !_serviceSortAscending;
                                    } else {
                                      _serviceSortColumn = 'service';
                                      _serviceSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Service in Kms')),
                        const DataColumn(label: Text('Service in Hrs')),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Next Service Date'),
                              IconButton(
                                icon: Icon(
                                  _serviceSortColumn == 'next'
                                      ? (_serviceSortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.sort,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_serviceSortColumn == 'next') {
                                      _serviceSortAscending = !_serviceSortAscending;
                                    } else {
                                      _serviceSortColumn = 'next';
                                      _serviceSortAscending = true;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Action')),
                      ],
                      rows: sortedServices.map((service) {
                        return DataRow(
                          cells: [
                            if (widget.selectedSector == null && _isAdmin)
                              DataCell(Text(_getSectorName(service.sectorCode))),
                            DataCell(Text(service.vehicleName)),
                            DataCell(Text(service.model)),
                            DataCell(Text(service.servicePartName)),
                            DataCell(Text(service.serviceDate.toIso8601String().split('T')[0])),
                            DataCell(Text(service.serviceInKms?.toString() ?? 'N/A')),
                            DataCell(Text(service.serviceInHrs?.toString() ?? 'N/A')),
                            DataCell(Text(service.nextServiceDate != null ? service.nextServiceDate!.toIso8601String().split('T')[0] : 'N/A')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
                                    tooltip: 'View',
                                    onPressed: () => _viewEngineOilService(service),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () => _editEngineOilService(service),
                                  ),
                                  if (widget.isMainAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteEngineOilService(service),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addEngineOilService,
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle service details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addVehicleLicense() async {
    final result = await showDialog<VehicleLicense>(
      context: context,
      builder: (context) => AddVehicleLicenseDialog(selectedSector: widget.selectedSector),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _viewVehicleLicense(VehicleLicense license) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vehicle License Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectedSector == null && _isAdmin)
                _buildViewField('Sector', _getSectorName(license.sectorCode)),
              _buildViewField('Name', license.name),
              _buildViewField('Model', license.model),
              _buildViewField('Registration Number', license.registrationNumber),
              _buildViewField('Permit Date', license.permitDate != null ? license.permitDate!.toIso8601String().split('T')[0] : 'N/A'),
              _buildViewField('Insurance Date', license.insuranceDate != null ? license.insuranceDate!.toIso8601String().split('T')[0] : 'N/A'),
              _buildViewField('Fitness Date', license.fitnessDate != null ? license.fitnessDate!.toIso8601String().split('T')[0] : 'N/A'),
              _buildViewField('Pollution Date', license.pollutionDate != null ? license.pollutionDate!.toIso8601String().split('T')[0] : 'N/A'),
              _buildViewField('Tax Date', license.taxDate != null ? license.taxDate!.toIso8601String().split('T')[0] : 'N/A'),
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

  Future<void> _viewDriverLicense(DriverLicense license) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Driver License Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectedSector == null && _isAdmin)
                _buildViewField('Sector', _getSectorName(license.sectorCode)),
              _buildViewField('Driver Name', license.driverName),
              _buildViewField('License Number', license.licenseNumber),
              _buildViewField('Expiry Date', license.expiryDate.toIso8601String().split('T')[0]),
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

  Future<void> _viewEngineOilService(EngineOilService service) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vehicle Service Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectedSector == null && _isAdmin)
                _buildViewField('Sector', _getSectorName(service.sectorCode)),
              _buildViewField('Vehicle Name', service.vehicleName),
              _buildViewField('Model', service.model),
              _buildViewField('Service Part Name', service.servicePartName),
              _buildViewField('Service Date', service.serviceDate.toIso8601String().split('T')[0]),
              _buildViewField('Service in Kms', service.serviceInKms?.toString() ?? 'N/A'),
              _buildViewField('Service in Hrs', service.serviceInHrs?.toString() ?? 'N/A'),
              _buildViewField('Next Service Date', service.nextServiceDate != null ? service.nextServiceDate!.toIso8601String().split('T')[0] : 'N/A'),
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

  Future<void> _editVehicleLicense(VehicleLicense license) async {
    final result = await showDialog<VehicleLicense>(
      context: context,
      builder: (context) => AddVehicleLicenseDialog(selectedSector: widget.selectedSector, vehicleLicense: license),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _deleteVehicleLicense(VehicleLicense license) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle License'),
        content: const Text('Are you sure you want to delete this vehicle license?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteVehicleLicense(license.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        }
        await _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _addDriverLicense() async {
    final result = await showDialog<DriverLicense>(
      context: context,
      builder: (context) => AddDriverLicenseDialog(selectedSector: widget.selectedSector),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _editDriverLicense(DriverLicense license) async {
    final result = await showDialog<DriverLicense>(
      context: context,
      builder: (context) => AddDriverLicenseDialog(selectedSector: widget.selectedSector, driverLicense: license),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _deleteDriverLicense(DriverLicense license) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver License'),
        content: const Text('Are you sure you want to delete this driver license?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteDriverLicense(license.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        }
        await _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _addEngineOilService() async {
    final result = await showDialog<EngineOilService>(
      context: context,
      builder: (context) => AddEngineOilServiceDialog(selectedSector: widget.selectedSector),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _editEngineOilService(EngineOilService service) async {
    final result = await showDialog<EngineOilService>(
      context: context,
      builder: (context) => AddEngineOilServiceDialog(selectedSector: widget.selectedSector, engineOilService: service),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _deleteEngineOilService(EngineOilService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Engine Oil Service'),
        content: const Text('Are you sure you want to delete this engine oil service record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteEngineOilService(service.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        }
        await _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}

