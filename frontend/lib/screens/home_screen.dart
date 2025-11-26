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
import '../services/auth_service.dart';
import 'add_sector_dialog.dart';
import 'add_product_dialog.dart';
import 'manage_products_dialog.dart';
import 'manage_sectors_dialog.dart';
import 'add_stock_item_dialog.dart';
import 'manage_stock_items_dialog.dart';
import 'stock_management_screen.dart';
import 'login_screen.dart';
import 'update_dialog.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String? initialSector;
  final bool isAdmin;
  final bool isMainAdmin;

  const HomeScreen({
    super.key,
    required this.username,
    this.initialSector,
    this.isAdmin = false,
    this.isMainAdmin = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SectorService _sectorService = SectorService();
  List<Sector> _sectors = [];
  String? _selectedSector;
  bool _isAdmin = false;
  bool _isMainAdmin = false;

  @override
  void initState() {
    super.initState();
    // Admin privileges are determined by backend based on password
    // Use AuthService if available, otherwise fall back to widget parameters
    _isAdmin = AuthService.isAdmin || widget.isAdmin;
    _isMainAdmin = AuthService.isMainAdmin || widget.isMainAdmin;
    if (widget.initialSector != null) {
      _selectedSector = widget.initialSector;
    }
    _loadSectors();
    // Check for updates after a short delay (to let UI load first)
    Future.delayed(const Duration(seconds: 2), () {
      _checkForUpdates();
    });
  }
  
  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await UpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        // Show update dialog
        final shouldUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: !updateInfo.isRequired,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
        
        // If user clicked "Later", mark this version as dismissed
        if (shouldUpdate == false && !updateInfo.isRequired) {
          await UpdateService.dismissVersion(
            updateInfo.latestVersion,
            updateInfo.latestBuildNumber,
          );
        }
        
        // If update is required and user dismissed, show again after delay
        if (updateInfo.isRequired && shouldUpdate == false) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _checkForUpdates();
          });
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('Error checking for updates: $e');
    }
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
        title: const Text('Company360'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // User icon with username - Hide text on small screens
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                // On very small screens, show only icon
                return IconButton(
                  icon: const Icon(Icons.person),
                  tooltip: widget.username,
                  onPressed: null,
                );
              } else {
                // On larger screens, show icon and username
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        widget.username,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
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
            // Sector Selection - Responsive layout for mobile
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue),
                      SizedBox(width: 12),
                      Text(
                        'Select Sector:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Sector Dropdown - Full width on mobile
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSector,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.filter_list),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  // Admin buttons - Use Wrap for responsive layout
                  if (_isAdmin) ...[
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // On mobile (width < 600), use vertical layout
                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              _buildAdminButton(
                                icon: Icons.add_business,
                                label: 'Add Sector',
                                color: Colors.green.shade700,
                                onPressed: () async {
                                  final result = await showDialog<Sector>(
                                    context: context,
                                    builder: (context) => const AddSectorDialog(),
                                  );
                                  if (result != null) {
                                    await _loadSectors();
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAdminButton(
                                icon: Icons.business,
                                label: 'Manage Sectors',
                                color: Colors.indigo.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageSectorsDialog(isMainAdmin: _isMainAdmin),
                                  ).then((_) => _loadSectors());
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAdminButton(
                                icon: Icons.add_shopping_cart,
                                label: 'Add Production Item',
                                color: Colors.orange.shade700,
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => const AddProductDialog(),
                                  );
                                  if (result == true) {
                                    // Product created successfully
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAdminButton(
                                icon: Icons.inventory_2,
                                label: 'Manage Production Item',
                                color: Colors.purple.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageProductsDialog(isMainAdmin: _isMainAdmin),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAdminButton(
                                icon: Icons.add_box,
                                label: 'Add Stock Item',
                                color: Colors.brown.shade700,
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => const AddStockItemDialog(),
                                  );
                                  if (result == true) {
                                    // Stock item created successfully
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAdminButton(
                                icon: Icons.inventory,
                                label: 'Manage Stock Item',
                                color: Colors.grey.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageStockItemsDialog(isMainAdmin: _isMainAdmin),
                                  );
                                },
                              ),
                            ],
                          );
                        } else {
                          // On larger screens, use Wrap for horizontal layout
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildAdminButton(
                                icon: Icons.add_business,
                                label: 'Add Sector',
                                color: Colors.green.shade700,
                                onPressed: () async {
                                  final result = await showDialog<Sector>(
                                    context: context,
                                    builder: (context) => const AddSectorDialog(),
                                  );
                                  if (result != null) {
                                    await _loadSectors();
                                  }
                                },
                              ),
                              _buildAdminButton(
                                icon: Icons.business,
                                label: 'Manage Sectors',
                                color: Colors.indigo.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageSectorsDialog(isMainAdmin: _isMainAdmin),
                                  ).then((_) => _loadSectors());
                                },
                              ),
                              _buildAdminButton(
                                icon: Icons.add_shopping_cart,
                                label: 'Add Production Item',
                                color: Colors.orange.shade700,
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => const AddProductDialog(),
                                  );
                                  if (result == true) {
                                    // Product created successfully
                                  }
                                },
                              ),
                              _buildAdminButton(
                                icon: Icons.inventory_2,
                                label: 'Manage Production Item',
                                color: Colors.purple.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageProductsDialog(isMainAdmin: _isMainAdmin),
                                  );
                                },
                              ),
                              _buildAdminButton(
                                icon: Icons.add_box,
                                label: 'Add Stock Item',
                                color: Colors.brown.shade700,
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => const AddStockItemDialog(),
                                  );
                                  if (result == true) {
                                    // Stock item created successfully
                                  }
                                },
                              ),
                              _buildAdminButton(
                                icon: Icons.inventory,
                                label: 'Manage Stock Item',
                                color: Colors.grey.shade700,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ManageStockItemsDialog(isMainAdmin: _isMainAdmin),
                                  );
                                },
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
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
                                          isMainAdmin: _isMainAdmin || _isAdmin, // Ensure abinaya has full access
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
                                          isMainAdmin: _isMainAdmin,
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
                                          isMainAdmin: _isMainAdmin,
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
                              // Stock Management - available for all users
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StockManagementScreen(
                                          username: widget.username,
                                          selectedSector: _selectedSector,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.warehouse),
                                  label: const Text(
                                    'Stock Management',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
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
                                            isMainAdmin: _isMainAdmin,
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
                                          isMainAdmin: _isMainAdmin,
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

  Widget _buildAdminButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
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
    );
  }
}
