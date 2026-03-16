import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';
import '../widgets/fixed_header_table.dart';
import 'edit_item_name_dialog.dart';

class ManageItemNamesDialog extends StatefulWidget {
  final bool isMainAdmin;
  final String? selectedSector;

  const ManageItemNamesDialog({
    super.key,
    required this.isMainAdmin,
    this.selectedSector,
  });

  @override
  State<ManageItemNamesDialog> createState() => _ManageItemNamesDialogState();
}

class _ManageItemNamesDialogState extends State<ManageItemNamesDialog> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _sortAscending = true;
  String? _searchSectorCode;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getItemNames();
      final sectors = await SectorService().loadSectorsForScreen();
      if (!mounted) return;
      List<Map<String, dynamic>> filtered = list;
      if (widget.selectedSector != null) {
        filtered = list.where((e) => e['sector_code']?.toString() == widget.selectedSector).toList();
      }
      setState(() {
        _items = filtered;
        _filteredItems = _searchSectorCode == null
            ? List.from(filtered)
            : filtered.where((e) => e['sector_code']?.toString() == _searchSectorCode).toList();
        _sectors = sectors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading item names: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getSectorName(String? code) {
    if (code == null) return 'N/A';
    for (final s in _sectors) {
      if (s.code == code) return s.name;
    }
    return code;
  }

  static const double _headerHeight = 48;
  static const double _colItemName = 180;
  static const double _colSector = 120;
  static const double _colVehicleType = 120;
  static const double _colPartNumber = 120;
  static const double _colAction = 120;
  static const double _colSpacing = 20;
  static const double _totalWidth = _colItemName + _colSector + _colVehicleType + _colPartNumber + _colAction + _colSpacing * 4;

  Widget _buildItemNamesFixedTable() {
    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: _totalWidth,
      headerHeight: _headerHeight,
      headerBuilder: (context) => Row(
        children: [
          SizedBox(width: _colItemName, child: const Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colSpacing),
          InkWell(
            onTap: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _filteredItems = List.from(_filteredItems)
                  ..sort((a, b) {
                    final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                    final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                    return _sortAscending ? aName.compareTo(bName) : bName.compareTo(aName);
                  });
              });
            },
            child: SizedBox(width: _colSector, child: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: _colSpacing),
          SizedBox(width: _colVehicleType, child: const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colSpacing),
          SizedBox(width: _colPartNumber, child: const Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colSpacing),
          SizedBox(width: _colAction, child: const Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      rowCount: _filteredItems.length,
      rowBuilder: (context, index) {
        final item = _filteredItems[index];
        final sectorCode = item['sector_code']?.toString();
        final showVehicleFields = sectorCode == 'SSEW';
        return Row(
          children: [
            SizedBox(width: _colItemName, child: Text(item['item_name']?.toString() ?? 'N/A')),
            SizedBox(width: _colSpacing),
            SizedBox(width: _colSector, child: Text(_getSectorName(sectorCode))),
            SizedBox(width: _colSpacing),
            SizedBox(width: _colVehicleType, child: Text(showVehicleFields ? (item['vehicle_type']?.toString() ?? '') : '')),
            SizedBox(width: _colSpacing),
            SizedBox(width: _colPartNumber, child: Text(showVehicleFields ? (item['part_number']?.toString() ?? '') : '')),
            SizedBox(width: _colSpacing),
            SizedBox(
              width: _colAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _editItemName(item),
                  ),
                  if (widget.isMainAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => _deleteItemName(
                        item['id'] as int,
                        item['item_name']?.toString() ?? 'Item Name',
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteItemName(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item Name'),
        content: Text('Are you sure you want to delete "$name"?'),
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
      await ApiService.deleteItemName(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item name deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editItemName(Map<String, dynamic> itemData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditItemNameDialog(
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
                        'Manage Item Names',
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
                            _filteredItems = List.from(_items);
                          } else {
                            _filteredItems = _items.where((e) => e['sector_code']?.toString() == value).toList();
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
                  : _filteredItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No item names found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : _buildItemNamesFixedTable(),
            ),
          ],
        ),
      ),
    );
  }
}
