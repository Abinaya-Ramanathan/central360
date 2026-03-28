import 'package:flutter/material.dart';
import 'employee_details_screen.dart';
import 'maintenance_issue_screen.dart';
import 'mahal_booking_screen.dart';
import 'sales_credit_details_screen.dart';
import 'vehicle_driver_license_screen.dart';
import 'attendance_advance_screen.dart';
import 'stock_management_screen.dart';
import 'login_screen.dart';
import 'ingredients_details_screen.dart';
import '../models/sector.dart';
import '../services/sector_service.dart';
import '../widgets/sector_notes_app_bar_button.dart';

/// SSC units shown when sector is SSC (Sri Surya Mini Hall / SSMMC removed from this page).
const sscUnits = ['SSCT', 'CS', 'SSCM'];

/// Fallback full names for SSC units (used when API has no name). Code -> full form.
const Map<String, String> sscUnitFullNames = {
  'SSCT': 'SRI SURYAAS CAFE THANTHONDRIMALAI',
  'CS': 'CANTEEN STORE',
  'SSCM': 'SRI SURYAAS CAFE MAIN BRANCH',
};

class SectorDashboardScreen extends StatefulWidget {
  final String username;
  /// null means "All Sectors"
  final String? selectedSector;
  final bool isAdmin;
  final bool isMainAdmin;
  /// Sector codes the user can access (keyword login). If non-null and contains selectedSector, allows sub-sector chip selection.
  final List<String>? userSectorCodes;

  const SectorDashboardScreen({
    super.key,
    required this.username,
    required this.selectedSector,
    required this.isAdmin,
    required this.isMainAdmin,
    this.userSectorCodes,
  });

  @override
  State<SectorDashboardScreen> createState() => _SectorDashboardScreenState();
}

class _SectorDashboardScreenState extends State<SectorDashboardScreen> {
  String? _selectedSscUnit;
  List<Sector> _sectors = [];

  /// Sub-sector codes for current selected sector (from API). For SSC, merge with sscUnits; SSMMC excluded from SSC page.
  List<String> get _subSectorCodes {
    if (widget.selectedSector == null) return [];
    final fromApi = _sectors
        .where((s) => s.parentCode == widget.selectedSector)
        .map((s) => s.code)
        .toList();
    if (widget.selectedSector == 'SSC') {
      final merged = <String>{...sscUnits, ...fromApi}..remove('SSMMC');
      return merged.toList()..sort();
    }
    if (fromApi.isNotEmpty) return fromApi;
    return [];
  }

  bool get _hasSubSectors => _subSectorCodes.isNotEmpty;

  /// Display string for sector: "code - full name" or "All Sectors".
  String _sectorDisplayName(String? code) {
    if (code == null || code.isEmpty) return 'All Sectors';
    final s = _sectors.where((s) => s.code == code);
    if (s.isNotEmpty) return '${s.first.code} - ${s.first.name}';
    final fullName = sscUnitFullNames[code];
    return fullName != null ? '$code - $fullName' : code;
  }

  static Color _sscUnitChipColor(String code) {
    switch (code) {
      case 'SSCT':
        return Colors.blue.shade700;
      case 'CS':
        return Colors.green.shade700;
      case 'SSCM':
        return Colors.teal.shade700;
      default:
        final palette = [
          Colors.indigo,
          Colors.orange,
          Colors.cyan,
          Colors.brown,
        ];
        final idx = code.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
        return palette[idx].shade700;
    }
  }

  /// Title for app bar: current sector as code + full name.
  String get _title {
    if (widget.selectedSector == null) return 'All Sectors';
    if (_hasSubSectors) {
      final code = _selectedSscUnit ?? widget.selectedSector;
      return _sectorDisplayName(code);
    }
    return _sectorDisplayName(widget.selectedSector);
  }

