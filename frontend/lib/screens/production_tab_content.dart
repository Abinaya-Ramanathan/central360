import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../widgets/fixed_header_table.dart';

/// Callback (isEditMode) when production enters or exits edit mode.
typedef OnProductionEditModeChanged = void Function(bool isEditMode);

class ProductionTabContent extends StatefulWidget {
  final String? selectedSector;
  /// When set, show consolidated data for main + subsectors with sector name column.
  final List<String>? includedSectorCodes;
  final DateTime? selectedDate;
  final bool isAdmin;
  final VoidCallback? onEditPressed;
  final TextEditingController? searchController;
  /// Notify parent when edit mode is toggled (so parent can show Cancel/Save).
  final OnProductionEditModeChanged? onEditModeChanged;

  const ProductionTabContent({
    super.key,
    this.selectedSector,
    this.includedSectorCodes,
    this.selectedDate,
    this.isAdmin = false,
    this.onEditPressed,
    this.searchController,
    this.onEditModeChanged,
  });

  @override
  State<ProductionTabContent> createState() => _ProductionTabContentState();
}

class _ProductionTabContentState extends State<ProductionTabContent> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _productionData = [];
  List<Map<String, dynamic>> _filteredProductionData = [];
  bool _isLoading = false;
  late final TextEditingController _searchController;
  bool _sortAscending = true; // Sort direction for Sector column
  final Map<String, String?> _productionUnits = {}; // First column unit (morning/overall)
  final Map<String, String?> _unitAfternoon = {};   // Second column unit (cafe)
  final Map<String, String?> _unitEvening = {};    // Third column unit (cafe)
  final Map<String, String?> _unitStockInCanteen = {}; // Stock in canteen unit (CS)

  List<Sector> _sectors = [];
  bool _isEditModeProduction = false;
  final Map<String, TextEditingController> _morningControllers = {};
  final Map<String, TextEditingController> _afternoonControllers = {};
  final Map<String, TextEditingController> _eveningControllers = {};
  final Map<String, TextEditingController> _stockInCanteenControllers = {};
  
  // Horizontal ScrollController for draggable scrollbar
  final ScrollController _horizontalScrollController = ScrollController();

  static const double _headerHeight = 48;
  static const double _colSector = 120;
  static const double _colProductName = 150;
  static const double _colNum = 90;
  static const double _colUnit = 75;
  static const double _colSpacing = 20;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    if (widget.searchController == null) {
      _searchController.addListener(_filterProductionData);
    }
    _loadSectors();
    if (widget.selectedDate != null) {
      if (widget.selectedSector != null ||
          (widget.isAdmin && widget.selectedSector == null) ||
          (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)) {
        _loadData();
      }
    }
  }

  @override
  void dispose() {
    _disposeProductionControllers();
    // Only dispose if we created the controller ourselves
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _initProductionControllers() {
    _disposeProductionControllers();
    for (var record in _productionData) {
      final productName = record['product_name']?.toString() ?? '';
      final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
      final controllerKey = _isConsolidatedView ? '$productName|$sectorCode' : productName;
      _morningControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['morning_production']).toString(),
      );
      _afternoonControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['afternoon_production']).toString(),
      );
      _eveningControllers[controllerKey] = TextEditingController(
        text: _parseIntFromDynamic(record['evening_production']).toString(),
      );
      if (_isCanteenStore) {
        _stockInCanteenControllers[controllerKey] = TextEditingController(
          text: (record['stock_in_canteen'] != null
              ? _parseIntFromDynamic(record['stock_in_canteen'])
              : 0)
              .toString(),
        );
      }
      if (!_productionUnits.containsKey(controllerKey)) {
        _productionUnits[controllerKey] = record['unit']?.toString();
      }
      if (_isCafeProduction) {
        if (!_unitAfternoon.containsKey(controllerKey)) {
          _unitAfternoon[controllerKey] = record['unit_afternoon']?.toString();
        }
        if (!_unitEvening.containsKey(controllerKey)) {
          _unitEvening[controllerKey] = record['unit_evening']?.toString();
        }
      }
      if (_isCanteenStore && !_unitStockInCanteen.containsKey(controllerKey)) {
        _unitStockInCanteen[controllerKey] = record['unit_stock_in_canteen']?.toString();
      }
    }
  }

  void _disposeProductionControllers() {
    for (var c in _morningControllers.values) {
      c.dispose();
    }
    for (var c in _afternoonControllers.values) {
      c.dispose();
    }
    for (var c in _eveningControllers.values) {
      c.dispose();
    }
    for (var c in _stockInCanteenControllers.values) {
      c.dispose();
    }
    _morningControllers.clear();
    _afternoonControllers.clear();
    _eveningControllers.clear();
    _stockInCanteenControllers.clear();
  }

  void cancelEdit() {
    _disposeProductionControllers();
    setState(() => _isEditModeProduction = false);
    widget.onEditModeChanged?.call(false);
  }

  Future<void> saveProduction() async {
    if (widget.selectedDate == null) return;
    final dateStr = FormatUtils.formatDateForApi(widget.selectedDate!);
    setState(() => _isLoading = true);
    int successCount = 0;
    int failCount = 0;
    String? lastError;
    try {
      for (var record in _productionData) {
        final productName = record['product_name']?.toString() ?? '';
        final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
        final recordId = _parseIdFromDynamic(record['id']);
        if (productName.isEmpty || sectorCode == null || sectorCode.isEmpty) continue;
        final controllerKey = _isConsolidatedView ? '$productName|$sectorCode' : productName;
        if (!_morningControllers.containsKey(controllerKey) ||
            !_afternoonControllers.containsKey(controllerKey) ||
            !_eveningControllers.containsKey(controllerKey)) {
          continue;
        }
        final productionRecord = {
          if (recordId != null) 'id': recordId,
          'product_name': productName,
          'sector_code': sectorCode,
          'morning_production': _parseIntValue(_morningControllers[controllerKey]!.text),
          'afternoon_production': _parseIntValue(_afternoonControllers[controllerKey]!.text),
          'evening_production': _parseIntValue(_eveningControllers[controllerKey]!.text),
          'unit': _productionUnits[controllerKey],
          'production_date': dateStr,
          if (_isCanteenStore)
            'stock_in_canteen': _parseIntValue(_stockInCanteenControllers[controllerKey]?.text ?? '0'),
          if (_isCafeProduction) ...{
            'unit_afternoon': _unitAfternoon[controllerKey],
            'unit_evening': _unitEvening[controllerKey],
          },
          if (_isCanteenStore) 'unit_stock_in_canteen': _unitStockInCanteen[controllerKey],
        };
        try {
          await ApiService.saveDailyProduction(productionRecord);
          successCount++;
        } catch (e) {
          failCount++;
          lastError = e.toString();
        }
      }
      if (mounted) {
        _disposeProductionControllers();
        setState(() {
          _isEditModeProduction = false;
          _isLoading = false;
        });
        widget.onEditModeChanged?.call(false);
        if (_products.isEmpty) await _loadProducts();
        await _loadProductionData();
        _filterProductionData();
        if (failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved $successCount record(s). $failCount failed. ${lastError ?? ''}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Production data saved successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving production data: $e')),
        );
      }
    }
  }

  void _filterProductionData() {
    final searchQuery = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> list;
    if (searchQuery.isEmpty) {
      list = List.from(_productionData);
    } else {
      list = _productionData.where((record) {
        final productName = record['product_name']?.toString().toLowerCase() ?? '';
        return productName.contains(searchQuery);
      }).toList();
    }
    // Rows with any value > 0 first
    list.sort((a, b) {
      final aSum = _parseIntFromDynamic(a['morning_production']) + _parseIntFromDynamic(a['afternoon_production']) + _parseIntFromDynamic(a['evening_production']) + _parseIntFromDynamic(a['stock_in_canteen']);
      final bSum = _parseIntFromDynamic(b['morning_production']) + _parseIntFromDynamic(b['afternoon_production']) + _parseIntFromDynamic(b['evening_production']) + _parseIntFromDynamic(b['stock_in_canteen']);
      if (aSum > 0 && bSum == 0) return -1;
      if (aSum == 0 && bSum > 0) return 1;
      return 0;
    });
    setState(() {
      _filteredProductionData = list;
    });
  }

  @override
  void didUpdateWidget(ProductionTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedDate != oldWidget.selectedDate ||
            widget.selectedSector != oldWidget.selectedSector) &&
        widget.selectedDate != null) {
      if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null)) {
        _loadData();
      }
    }
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await SectorService().loadSectorsForScreen();
      if (mounted) setState(() => _sectors = sectors);
    } catch (_) {}
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
    if (widget.selectedSector == null && !widget.isAdmin &&
        (widget.includedSectorCodes == null || widget.includedSectorCodes!.isEmpty)) {
      return;
    }

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

  bool get _isConsolidatedView =>
      (widget.isAdmin && widget.selectedSector == null) ||
      (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty);

  /// Canteen Store (CS) sector: different column labels and Stock in Canteen column.
  bool get _isCanteenStore => widget.selectedSector == 'CS';
  /// Sri Surya cafe sectors: show unit column for each quantity column.
  static const _cafeSectorCodes = ['SSC', 'SSCT', 'CS', 'SSCM'];
  bool get _isCafeProduction =>
      (widget.selectedSector != null && _cafeSectorCodes.contains(widget.selectedSector)) ||
      (widget.includedSectorCodes != null &&
          widget.includedSectorCodes!.isNotEmpty &&
          widget.includedSectorCodes!.every((c) => _cafeSectorCodes.contains(c)));

  Future<void> _loadProducts() async {
    if (widget.selectedSector == null && !widget.isAdmin &&
        (widget.includedSectorCodes == null || widget.includedSectorCodes!.isEmpty)) {
      return;
    }
    try {
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        _products = [];
        for (var code in widget.includedSectorCodes!) {
          final sectorProducts = await ApiService.getProducts(sector: code);
          for (var product in sectorProducts) {
            product['sector_code'] = code;
            _products.add(product);
          }
        }
      } else if (widget.selectedSector == null && widget.isAdmin) {
        final allSectors = await SectorService().loadSectorsForScreen();
        _products = [];
        for (var sector in allSectors) {
          final sectorProducts = await ApiService.getProducts(sector: sector.code);
          for (var product in sectorProducts) {
            product['sector_code'] = sector.code;
            _products.add(product);
          }
        }
      } else {
        _products = await ApiService.getProducts(sector: widget.selectedSector);
        for (var product in _products) {
          if (product['sector_code'] == null || product['sector_code'].toString().isEmpty) {
            product['sector_code'] = widget.selectedSector;
          }
        }
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
    if (widget.selectedSector == null && !widget.isAdmin &&
        (widget.includedSectorCodes == null || widget.includedSectorCodes!.isEmpty)) {
      return;
    }
    
    if (_products.isEmpty) {
      await _loadProducts();
      if (_products.isEmpty) {
        setState(() {
          _productionData = [];
          _filteredProductionData = [];
        });
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final year = widget.selectedDate!.year;
      final month = widget.selectedDate!.month;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final dateStr = FormatUtils.formatDateForApi(widget.selectedDate!);

      final records = await ApiService.getDailyProduction(
        month: monthStr,
        date: dateStr,
      );
      
      // Filter by sector: all for admin "All Sectors", by includedSectorCodes for consolidated, else single sector
      final List<Map<String, dynamic>> filteredRecords;
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        final codes = widget.includedSectorCodes!.toSet();
        filteredRecords = records.where((r) => codes.contains(r['sector_code']?.toString())).toList();
      } else if (widget.selectedSector == null && widget.isAdmin) {
        filteredRecords = records;
      } else {
        final selectedSector = widget.selectedSector ?? '';
        filteredRecords = records.where((r) => (r['sector_code']?.toString() ?? '') == selectedSector).toList();
      }

      final useCompositeKey = _isConsolidatedView;
      final Map<String, Map<String, dynamic>> existingRecordsMap = {};
      for (var record in filteredRecords) {
        final productName = record['product_name']?.toString() ?? '';
        final sectorCode = record['sector_code']?.toString() ?? '';
        final key = useCompositeKey ? '$productName|$sectorCode' : productName;
        existingRecordsMap[key] = record;
      }

      final List<Map<String, dynamic>> finalData = [];
      for (var product in _products) {
        final productName = product['product_name']?.toString() ?? '';
        final sectorCode = product['sector_code']?.toString() ?? '';
        final key = useCompositeKey ? '$productName|$sectorCode' : productName;
        
        if (existingRecordsMap.containsKey(key)) {
          final existingRecord = existingRecordsMap[key]!;
          if (!existingRecord.containsKey('unit')) {
            existingRecord['unit'] = null;
          }
          finalData.add(existingRecord);
          existingRecordsMap.remove(key);
        } else {
          finalData.add({
            'product_name': productName,
            'sector_code': sectorCode,
            'morning_production': 0,
            'afternoon_production': 0,
            'evening_production': 0,
            'unit': null,
            'unit_afternoon': null,
            'unit_evening': null,
            'unit_stock_in_canteen': null,
            'production_date': dateStr,
            'stock_in_canteen': 0,
          });
        }
      }

      // Sort: rows with any entered value > 0 first (all sectors)
      finalData.sort((a, b) {
        final aSum = _parseIntFromDynamic(a['morning_production']) + _parseIntFromDynamic(a['afternoon_production']) + _parseIntFromDynamic(a['evening_production']) + _parseIntFromDynamic(a['stock_in_canteen']);
        final bSum = _parseIntFromDynamic(b['morning_production']) + _parseIntFromDynamic(b['afternoon_production']) + _parseIntFromDynamic(b['evening_production']) + _parseIntFromDynamic(b['stock_in_canteen']);
        if (aSum > 0 && bSum == 0) return -1;
        if (aSum == 0 && bSum > 0) return 1;
        return 0;
      });
      setState(() {
        _productionData = finalData;
        _filteredProductionData = finalData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  /// Called by parent when Edit is clicked: enter inline edit mode (no popup).
  void showEditDialog() {
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
    _initProductionControllers();
    setState(() => _isEditModeProduction = true);
    widget.onEditModeChanged?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDate == null) {
      return const Center(
        child: Text(
          'Please select date',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (widget.selectedSector == null && !widget.isAdmin &&
        (widget.includedSectorCodes == null || widget.includedSectorCodes!.isEmpty)) {
      return const Center(
        child: Text(
          'Please select a sector from Home page',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final showSectorColumn = _isConsolidatedView;

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
                  : _filteredProductionData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No products found matching "${_searchController.text}"',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _buildProductionTable(showSectorColumn),
        ),
      ],
    );
  }

  double _getProductionTableWidth(bool showSectorColumn) {
    final widths = <double>[];
    if (showSectorColumn) widths.add(_colSector);
    widths.addAll([_colProductName, _colNum, _colNum, _colNum]);
    if (_isCafeProduction) widths.addAll([_colUnit, _colUnit, _colUnit]);
    if (!_isCanteenStore) {
      widths.add(_colNum);
      if (_isCafeProduction) widths.add(_colUnit);
    }
    if (_isCanteenStore) widths.addAll([_colNum, _colUnit]);
    if (!_isCafeProduction) widths.add(_colUnit);
    if (widths.isEmpty) return 0;
    return widths.reduce((a, b) => a + b) + (widths.length - 1) * _colSpacing;
  }

  Widget _buildProductionTable(bool showSectorColumn) {
    final totalWidth = _getProductionTableWidth(showSectorColumn);
    const bold = TextStyle(fontWeight: FontWeight.bold);
    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _headerHeight,
      headerBuilder: (context) {
        final List<Widget> headerChildren = [];
        void addCol(double w, Widget c) {
          if (headerChildren.isNotEmpty) headerChildren.add(const SizedBox(width: _colSpacing));
          headerChildren.add(SizedBox(width: w, child: c));
        }
        if (showSectorColumn) {
          addCol(_colSector, InkWell(
            onTap: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _filteredProductionData.sort((a, b) {
                  final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                  final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                  return _sortAscending ? aName.compareTo(bName) : bName.compareTo(aName);
                });
              });
            },
            child: const Text('Sector', style: bold),
          ));
        }
        addCol(_colProductName, const Text('Product Name', style: bold));
        addCol(_colNum, Text(_isCanteenStore ? 'Overall Production' : 'Morning Production', style: bold));
        if (_isCafeProduction) addCol(_colUnit, const Text('Unit', style: bold));
        addCol(_colNum, Text(_isCanteenStore ? 'Sent to Mainbranch' : 'Afternoon Production', style: bold));
        if (_isCafeProduction) addCol(_colUnit, const Text('Unit', style: bold));
        addCol(_colNum, Text(_isCanteenStore ? 'Sent to Thanthondrimalai' : 'Evening Production', style: bold));
        if (_isCafeProduction) addCol(_colUnit, const Text('Unit', style: bold));
        if (!_isCanteenStore) {
          addCol(_colNum, const Text('Overall Production', style: bold));
          if (_isCafeProduction) addCol(_colUnit, const Text('Unit', style: bold));
        }
        if (_isCanteenStore) {
          addCol(_colNum, const Text('Stock in Canteen', style: bold));
          addCol(_colUnit, const Text('Unit', style: bold));
        }
        if (!_isCafeProduction) addCol(_colUnit, const Text('Unit', style: bold));
        return Row(children: headerChildren);
      },
      rowCount: _filteredProductionData.length,
      rowBuilder: (context, index) {
        final record = _filteredProductionData[index];
        final productName = record['product_name']?.toString() ?? '';
        final sectorCode = record['sector_code']?.toString() ?? widget.selectedSector;
        final controllerKey = _isConsolidatedView ? '$productName|$sectorCode' : productName;
        final morning = _parseIntFromDynamic(record['morning_production'] ?? 0);
        final afternoon = _parseIntFromDynamic(record['afternoon_production'] ?? 0);
        final evening = _parseIntFromDynamic(record['evening_production'] ?? 0);
        final overall = morning + afternoon + evening;
        final stockInCanteen = record['stock_in_canteen'] != null
            ? _parseIntFromDynamic(record['stock_in_canteen'])
            : 0;
        final List<Widget> rowChildren = [];
        void addCell(double w, Widget c) {
          if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: _colSpacing));
          rowChildren.add(SizedBox(width: w, child: c));
        }
        Widget unitDropdown(String? value, ValueChanged<String?> onChanged) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 65, maxWidth: 80),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              ),
              style: const TextStyle(fontSize: 11, color: Colors.black),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: null, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(value: 'gram', child: Text('gram', style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 11, color: Colors.black))),
                DropdownMenuItem(value: 'pieces', child: Text('pieces', style: TextStyle(fontSize: 11, color: Colors.black))),
              ],
              onChanged: onChanged,
            ),
          );
        }
        if (showSectorColumn) addCell(_colSector, Text(_getSectorName(record['sector_code']?.toString())));
        addCell(_colProductName, Text(record['product_name']?.toString() ?? ''));
        addCell(_colNum, _isEditModeProduction && _morningControllers.containsKey(controllerKey)
            ? SizedBox(width: 70, child: TextField(
                controller: _morningControllers[controllerKey],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              ))
            : Text('$morning'));
        if (_isCafeProduction) {
          addCell(_colUnit, _isEditModeProduction
            ? unitDropdown(_productionUnits[controllerKey], (v) => setState(() => _productionUnits[controllerKey] = v))
            : Text(record['unit']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)));
        }
        addCell(_colNum, _isEditModeProduction && _afternoonControllers.containsKey(controllerKey)
            ? SizedBox(width: 70, child: TextField(
                controller: _afternoonControllers[controllerKey],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              ))
            : Text('$afternoon'));
        if (_isCafeProduction) {
          addCell(_colUnit, _isEditModeProduction
            ? unitDropdown(_unitAfternoon[controllerKey], (v) => setState(() => _unitAfternoon[controllerKey] = v))
            : Text(record['unit_afternoon']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)));
        }
        addCell(_colNum, _isEditModeProduction && _eveningControllers.containsKey(controllerKey)
            ? SizedBox(width: 70, child: TextField(
                controller: _eveningControllers[controllerKey],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              ))
            : Text('$evening'));
        if (_isCafeProduction) {
          addCell(_colUnit, _isEditModeProduction
            ? unitDropdown(_unitEvening[controllerKey], (v) => setState(() => _unitEvening[controllerKey] = v))
            : Text(record['unit_evening']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)));
        }
        if (!_isCanteenStore) addCell(_colNum, Text('$overall', style: const TextStyle(fontWeight: FontWeight.bold)));
        if (_isCanteenStore) {
          addCell(_colNum, _isEditModeProduction && _stockInCanteenControllers.containsKey(controllerKey)
              ? SizedBox(width: 70, child: TextField(
                  controller: _stockInCanteenControllers[controllerKey],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                ))
              : Text('$stockInCanteen'));
          addCell(_colUnit, _isEditModeProduction
              ? unitDropdown(_unitStockInCanteen[controllerKey], (v) => setState(() => _unitStockInCanteen[controllerKey] = v))
              : Text(record['unit_stock_in_canteen']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)));
        }
        if (!_isCafeProduction) {
          addCell(_colUnit, _isEditModeProduction
            ? unitDropdown(_productionUnits[controllerKey], (v) => setState(() => _productionUnits[controllerKey] = v))
            : Text(record['unit']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)));
        }
        return Row(children: rowChildren);
      },
    );
  }
}

