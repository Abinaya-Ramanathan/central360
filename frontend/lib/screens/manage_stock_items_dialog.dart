import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';
import 'edit_stock_item_dialog.dart';

class ManageStockItemsDialog extends StatefulWidget {
  final bool isMainAdmin;
  final String? selectedSector;

  const ManageStockItemsDialog({
    super.key,
    required this.isMainAdmin,
    this.selectedSector,
  });

  @override
  State<ManageStockItemsDialog> createState() => _ManageStockItemsDialogState();
}

class _ManageStockItemsDialogState extends State<ManageStockItemsDialog> {
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _filteredStockItems = [];
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
      final stockItems = await ApiService.getStockItems();
      final sectors = await ApiService.getSectors();
      if (mounted) {
        // Filter stock items by selected sector
        List<Map<String, dynamic>> filteredStockItems = stockItems;
        if (widget.selectedSector != null) {
          filteredStockItems = stockItems.where((item) {
            final itemSector = item['sector_code']?.toString();
            return itemSector == widget.selectedSector;
          }).toList();
        }
        
        setState(() {
          _stockItems = filteredStockItems;
          _filteredStockItems = filteredStockItems;
          _sectors = sectors;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stock items: $e'), backgroundColor: Colors.red),
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

  Future<void> _deleteStockItem(int itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stock Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
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
      await ApiService.deleteStockItem(itemId.toString());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting stock item: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editStockItem(Map<String, dynamic> itemData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditStockItemDialog(
        itemId: itemData['id'] as int,
        itemName: itemData['item_name'] as String,
        sectorCode: itemData['sector_code'] as String,
        vehicleType: itemData['vehicle_type']?.toString(),
        partNumber: itemData['part_number']?.toString(),
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
                        'Manage Stock Items',
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
                            _filteredStockItems = _stockItems;
                          } else {
                            _filteredStockItems = _stockItems.where((item) {
                              return item['sector_code']?.toString() == value;
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
                  : _filteredStockItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No stock items found',
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
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(
                                  label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (columnIndex, ascending) {
                                    setState(() {
                                      _sortAscending = ascending;
                                      _stockItems.sort((a, b) {
                                        final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                        final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                        return ascending
                                            ? aName.compareTo(bName)
                                            : bName.compareTo(aName);
                                      });
                                    });
                                  },
                                ),
                                // Show vehicle type and part number columns
                                const DataColumn(label: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _filteredStockItems.map((item) {
                                final sectorCode = item['sector_code']?.toString();
                                final showVehicleFields = sectorCode == 'SSEW';
                                
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item['item_name']?.toString() ?? 'N/A')),
                                    DataCell(Text(_getSectorName(sectorCode))),
                                    DataCell(Text(showVehicleFields ? (item['vehicle_type']?.toString() ?? '') : '')),
                                    DataCell(Text(showVehicleFields ? (item['part_number']?.toString() ?? '') : '')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            tooltip: 'Edit',
                                            onPressed: () => _editStockItem(item),
                                          ),
                                          if (widget.isMainAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteStockItem(
                                                item['id'] as int,
                                                item['item_name']?.toString() ?? 'Stock Item',
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

