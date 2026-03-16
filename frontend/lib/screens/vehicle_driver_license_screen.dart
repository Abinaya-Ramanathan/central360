import 'package:flutter/material.dart';
import '../widgets/fixed_header_table.dart';
import '../models/vehicle_license.dart';
import '../models/driver_license.dart';
import '../models/engine_oil_service.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
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

  final ScrollController _vehicleHorizontalScrollController = ScrollController();
  final ScrollController _driverHorizontalScrollController = ScrollController();
  final ScrollController _serviceHorizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
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
    _vehicleHorizontalScrollController.dispose();
    _driverHorizontalScrollController.dispose();
    _serviceHorizontalScrollController.dispose();
    super.dispose();
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
                      initialSectorCodes: AuthService.initialSectorCodes,
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
            : Column(
                children: [
                  // Action button: top-right in body, just below AppBar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_tabController.index == 0)
                          FilledButton.icon(
                            onPressed: _addVehicleLicense,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Vehicle', style: TextStyle(fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepOrange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        if (_tabController.index == 1)
                          FilledButton.icon(
                            onPressed: _addDriverLicense,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Driver', style: TextStyle(fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepOrange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        if (_tabController.index == 2)
                          FilledButton.icon(
                            onPressed: _addEngineOilService,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Service', style: TextStyle(fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepOrange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVehicleLicenseTab(),
                        _buildDriverLicenseTab(),
                        _buildEngineOilServiceTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _vehicleSortHeader(String label, String columnKey, double width) {
    return InkWell(
      onTap: () => setState(() {
        if (_vehicleSortColumn == columnKey) {
          _vehicleSortAscending = !_vehicleSortAscending;
        } else {
          _vehicleSortColumn = columnKey;
          _vehicleSortAscending = true;
        }
      }),
      child: SizedBox(
        width: width,
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Icon(_vehicleSortColumn == columnKey ? (_vehicleSortAscending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.sort, size: 16),
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const double sp = 16;
                    const double wSector = 100, wName = 120, wModel = 100, wRegNo = 140, wDate = 100, wAction = 120;
                    final showSector = widget.selectedSector == null && _isAdmin;
                    final totalWidth = (showSector ? wSector + sp : 0) + wName + wModel + wRegNo + wDate * 6 + wAction + (showSector ? 10 : 9) * sp;
                    return FixedHeaderTable(
                      horizontalScrollController: _vehicleHorizontalScrollController,
                      totalWidth: totalWidth,
                      headerHeight: 48,
                      headerBuilder: (ctx) {
                        final headers = <Widget>[
                          if (showSector)
                            InkWell(
                              onTap: () => setState(() {
                                _sectorSortAscendingVehicle = !_sectorSortAscendingVehicle;
                                sortedLicenses.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return _sectorSortAscendingVehicle ? aName.compareTo(bName) : bName.compareTo(aName);
                                });
                              }),
                              child: SizedBox(width: wSector, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)))),
                            ),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wName, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wModel, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Model', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wRegNo, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Registration Number', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          _vehicleSortHeader('Permit Date', 'permit', wDate),
                          const SizedBox(width: sp),
                          _vehicleSortHeader('Insurance Date', 'insurance', wDate),
                          const SizedBox(width: sp),
                          _vehicleSortHeader('Fitness Date', 'fitness', wDate),
                          const SizedBox(width: sp),
                          _vehicleSortHeader('Pollution Date', 'pollution', wDate),
                          const SizedBox(width: sp),
                          _vehicleSortHeader('Tax Date', 'tax', wDate),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
                        ];
                        return Row(children: headers);
                      },
                      rowCount: sortedLicenses.length,
                      rowBuilder: (ctx, index) {
                        final license = sortedLicenses[index];
                        final cells = <Widget>[
                          if (showSector) SizedBox(width: wSector, child: Text(_getSectorName(license.sectorCode))),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wName, child: Text(license.name)),
                          const SizedBox(width: sp),
                          SizedBox(width: wModel, child: Text(license.model)),
                          const SizedBox(width: sp),
                          SizedBox(width: wRegNo, child: Text(license.registrationNumber)),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(license.permitDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(license.insuranceDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(license.fitnessDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(license.pollutionDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(license.taxDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, child: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewVehicleLicense(license)),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Edit', onPressed: () => _editVehicleLicense(license)),
                            if (_isAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Delete', onPressed: () => _deleteVehicleLicense(license)),
                          ])),
                        ];
                        return Row(children: cells);
                      },
                    );
                  },
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const double sp = 16;
                    const double wSector = 100, wDriverName = 140, wLicenseNo = 140, wExpiry = 110, wAction = 120;
                    final showSector = widget.selectedSector == null && _isAdmin;
                    final totalWidth = (showSector ? wSector + sp : 0) + wDriverName + wLicenseNo + wExpiry + wAction + (showSector ? 4 : 3) * sp;
                    return FixedHeaderTable(
                      horizontalScrollController: _driverHorizontalScrollController,
                      totalWidth: totalWidth,
                      headerHeight: 48,
                      headerBuilder: (ctx) {
                        final headers = <Widget>[
                          if (showSector)
                            InkWell(
                              onTap: () => setState(() {
                                _sectorSortAscendingDriver = !_sectorSortAscendingDriver;
                                sortedLicenses.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return _sectorSortAscendingDriver ? aName.compareTo(bName) : bName.compareTo(aName);
                                });
                              }),
                              child: SizedBox(width: wSector, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)))),
                            ),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wDriverName, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Driver Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wLicenseNo, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('License Number', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          InkWell(
                            onTap: () => setState(() => _driverSortAscending = !_driverSortAscending),
                            child: SizedBox(width: wExpiry, height: 48, child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold)), Icon(_driverSortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16)])),
                          ),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
                        ];
                        return Row(children: headers);
                      },
                      rowCount: sortedLicenses.length,
                      rowBuilder: (ctx, index) {
                        final license = sortedLicenses[index];
                        final cells = <Widget>[
                          if (showSector) SizedBox(width: wSector, child: Text(_getSectorName(license.sectorCode))),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wDriverName, child: Text(license.driverName)),
                          const SizedBox(width: sp),
                          SizedBox(width: wLicenseNo, child: Text(license.licenseNumber)),
                          const SizedBox(width: sp),
                          SizedBox(width: wExpiry, child: Text(FormatUtils.formatDateDisplay(license.expiryDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, child: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewDriverLicense(license)),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Edit', onPressed: () => _editDriverLicense(license)),
                            if (widget.isMainAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Delete', onPressed: () => _deleteDriverLicense(license)),
                          ])),
                        ];
                        return Row(children: cells);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _serviceSortHeader(String label, String columnKey, double width) {
    return InkWell(
      onTap: () => setState(() {
        if (_serviceSortColumn == columnKey) {
          _serviceSortAscending = !_serviceSortAscending;
        } else {
          _serviceSortColumn = columnKey;
          _serviceSortAscending = true;
        }
      }),
      child: SizedBox(
        width: width,
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Icon(_serviceSortColumn == columnKey ? (_serviceSortAscending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.sort, size: 16),
          ],
        ),
      ),
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const double sp = 16;
                    const double wSector = 100, wVehicle = 120, wModel = 90, wPart = 140, wDate = 110, wKms = 100, wHrs = 90, wAction = 120;
                    final showSector = widget.selectedSector == null && _isAdmin;
                    final totalWidth = (showSector ? wSector + sp : 0) + wVehicle + wModel + wPart + wDate + wKms + wHrs + wDate + wAction + (showSector ? 8 : 7) * sp;
                    return FixedHeaderTable(
                      horizontalScrollController: _serviceHorizontalScrollController,
                      totalWidth: totalWidth,
                      headerHeight: 48,
                      headerBuilder: (ctx) {
                        final headers = <Widget>[
                          if (showSector)
                            InkWell(
                              onTap: () => setState(() {
                                _sectorSortAscendingService = !_sectorSortAscendingService;
                                sortedServices.sort((a, b) {
                                  final aName = _getSectorName(a.sectorCode).toLowerCase();
                                  final bName = _getSectorName(b.sectorCode).toLowerCase();
                                  return _sectorSortAscendingService ? aName.compareTo(bName) : bName.compareTo(aName);
                                });
                              }),
                              child: SizedBox(width: wSector, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)))),
                            ),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wVehicle, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Vehicle Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wModel, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Model', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wPart, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Service Part Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          _serviceSortHeader('Service Date', 'service', wDate),
                          const SizedBox(width: sp),
                          SizedBox(width: wKms, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Service in Kms', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          SizedBox(width: wHrs, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Service in Hrs', style: TextStyle(fontWeight: FontWeight.bold)))),
                          const SizedBox(width: sp),
                          _serviceSortHeader('Next Service Date', 'next', wDate),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, height: 48, child: const Align(alignment: Alignment.centerLeft, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
                        ];
                        return Row(children: headers);
                      },
                      rowCount: sortedServices.length,
                      rowBuilder: (ctx, index) {
                        final service = sortedServices[index];
                        final cells = <Widget>[
                          if (showSector) SizedBox(width: wSector, child: Text(_getSectorName(service.sectorCode))),
                          if (showSector) const SizedBox(width: sp),
                          SizedBox(width: wVehicle, child: Text(service.vehicleName)),
                          const SizedBox(width: sp),
                          SizedBox(width: wModel, child: Text(service.model)),
                          const SizedBox(width: sp),
                          SizedBox(width: wPart, child: Text(service.servicePartName)),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(service.serviceDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wKms, child: Text(service.serviceInKms?.toString() ?? 'N/A')),
                          const SizedBox(width: sp),
                          SizedBox(width: wHrs, child: Text(service.serviceInHrs?.toString() ?? 'N/A')),
                          const SizedBox(width: sp),
                          SizedBox(width: wDate, child: Text(FormatUtils.formatDateDisplay(service.nextServiceDate))),
                          const SizedBox(width: sp),
                          SizedBox(width: wAction, child: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewEngineOilService(service)),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Edit', onPressed: () => _editEngineOilService(service)),
                            if (widget.isMainAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Delete', onPressed: () => _deleteEngineOilService(service)),
                          ])),
                        ];
                        return Row(children: cells);
                      },
                    );
                  },
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
              _buildViewField('Permit Date', FormatUtils.formatDateDisplay(license.permitDate)),
              _buildViewField('Insurance Date', FormatUtils.formatDateDisplay(license.insuranceDate)),
              _buildViewField('Fitness Date', FormatUtils.formatDateDisplay(license.fitnessDate)),
              _buildViewField('Pollution Date', FormatUtils.formatDateDisplay(license.pollutionDate)),
              _buildViewField('Tax Date', FormatUtils.formatDateDisplay(license.taxDate)),
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
              _buildViewField('Expiry Date', FormatUtils.formatDateDisplay(license.expiryDate)),
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
              _buildViewField('Service Date', FormatUtils.formatDateDisplay(service.serviceDate)),
              _buildViewField('Service in Kms', service.serviceInKms?.toString() ?? 'N/A'),
              _buildViewField('Service in Hrs', service.serviceInHrs?.toString() ?? 'N/A'),
              _buildViewField('Next Service Date', FormatUtils.formatDateDisplay(service.nextServiceDate)),
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

