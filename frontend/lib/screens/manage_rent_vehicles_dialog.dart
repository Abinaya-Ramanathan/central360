import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';
import 'edit_rent_vehicle_dialog.dart';

class ManageRentVehiclesDialog extends StatefulWidget {
  final bool isMainAdmin;
  final String? selectedSector;

  const ManageRentVehiclesDialog({
    super.key,
    required this.isMainAdmin,
    this.selectedSector,
  });

  @override
  State<ManageRentVehiclesDialog> createState() => _ManageRentVehiclesDialogState();
}

class _ManageRentVehiclesDialogState extends State<ManageRentVehiclesDialog> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
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
      final vehicles = await ApiService.getRentVehicles();
      final sectors = await ApiService.getSectors();
      if (mounted) {
        // Filter vehicles by selected sector
        List<Map<String, dynamic>> filteredVehicles = vehicles;
        if (widget.selectedSector != null) {
          filteredVehicles = vehicles.where((vehicle) {
            final vehicleSector = vehicle['sector_code']?.toString();
            return vehicleSector == widget.selectedSector;
          }).toList();
        }
        
        setState(() {
          _vehicles = filteredVehicles;
          _filteredVehicles = filteredVehicles;
          _sectors = sectors;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e'), backgroundColor: Colors.red),
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

  Future<void> _deleteVehicle(int vehicleId, String vehicleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rent Vehicle'),
        content: Text('Are you sure you want to delete "$vehicleName"?'),
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
      await ApiService.deleteRentVehicle(vehicleId.toString());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting vehicle: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editVehicle(Map<String, dynamic> vehicleData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditRentVehicleDialog(
        vehicleId: vehicleData['id'] as int,
        vehicleName: vehicleData['vehicle_name'] as String,
        sectorCode: vehicleData['sector_code'] as String,
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
                        'Manage Rent Vehicles',
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
                      value: _searchSectorCode,
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
                            _filteredVehicles = _vehicles;
                          } else {
                            _filteredVehicles = _vehicles.where((vehicle) {
                              return vehicle['sector_code']?.toString() == value;
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
                  : _filteredVehicles.isEmpty
                      ? const Center(
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 20,
                            sortColumnIndex: 1,
                            sortAscending: _sortAscending,
                            columns: [
                              const DataColumn(label: Text('Vehicle Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortAscending = ascending;
                                    _vehicles.sort((a, b) {
                                      final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                      final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                      return ascending
                                          ? aName.compareTo(bName)
                                          : bName.compareTo(aName);
                                    });
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredVehicles.map((vehicle) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(vehicle['vehicle_name']?.toString() ?? 'N/A')),
                                  DataCell(Text(_getSectorName(vehicle['sector_code']?.toString()))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit',
                                          onPressed: () => _editVehicle(vehicle),
                                        ),
                                        if (widget.isMainAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            tooltip: 'Delete',
                                            onPressed: () => _deleteVehicle(
                                              vehicle['id'] as int,
                                              vehicle['vehicle_name']?.toString() ?? 'Vehicle',
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
          ],
        ),
      ),
    );
  }
}