  @override
  void initState() {
    super.initState();
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await SectorService().loadSectorsForScreen();
      if (mounted) setState(() => _sectors = sectors);
    } catch (_) {}
  }

  ButtonStyle _dashboardButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cache computed values once per build for UI speed (avoid repeated getter/list work).
    final subSectorCodes = _subSectorCodes;
    final hasSubSectors = subSectorCodes.isNotEmpty;
    final showOnlySscRelated = hasSubSectors && _selectedSscUnit == null;
    final effectiveSector = hasSubSectors ? _selectedSscUnit : widget.selectedSector;
    final sectorForScreens = showOnlySscRelated ? widget.selectedSector : effectiveSector;
    final includedCodes = showOnlySscRelated && widget.selectedSector != null
        ? [widget.selectedSector!, ...subSectorCodes]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sector: $_title'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                return IconButton(
                  icon: const Icon(Icons.person),
                  tooltip: widget.username,
                  onPressed: null,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 4),
                    Text(widget.username, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              );
            },
          ),
          SectorNotesAppBarButton(sectorCode: sectorForScreens),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                if (hasSubSectors) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (widget.isAdmin ||
                              (widget.userSectorCodes != null &&
                                  widget.selectedSector != null &&
                                  widget.userSectorCodes!.contains(widget.selectedSector)))
                          ? 'Select unit:'
                          : 'Unit:',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subSectorCodes.map((code) {
                      final isSelected = _selectedSscUnit == code;
                      final color = _sscUnitChipColor(code);
                      // Allow sub-sector selection for admin OR for user whose allowed sectors include this one
                      final canSelectSubSector = widget.isAdmin ||
                          (widget.userSectorCodes != null &&
                              widget.selectedSector != null &&
                              widget.userSectorCodes!.contains(widget.selectedSector) &&
                              hasSubSectors);
                      return ChoiceChip(
                        label: Text(_sectorDisplayName(code)),
                        selected: isSelected,
                        onSelected: canSelectSubSector
                            ? (selected) {
                                setState(() {
                                  _selectedSscUnit = selected ? code : null;
                                });
                              }
                            : null,
                        backgroundColor: color.withOpacity(0.2),
                        selectedColor: color,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildDashboardButtons(
                        context,
                        sectorForScreens: sectorForScreens,
                        includedCodes: includedCodes,
                        showOnlySscRelated: showOnlySscRelated,
                        effectiveSector: effectiveSector,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDashboardButtons(
    BuildContext context, {
    required String? sectorForScreens,
    required List<String>? includedCodes,
    required bool showOnlySscRelated,
    required String? effectiveSector,
  }) {
    final styleBlue = _dashboardButtonStyle(Colors.blue.shade700);
    final styleGreen = _dashboardButtonStyle(Colors.green.shade700);
    final styleTeal = _dashboardButtonStyle(Colors.teal.shade700);
    final styleIndigo = _dashboardButtonStyle(Colors.indigo.shade700);
    final styleAmber = _dashboardButtonStyle(Colors.amber.shade700);
    final stylePurple = _dashboardButtonStyle(Colors.purple.shade700);
    final styleDeepOrange = _dashboardButtonStyle(Colors.deepOrange.shade700);
    final styleBrown = _dashboardButtonStyle(Colors.brown.shade700);
    final styleOrange = _dashboardButtonStyle(Colors.orange.shade700);
    final styleLightGreen = _dashboardButtonStyle(Colors.lightGreen.shade700);

    final buttons = <Widget>[];

    if (widget.isAdmin) {
      buttons.addAll([
        _dashboardButton(
          context,
          icon: Icons.people,
          label: 'Employee Details',
          style: styleBlue,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeDetailsScreen(
                username: widget.username,
                selectedSector: sectorForScreens,
                includedSectorCodes: includedCodes,
                isMainAdmin: widget.isMainAdmin || widget.isAdmin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ]);
    }

    if (showOnlySscRelated || effectiveSector != 'SSMMC') {
      buttons.addAll([
        _dashboardButton(
          context,
          icon: Icons.event_available,
          label: 'Attendance and Advance Details',
          style: styleGreen,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendanceAdvanceScreen(
                username: widget.username,
                selectedSector: sectorForScreens,
                includedSectorCodes: includedCodes,
                isAdmin: widget.isAdmin,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ]);
    }

    buttons.addAll([
      _dashboardButton(
        context,
        icon: Icons.build,
        label: 'Maintenance Issue Report',
        style: styleTeal,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenanceIssueScreen(
              username: widget.username,
              selectedSector: sectorForScreens,
              isMainAdmin: widget.isMainAdmin,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _dashboardButton(
        context,
        icon: Icons.credit_card,
        label: 'Sales Expense and Credit Details',
        style: styleIndigo,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SalesCreditDetailsScreen(
              username: widget.username,
              selectedSector: sectorForScreens,
              includedSectorCodes: includedCodes,
              isMainAdmin: widget.isMainAdmin,
            ),
          ),
        ),
      ),
    ]);

    // Single sector (no subs) or specific unit selected: show combined button
    if (!showOnlySscRelated && effectiveSector != 'SSMMC') {
      buttons.addAll([
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.warehouse,
          label: 'Daily Production and Stock Management',
          style: styleAmber,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockManagementScreen(
                username: widget.username,
                selectedSector: sectorForScreens,
              ),
            ),
          ),
        ),
      ]);
    }

    if (!showOnlySscRelated &&
        (effectiveSector == 'SSMMC' || (widget.selectedSector == null && widget.isAdmin))) {
      buttons.addAll([
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.event_seat,
          label: 'Mahal Booking and Catering Orders Details',
          style: stylePurple,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MahalBookingScreen(
                username: widget.username,
                selectedSector: sectorForScreens,
                isMainAdmin: widget.isMainAdmin,
              ),
            ),
          ),
        ),
      ]);
    }

    if (!showOnlySscRelated &&
        ((widget.selectedSector == null && widget.isAdmin) || effectiveSector == 'SSBM')) {
      buttons.addAll([
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.drive_eta,
          label: 'Vehicle and Driver Details',
          style: styleDeepOrange,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDriverLicenseScreen(
                username: widget.username,
                selectedSector: sectorForScreens,
                isMainAdmin: widget.isMainAdmin,
              ),
            ),
          ),
        ),
      ]);
    }

    if (widget.isAdmin && showOnlySscRelated) {
      buttons.addAll([
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.restaurant_menu,
          label: 'Ingredients Details',
          style: styleBrown,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IngredientsDetailsScreen(
                username: widget.username,
                isMainAdmin: widget.isMainAdmin,
              ),
            ),
          ),
        ),
      ]);
    }

    if (widget.selectedSector == 'SSACF') {
      buttons.addAll([
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.pets,
          label: 'Cattle Datas',
          style: styleOrange,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cattle Datas - Coming soon')),
          ),
        ),
        const SizedBox(height: 10),
        _dashboardButton(
          context,
          icon: Icons.agriculture,
          label: 'Agri Datas',
          style: styleLightGreen,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agri Datas - Coming soon')),
          ),
        ),
      ]);
    }

    return buttons;
  }

  Widget _dashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ButtonStyle style,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: style,
      ),
    );
  }
}

