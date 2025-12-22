import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';
import 'edit_mining_activity_dialog.dart';

class ManageMiningActivitiesDialog extends StatefulWidget {
  final bool isMainAdmin;
  final String? selectedSector;

  const ManageMiningActivitiesDialog({
    super.key,
    required this.isMainAdmin,
    this.selectedSector,
  });

  @override
  State<ManageMiningActivitiesDialog> createState() => _ManageMiningActivitiesDialogState();
}

class _ManageMiningActivitiesDialogState extends State<ManageMiningActivitiesDialog> {
  List<Map<String, dynamic>> _miningActivities = [];
  List<Map<String, dynamic>> _filteredMiningActivities = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column
  String? _searchSectorCode; // Selected sector for search filter

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final miningActivities = await ApiService.getMiningActivities();
      final sectors = await ApiService.getSectors();
      if (mounted) {
        // Filter mining activities by selected sector
        List<Map<String, dynamic>> filteredActivities = miningActivities;
        if (widget.selectedSector != null) {
          filteredActivities = miningActivities.where((activity) {
            final activitySector = activity['sector_code']?.toString();
            return activitySector == widget.selectedSector;
          }).toList();
        }
        
        setState(() {
          _miningActivities = filteredActivities;
          _filteredMiningActivities = filteredActivities;
          _sectors = sectors;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mining activities: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getSectorName(String? sectorCode) {
    if (sectorCode == null) return 'N/A';
    final sector = _sectors.firstWhere(
      (s) => s.code == sectorCode,
      orElse: () => Sector(code: sectorCode, name: sectorCode),
    );
    return sector.name;
  }

  Future<void> _deleteMiningActivity(int activityId, String activityName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mining Activity'),
        content: Text('Are you sure you want to delete "$activityName"?'),
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
      await ApiService.deleteMiningActivity(activityId.toString());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mining activity deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting mining activity: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editMiningActivity(Map<String, dynamic> activityData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditMiningActivityDialog(
        activityId: activityData['id'] as int,
        activityName: activityData['activity_name'] as String,
        sectorCode: activityData['sector_code'] as String,
        description: activityData['description']?.toString(),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Mining Activities',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (widget.selectedSector != null)
                        Text(
                          'Sector: ${_getSectorName(widget.selectedSector)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        )
                      else
                        const Text(
                          'All Sectors',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            // Sector Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  const Text('Search by Sector:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _searchSectorCode,
                      decoration: InputDecoration(
                        hintText: 'All Sectors',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
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
                      ],
                      onChanged: (value) {
                        setState(() {
                          _searchSectorCode = value;
                          if (value == null) {
                            _filteredMiningActivities = _miningActivities;
                          } else {
                            _filteredMiningActivities = _miningActivities.where((activity) {
                              return activity['sector_code']?.toString() == value;
                            }).toList();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMiningActivities.isEmpty
                      ? const Center(
                          child: Text(
                            'No mining activities found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 20,
                              sortColumnIndex: 1,
                              sortAscending: _sortAscending,
                              columns: [
                                const DataColumn(label: Text('Activity Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(
                                  label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (columnIndex, ascending) {
                                    setState(() {
                                      _sortAscending = ascending;
                                      _miningActivities.sort((a, b) {
                                        final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                        final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                        return ascending
                                            ? aName.compareTo(bName)
                                            : bName.compareTo(aName);
                                      });
                                    });
                                  },
                                ),
                                const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _filteredMiningActivities.map((activity) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(activity['activity_name']?.toString() ?? 'N/A')),
                                    DataCell(Text(_getSectorName(activity['sector_code']?.toString()))),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          activity['description']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            tooltip: 'Edit',
                                            onPressed: () => _editMiningActivity(activity),
                                          ),
                                          if (widget.isMainAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteMiningActivity(
                                                activity['id'] as int,
                                                activity['activity_name']?.toString() ?? 'Mining Activity',
                                              ),
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
            ),
          ],
        ),
      ),
    );
  }
}

