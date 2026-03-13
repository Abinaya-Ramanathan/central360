import 'package:flutter/material.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'update_dialog.dart';
import '../services/update_service.dart';
import 'new_entry_screen.dart';
import 'sector_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  /// Sector codes the user can access (keyword login). Null for admin (sees all).
  final List<String>? initialSectorCodes;
  final bool isAdmin;
  final bool isMainAdmin;

  const HomeScreen({
    super.key,
    required this.username,
    this.initialSectorCodes,
    this.isAdmin = false,
    this.isMainAdmin = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Internal value for the "All Sectors" button (so null can mean "no selection").
const _allSectorsValue = '__ALL__';

class _HomeScreenState extends State<HomeScreen> {
  final SectorService _sectorService = SectorService();
  List<Sector> _sectors = [];
  bool _isAdmin = false;
  bool _isMainAdmin = false;

  /// Top-level sectors to show on home: no parent, or parent code added if it has children but is missing.
  List<Sector> get _displaySectors {
    final topLevel = _sectors
        .where((s) => s.parentCode == null || (s.parentCode?.isEmpty ?? true))
        .toList();
    final parentCodes = _sectors
        .where((s) => s.parentCode != null && s.parentCode!.isNotEmpty)
        .map((s) => s.parentCode!)
        .toSet();
    for (final code in parentCodes) {
      if (!topLevel.any((s) => s.code == code)) {
        topLevel.add(Sector(code: code, name: code));
      }
    }
    return topLevel;
  }

  Color _sectorButtonColor(String value) {
    if (value == _allSectorsValue) return Colors.indigo.shade700;
    switch (value) {
      case 'SSC':
        return Colors.purple.shade700;
      case 'SSBM':
        return Colors.deepOrange.shade700;
      default:
        // Deterministic color selection for any other sector codes.
        const palette = [
          Colors.teal,
          Colors.green,
          Colors.cyan,
          Colors.brown,
          Colors.amber,
          Colors.blueGrey,
        ];
        final idx = value.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
        return palette[idx].shade700;
    }
  }

  ButtonStyle _homeHeaderButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  /// Sector values to show as buttons: New Entry first, then these (admin: All + displaySectors; non-admin: from initialSectorCodes).
  List<String> get _sectorButtonValues {
    if (_isAdmin) {
      return [_allSectorsValue, ..._displaySectors.map((s) => s.code)];
    }
    final codes = widget.initialSectorCodes;
    if (codes != null && codes.isNotEmpty) {
      return codes;
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Admin privileges are determined by backend based on password
    // Use AuthService if available, otherwise fall back to widget parameters
    _isAdmin = AuthService.isAdmin || widget.isAdmin;
    _isMainAdmin = AuthService.isMainAdmin || widget.isMainAdmin;
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
        debugPrint('Update available: ${updateInfo.versionString}');
        
        // Show update dialog
        final shouldUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: !updateInfo.isRequired,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
        
        // If user clicked "Later", mark this version as dismissed
        if (shouldUpdate == false && !updateInfo.isRequired) {
          debugPrint('User dismissed update ${updateInfo.versionString} - saving to preferences');
          await UpdateService.dismissVersion(
            updateInfo.latestVersion,
            updateInfo.latestBuildNumber,
          );
          debugPrint('Update ${updateInfo.versionString} marked as dismissed');
        }
        
        // If update is required and user dismissed, show again after delay
        // But only if it's actually required
        if (updateInfo.isRequired && shouldUpdate == false) {
          debugPrint('Required update dismissed - will check again in 5 seconds');
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _checkForUpdates();
          });
        }
      } else {
        debugPrint('No update available or already dismissed');
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
            // Home page: New Entry top right (line 1), sector buttons (line 2)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First line: New Entry button top right
                  if (_isAdmin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewEntryScreen(
                                username: widget.username,
                                selectedSector: null,
                                isMainAdmin: _isMainAdmin,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) _loadSectors();
                          });
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('New Entry'),
                        style: _homeHeaderButtonStyle(Colors.blue.shade700),
                      ),
                    ),
                  if (_isAdmin) const SizedBox(height: 12),
                  // Second line: sector buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sectorButtonValues.map((value) {
                      final label = value == _allSectorsValue
                          ? 'All Sectors'
                          : () {
                              final inDisplay = _displaySectors.where((s) => s.code == value);
                              if (inDisplay.isNotEmpty) return '$value - ${inDisplay.first.name}';
                              final inAll = _sectors.where((s) => s.code == value);
                              return inAll.isNotEmpty ? '$value - ${inAll.first.name}' : value;
                            }();
                      return ElevatedButton(
                        onPressed: () {
                          final sector = value == _allSectorsValue ? null : value;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SectorDashboardScreen(
                                username: widget.username,
                                selectedSector: sector,
                                isAdmin: _isAdmin,
                                isMainAdmin: _isMainAdmin,
                                userSectorCodes: widget.initialSectorCodes,
                              ),
                            ),
                          );
                        },
                        style: _homeHeaderButtonStyle(_sectorButtonColor(value)),
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
