import 'package:flutter/material.dart';
import 'employee_details_screen.dart';
import 'daily_report_details_screen.dart';
import 'maintenance_issue_screen.dart';
import 'mahal_booking_screen.dart';
import 'credit_details_screen.dart';
import 'vehicle_driver_license_screen.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import 'add_sector_dialog.dart';
import 'add_product_dialog.dart';
import 'manage_products_dialog.dart';
import 'manage_sectors_dialog.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String? initialSector;

  const HomeScreen({
    super.key,
    required this.username,
    this.initialSector,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SectorService _sectorService = SectorService();
  List<Sector> _sectors = [];
  String? _selectedSector;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya';
    if (widget.initialSector != null) {
      _selectedSector = widget.initialSector;
    }
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await ApiService.getSectors();
      setState(() {
        _sectors = sectors;
        _sectorService.sectors = sectors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sectors: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central360'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Sector Selection in AppBar
          if (_selectedSector != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _sectors.firstWhere((s) => s.code == _selectedSector, orElse: () => Sector(code: _selectedSector!, name: _selectedSector!)).name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
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
              // Already on home page, do nothing or refresh
            },
          ),
          // Logout icon
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Show confirmation dialog
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
            // Sector Selection
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Sector:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSector,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.filter_list),
                          ),
                          isExpanded: true,
                          hint: const Text('Select Sector'),
                          items: [
                            // For admin users, show "All Sectors" and all sectors
                            if (_isAdmin) ...[
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Sectors'),
                              ),
                              ..._sectors.map((sector) {
                                return DropdownMenuItem<String>(
                                  value: sector.code,
                                  child: Text('${sector.code} - ${sector.name}'),
                                );
                              }),
                            ]
                            // For non-admin users with initialSector, only show their sector
                            else if (!_isAdmin && widget.initialSector != null && _sectors.isNotEmpty)
                              DropdownMenuItem<String>(
                                value: widget.initialSector,
                                child: Text(_sectors.firstWhere(
                                  (s) => s.code == widget.initialSector,
                                  orElse: () => Sector(code: widget.initialSector!, name: widget.initialSector!),
                                ).name),
                              ),
                          ],
                          onChanged: _isAdmin ? (value) {
                            setState(() {
                              _selectedSector = value;
                            });
                          } : null,
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<Sector>(
                              context: context,
                              builder: (context) => const AddSectorDialog(),
                            );
                            if (result != null) {
                              await _loadSectors();
                            }
                          },
                          icon: const Icon(Icons.add_business),
                          label: const Text('Add Sector'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ManageSectorsDialog(),
                            ).then((_) => _loadSectors());
                          },
                          icon: const Icon(Icons.business),
                          label: const Text('Manage Sectors'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddProductDialog(),
                            );
                            if (result == true) {
                              // Product created successfully
                            }
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Products'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ManageProductsDialog(),
                            );
                          },
                          icon: const Icon(Icons.inventory_2),
                          label: const Text('Manage Products'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Welcome Card and Buttons
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Show Employee Details only for Admin
                              if (_isAdmin)
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EmployeeDetailsScreen(
                                            username: widget.username,
                                            selectedSector: _selectedSector,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.people),
                                    label: const Text(
                                      'Employee Details',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              // Show Employee Details only for Admin
                              if (_isAdmin) const SizedBox(height: 16),
                              // Daily Report Details - available for all users
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DailyReportDetailsScreen(
                                          username: widget.username,
                                          selectedSector: _selectedSector,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.report),
                                  label: const Text(
                                    'Daily Report Details',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Maintenance Issue Report - available for all users
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MaintenanceIssueScreen(
                                          username: widget.username,
                                          selectedSector: _selectedSector,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.build),
                                  label: const Text(
                                    'Maintenance Issue Report',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Credit Details - available for all users
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CreditDetailsScreen(
                                          username: widget.username,
                                          selectedSector: _selectedSector,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.credit_card),
                                  label: const Text(
                                    'Credit Details',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Mahal Booking Details - for SSMMC sector or All Sectors (admin only)
                              if ((_selectedSector == 'SSMMC' || (_selectedSector == null && _isAdmin))) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MahalBookingScreen(
                                            username: widget.username,
                                            selectedSector: _selectedSector,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.event_seat),
                                    label: const Text(
                                      'Mahal Booking and Catering Orders Details',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              // Vehicle Driver License and Oil Service Details - for All Sectors (admin) or SSBM sector
                              if ((_selectedSector == null && _isAdmin) || _selectedSector == 'SSBM') ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VehicleDriverLicenseScreen(
                                            username: widget.username,
                                            selectedSector: _selectedSector,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.drive_eta),
                                    label: const Text(
                                      'Vehicle and Driver Details',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
