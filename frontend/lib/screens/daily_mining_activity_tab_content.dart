import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class DailyMiningActivityTabContent extends StatefulWidget {
  final String? selectedSector;
  final bool isAdmin;

  const DailyMiningActivityTabContent({
    super.key,
    this.selectedSector,
    required this.isAdmin,
  });

  @override
  State<DailyMiningActivityTabContent> createState() => _DailyMiningActivityTabContentState();
}

class _DailyMiningActivityTabContentState extends State<DailyMiningActivityTabContent> {
  List<Map<String, dynamic>> _miningActivities = [];
  List<Map<String, dynamic>> _dailyEntries = [];
  List<Sector> _sectors = [];
  DateTime? _selectedDate;
  bool _isLoading = false;
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, bool> _editMode = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadSectors();
    _loadMiningActivities();
    _loadDailyEntries();
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _loadMiningActivities() async {
    try {
      List<Map<String, dynamic>> activities;
      if (widget.selectedSector == null && widget.isAdmin) {
        activities = await ApiService.getMiningActivities();
      } else if (widget.selectedSector != null) {
        activities = await ApiService.getMiningActivities(sector: widget.selectedSector);
      } else {
        activities = [];
      }
      if (mounted) {
        setState(() {
          _miningActivities = activities;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mining activities: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadDailyEntries() async {
    if (_selectedDate == null) return;
    if (widget.selectedSector == null && !widget.isAdmin) return;

    // Clear edit mode and controllers when loading new date data
    setState(() {
      _editMode.clear();
      for (var controller in _quantityControllers.values) {
        controller.dispose();
      }
      _quantityControllers.clear();
    });

    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final entries = await ApiService.getDailyMiningActivities(
        date: dateStr,
        sector: widget.selectedSector,
      );
      if (mounted) {
        setState(() {
          _dailyEntries = entries;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading daily entries: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadDailyEntries();
    }
  }

  Future<void> _saveEntry(int activityId) async {
    if (_selectedDate == null) return;

    final quantityController = _quantityControllers[activityId];
    if (quantityController == null) return;

    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final quantity = double.tryParse(quantityController.text) ?? 0.0;

      await ApiService.createOrUpdateDailyMiningActivity(
        activityId: activityId,
        date: dateStr,
        quantity: quantity,
      );

      // Exit edit mode after successful save
      setState(() {
        _editMode[activityId] = false;
      });

      await _loadDailyEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mining activity entry saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleEditMode(int activityId) {
    setState(() {
      if (_editMode[activityId] == true) {
        // Exiting edit mode - dispose controller
        if (_quantityControllers.containsKey(activityId)) {
          _quantityControllers[activityId]!.dispose();
          _quantityControllers.remove(activityId);
        }
        _editMode[activityId] = false;
      } else {
        // Entering edit mode
        _editMode[activityId] = true;
        final existingEntry = _dailyEntries.firstWhere(
          (entry) => entry['activity_id'] == activityId,
          orElse: () => {},
        );

        _quantityControllers[activityId] = TextEditingController(
          text: existingEntry['quantity']?.toString() ?? '0',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date Selection
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? _selectedDate!.toIso8601String().split('T')[0]
                          : 'Select Date',
                      style: TextStyle(
                        color: _selectedDate != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Mining Activities Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _miningActivities.isEmpty
                  ? const Center(
                      child: Text(
                        'No mining activities found. Please add mining activities first.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DataTable(
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(label: Text('Activity Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _miningActivities.map((activity) {
                                final activityId = activity['id'] as int;
                                final isEditMode = _editMode[activityId] == true;
                                final existingEntry = _dailyEntries.firstWhere(
                                  (entry) => entry['activity_id'] == activityId,
                                  orElse: () => {},
                                );

                                return DataRow(
                                  cells: [
                                    DataCell(Text(activity['activity_name']?.toString() ?? 'N/A')),
                                    DataCell(Text(_getSectorName(activity['sector_code']?.toString()))),
                                    DataCell(
                                      isEditMode && _quantityControllers.containsKey(activityId)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _quantityControllers[activityId],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.number,
                                              ),
                                            )
                                          : Text(existingEntry['quantity']?.toString() ?? '0'),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                                  tooltip: 'Save',
                                                  onPressed: () => _saveEntry(activityId),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                  tooltip: 'Cancel',
                                                  onPressed: () => _toggleEditMode(activityId),
                                                ),
                                              ],
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                              tooltip: 'Edit',
                                              onPressed: () => _toggleEditMode(activityId),
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
        ),
      ],
    );
  }
}

