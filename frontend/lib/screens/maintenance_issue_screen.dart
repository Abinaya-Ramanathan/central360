import 'package:flutter/material.dart';
import '../models/maintenance_issue.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/env_config.dart';
import 'add_issue_dialog.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'upload_photos_dialog.dart';

class MaintenanceIssueScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const MaintenanceIssueScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<MaintenanceIssueScreen> createState() => _MaintenanceIssueScreenState();
}

class _MaintenanceIssueScreenState extends State<MaintenanceIssueScreen> {
  List<MaintenanceIssue> _issues = [];
  List<Sector> _sectors = [];
  final Map<int, bool> _editMode = {}; // Track which rows are in edit mode
  final Map<int, String> _editStatus = {}; // Track edited status
  final Map<int, DateTime?> _editDateResolved = {}; // Track edited date resolved
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column

  @override
  void initState() {
    super.initState();
    _loadSectors();
    _loadIssues();
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

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);
    try {
      final issues = await ApiService.getMaintenanceIssues(
        sector: widget.selectedSector,
      );
      if (mounted) {
        setState(() {
          _issues = issues;
          _editMode.clear();
          _editStatus.clear();
          _editDateResolved.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading issues: $e'),
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

  Future<void> _deleteIssue(int issueId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issue'),
        content: const Text('Are you sure you want to delete this issue?'),
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
      await ApiService.deleteMaintenanceIssue(issueId);
      await _loadIssues();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting issue: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveIssue(int issueId) async {
    final issue = _issues.firstWhere((i) => i.id == issueId);
    final newStatus = _editStatus[issueId] ?? issue.status;
    final newDateResolved = _editDateResolved[issueId];

    setState(() => _isLoading = true);
    try {
      await ApiService.updateMaintenanceIssue(
        id: issueId,
        issueDescription: issue.issueDescription,
        dateCreated: issue.dateCreated,
        status: newStatus,
        dateResolved: newDateResolved,
        sectorCode: issue.sectorCode,
      );
      if (mounted) {
        setState(() {
          _editMode[issueId] = false;
          _editStatus.remove(issueId);
          _editDateResolved.remove(issueId);
        });
        await _loadIssues();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating issue: $e'),
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

  void _toggleEditMode(int issueId) {
    setState(() {
      if (_editMode[issueId] == true) {
        // Cancel edit
        _editMode[issueId] = false;
        _editStatus.remove(issueId);
        _editDateResolved.remove(issueId);
      } else {
        // Enter edit mode
        final issue = _issues.firstWhere((i) => i.id == issueId);
        _editMode[issueId] = true;
        _editStatus[issueId] = issue.status;
        _editDateResolved[issueId] = issue.dateResolved;
      }
    });
  }

  Future<void> _selectDateResolved(int issueId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _editDateResolved[issueId] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _editDateResolved[issueId] = picked;
      });
    }
  }

  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // Images are served from the base URL, not the API endpoint
    return '${EnvConfig.apiBaseUrl}$imageUrl';
  }

  Widget _buildPhotosCell(MaintenanceIssue issue) {
    // Get photos from the issue, or fallback to imageUrl for backward compatibility
    final photos = issue.photos ?? [];
    final hasLegacyImage = issue.imageUrl != null && issue.imageUrl!.isNotEmpty;
    
    if (photos.isEmpty && !hasLegacyImage) {
      return const Center(
        child: Text(
          'No photos',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    // Combine photos and legacy image
    final allImages = <String>[];
    if (hasLegacyImage) {
      allImages.add(issue.imageUrl!);
    }
    for (var photo in photos) {
      allImages.add(photo.imageUrl);
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        final imageUrl = allImages[index];
        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: GestureDetector(
            onTap: () {
              // Show full image in a dialog
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: Stack(
                    children: [
                      Image.network(
                        _getImageUrl(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, size: 50),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _getImageUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Issue Report'),
        backgroundColor: Colors.teal.shade700,
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
      body: _isLoading && _issues.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _issues.isEmpty
                      ? Center(
                          child: Text(
                            widget.selectedSector == null
                                ? 'No maintenance issues found'
                                : 'No maintenance issues in selected sector',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 20,
                              sortColumnIndex: widget.selectedSector == null ? 0 : null,
                              sortAscending: _sortAscending,
                              columns: [
                                if (widget.selectedSector == null)
                                  DataColumn(
                                    label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onSort: (columnIndex, ascending) {
                                      setState(() {
                                        _sortAscending = ascending;
                                        _issues.sort((a, b) {
                                          final aName = _getSectorName(a.sectorCode).toLowerCase();
                                          final bName = _getSectorName(b.sectorCode).toLowerCase();
                                          return ascending
                                              ? aName.compareTo(bName)
                                              : bName.compareTo(aName);
                                        });
                                      });
                                    },
                                  ),
                                const DataColumn(label: Text('Issue Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Date Created', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Date Resolved', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Photos', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _issues.where((issue) => issue.id != null).map((issue) {
                                final issueId = issue.id!;
                                final isEditMode = _editMode[issueId] == true;
                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null)
                                      DataCell(Text(_getSectorName(issue.sectorCode))),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          issue.issueDescription ?? 'N/A',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        issue.dateCreated != null
                                            ? issue.dateCreated!.toIso8601String().split('T')[0]
                                            : 'N/A',
                                      ),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? DropdownButton<String>(
                                              value: _editStatus[issueId] ?? issue.status,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'Resolved',
                                                  child: Text('Resolved'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Not resolved',
                                                  child: Text('Not resolved'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _editStatus[issueId] = value!;
                                                });
                                              },
                                            )
                                          : Text(issue.status),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? InkWell(
                                              onTap: () => _selectDateResolved(issueId),
                                              child: InputDecorator(
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                ),
                                                child: Text(
                                                  _editDateResolved[issueId] != null
                                                      ? _editDateResolved[issueId]!
                                                          .toIso8601String()
                                                          .split('T')[0]
                                                      : 'Select date',
                                                ),
                                              ),
                                            )
                                          : Text(
                                              issue.dateResolved != null
                                                  ? issue.dateResolved!.toIso8601String().split('T')[0]
                                                  : 'N/A',
                                            ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        height: 60,
                                        child: _buildPhotosCell(issue),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isEditMode)
                                            IconButton(
                                              icon: const Icon(Icons.save, color: Colors.green),
                                              onPressed: () => _saveIssue(issueId),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _toggleEditMode(issueId),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.upload, color: Colors.orange),
                                            tooltip: 'Upload Photos',
                                            onPressed: () async {
                                              final result = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => UploadPhotosDialog(
                                                  issueId: issueId,
                                                ),
                                              );
                                              if (result == true) {
                                                await _loadIssues();
                                              }
                                            },
                                          ),
                                          if (widget.isMainAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteIssue(issueId),
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
                      onPressed: widget.selectedSector == null
                          ? null
                          : () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AddIssueDialog(
                                  selectedSector: widget.selectedSector!,
                                ),
                              );
                              if (result == true) {
                                await _loadIssues();
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add Issue',
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
                ),
              ],
            ),
    );
  }
}

