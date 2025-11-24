import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class ProductionTabContent extends StatefulWidget {
  final String? selectedSector;
  final int? selectedMonth;
  final DateTime? selectedDate;
  final bool isAdmin;

  const ProductionTabContent({
    super.key,
    this.selectedSector,
    this.selectedMonth,
    this.selectedDate,
    this.isAdmin = false,
  });

  @override
  State<ProductionTabContent> createState() => _ProductionTabContentState();
}

class _ProductionTabContentState extends State<ProductionTabContent> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _productionData = [];
  bool _isLoading = false;

  List<Sector> _sectors = [];

  @override
  void initState() {
    super.initState();
    _loadSectors();
    if (widget.selectedMonth != null && widget.selectedDate != null) {
      if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
  }

  @override
  void didUpdateWidget(ProductionTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedMonth != oldWidget.selectedMonth ||
            widget.selectedDate != oldWidget.selectedDate ||
            widget.selectedSector != oldWidget.selectedSector) &&
        widget.selectedMonth != null &&
        widget.selectedDate != null) {
      if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
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

  Future<void> _loadData() async {
    if (widget.selectedDate == null) return;
    if (widget.selectedSector == null && !widget.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      await _loadProducts();
      await _loadProductionData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    if (widget.selectedSector == null && !widget.isAdmin) return;
    try {
      if (widget.selectedSector == null && widget.isAdmin) {
        // Load all products from all sectors
        final allSectors = await ApiService.getSectors();
        _products = [];
        for (var sector in allSectors) {
          final sectorProducts = await ApiService.getProducts(sector: sector.code);
          // Add sector_code to each product for identification
          for (var product in sectorProducts) {
            product['sector_code'] = sector.code;
            _products.add(product);
          }
        }
      } else {
        _products = await ApiService.getProducts(sector: widget.selectedSector);
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _loadProductionData() async {
    if (widget.selectedDate == null) return;
    if (widget.selectedSector == null && !widget.isAdmin) return;
    
    if (_products.isEmpty) {
      await _loadProducts();
      if (_products.isEmpty) {
        setState(() {
          _productionData = [];
        });
        return;
      }
    }

    try {
      final year = widget.selectedDate!.year;
      final month = widget.selectedMonth ?? widget.selectedDate!.month;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final dateStr = widget.selectedDate!.toIso8601String().split('T')[0];

      final records = await ApiService.getDailyProduction(
        month: monthStr,
        date: dateStr,
      );
      
      // Filter by sector if not "All Sectors"
      final filteredRecords = widget.selectedSector == null && widget.isAdmin
          ? records
          : records.where((r) => r['sector_code']?.toString() == widget.selectedSector).toList();

      // Create a map keyed by product_name + sector_code for "All Sectors" view
      final Map<String, Map<String, dynamic>> existingRecordsMap = {};
      for (var record in filteredRecords) {
        final productName = record['product_name']?.toString() ?? '';
        final sectorCode = record['sector_code']?.toString() ?? '';
        final key = widget.selectedSector == null && widget.isAdmin
            ? '$productName|$sectorCode'
            : productName;
        existingRecordsMap[key] = record;
      }

      final List<Map<String, dynamic>> finalData = [];
      for (var product in _products) {
        final productName = product['product_name']?.toString() ?? '';
        final sectorCode = product['sector_code']?.toString() ?? '';
        final key = widget.selectedSector == null && widget.isAdmin
            ? '$productName|$sectorCode'
            : productName;
        
        if (existingRecordsMap.containsKey(key)) {
          finalData.add(existingRecordsMap[key]!);
          existingRecordsMap.remove(key);
        } else {
          finalData.add({
            'product_name': productName,
            'sector_code': sectorCode,
            'morning_production': 0,
            'afternoon_production': 0,
            'evening_production': 0,
            'production_date': dateStr,
          });
        }
      }

      setState(() {
        _productionData = finalData;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading production data: $e')),
        );
      }
    }
  }

  int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int? _parseIdFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  int _parseIntValue(String value) {
    if (value.isEmpty) return 0;
    final parsed = int.tryParse(value);
    return parsed ?? 0;
  }

  Future<void> _showEditProductionDialog() async {
    if (widget.selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    if (_productionData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available for this sector')),
      );
      return;
    }

    final Map<String, TextEditingController> morningControllers = {};
    final Map<String, TextEditingController> afternoonControllers = {};
    final Map<String, TextEditingController> eveningControllers = {};

    for (var record in _productionData) {
      final productName = record['product_name']?.toString() ?? '';
      final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
      // Create unique key for controllers when "All Sectors" is selected
      final controllerKey = widget.selectedSector == null && widget.isAdmin
          ? '$productName|$sectorCode'
          : productName;
      
      morningControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['morning_production']).toString(),
      );
      afternoonControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['afternoon_production']).toString(),
      );
      eveningControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['evening_production']).toString(),
      );
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Production Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _productionData.map((record) {
                final productName = record['product_name']?.toString() ?? '';
                final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
                final controllerKey = widget.selectedSector == null && widget.isAdmin
                    ? '$productName|$sectorCode'
                    : productName;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedSector == null && widget.isAdmin
                            ? '$productName (${_getSectorName(sectorCode)})'
                            : productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: morningControllers[controllerKey],
                              decoration: const InputDecoration(
                                labelText: 'Morning',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: afternoonControllers[controllerKey],
                              decoration: const InputDecoration(
                                labelText: 'Afternoon',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: eveningControllers[controllerKey],
                              decoration: const InputDecoration(
                                labelText: 'Evening',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (var controller in morningControllers.values) {
                controller.dispose();
              }
              for (var controller in afternoonControllers.values) {
                controller.dispose();
              }
              for (var controller in eveningControllers.values) {
                controller.dispose();
              }
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                final dateStr = widget.selectedDate!.toIso8601String().split('T')[0];

                for (var record in _productionData) {
                  final productName = record['product_name']?.toString() ?? '';
                  final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
                  final recordId = _parseIdFromDynamic(record['id']);
                  
                  // Create unique key for controllers when "All Sectors" is selected
                  final controllerKey = widget.selectedSector == null && widget.isAdmin
                      ? '$productName|$sectorCode'
                      : productName;

                  final productionRecord = {
                    if (recordId != null) 'id': recordId,
                    'product_name': productName,
                    'sector_code': sectorCode,
                    'morning_production': _parseIntValue(morningControllers[controllerKey]!.text),
                    'afternoon_production': _parseIntValue(afternoonControllers[controllerKey]!.text),
                    'evening_production': _parseIntValue(eveningControllers[controllerKey]!.text),
                    'production_date': dateStr,
                  };

                  await ApiService.saveDailyProduction(productionRecord);
                }

                for (var controller in morningControllers.values) {
                  controller.dispose();
                }
                for (var controller in afternoonControllers.values) {
                  controller.dispose();
                }
                for (var controller in eveningControllers.values) {
                  controller.dispose();
                }

                if (mounted) {
                  Navigator.pop(context, true);
                  await _loadProductionData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Production data saved successfully')),
                  );
                }
              } catch (e) {
                for (var controller in morningControllers.values) {
                  controller.dispose();
                }
                for (var controller in afternoonControllers.values) {
                  controller.dispose();
                }
                for (var controller in eveningControllers.values) {
                  controller.dispose();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving production data: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedMonth == null || widget.selectedDate == null) {
      return const Center(
        child: Text(
          'Please select month and date',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (widget.selectedSector == null && !widget.isAdmin) {
      return const Center(
        child: Text(
          'Please select a sector from Home page',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final showSectorColumn = widget.isAdmin && widget.selectedSector == null;

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _productionData.isEmpty
                  ? const Center(
                      child: Text(
                        'No products available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 20,
                          columns: [
                            if (showSectorColumn)
                              const DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Morning Production', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Afternoon Production', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Evening Production', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _productionData.map((record) {
                            return DataRow(
                              cells: [
                                if (showSectorColumn)
                                  DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                DataCell(Text(record['product_name']?.toString() ?? '')),
                                DataCell(Text('${_parseIntFromDynamic(record['morning_production'])}')),
                                DataCell(Text('${_parseIntFromDynamic(record['afternoon_production'])}')),
                                DataCell(Text('${_parseIntFromDynamic(record['evening_production'])}')),
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
              onPressed: _isLoading ? null : _showEditProductionDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Production Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

