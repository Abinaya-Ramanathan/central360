import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/fixed_header_table.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'production_tab_content.dart';
import '../utils/format_utils.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StockManagementScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  /// When set, show consolidated data for main + subsectors with sector name column.
  final List<String>? includedSectorCodes;
  /// Initial tab: 0 = Production, 1 = Daily Stock, 2 = Overall Stock, 3 = Item Price.
  final int? initialTabIndex;

  const StockManagementScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.includedSectorCodes,
    this.initialTabIndex,
  });

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  late TabController _tabController;
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _dailyStock = [];
  List<Map<String, dynamic>> _overallStock = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _isEditModeDaily = false;
  bool _isEditModeOverall = false;
  bool _isProductionEditMode = false;
  bool _isAdmin = false;
  String _searchQuery = '';
  final TextEditingController _productionSearchController = TextEditingController();
  final GlobalKey<State<ProductionTabContent>> _productionTabKey = GlobalKey<State<ProductionTabContent>>();
  bool _sortAscendingDaily = true; // Sort direction for Sector column in Daily Stock
  bool _sortAscendingOverall = true; // Sort direction for Sector column in Overall Stock
  final Map<String, TextEditingController> _dailyQuantityControllers = {};
  final Map<String, TextEditingController> _dailyReasonControllers = {};
  final Map<String, String?> _dailyQuantityUnits = {}; // Store unit for each quantity
  // Sri Suryaas Cafe: 3 quantity columns (canteen, main branch, thanthondrimalai)
  final Map<String, TextEditingController> _dailyQuantityMainBranchControllers = {};
  final Map<String, TextEditingController> _dailyQuantityThanthondrimalaiControllers = {};
  final Map<String, String?> _dailyUnitMainBranch = {};
  final Map<String, String?> _dailyUnitThanthondrimalai = {};
  final Map<String, TextEditingController> _overallNewStockControllers = {};
  final Map<String, String?> _overallNewStockUnits = {}; // Store unit for new stock (deprecated - keeping for compatibility)
  final Map<String, String?> _overallRemainingStockUnits = {}; // Store unit for remaining stock (deprecated)
  
  // New controllers for unit-specific columns
  final Map<String, TextEditingController> _overallRemainingStockGramControllers = {};
  final Map<String, TextEditingController> _overallRemainingStockKgControllers = {};
  final Map<String, TextEditingController> _overallRemainingStockLitreControllers = {};
  final Map<String, TextEditingController> _overallRemainingStockPiecesControllers = {};
  final Map<String, TextEditingController> _overallRemainingStockBoxesControllers = {};
  final Map<String, TextEditingController> _overallNewStockGramControllers = {};
  final Map<String, TextEditingController> _overallNewStockKgControllers = {};
  final Map<String, TextEditingController> _overallNewStockLitreControllers = {};
  final Map<String, TextEditingController> _overallNewStockPiecesControllers = {};
  final Map<String, TextEditingController> _overallNewStockBoxesControllers = {};
  
  // Horizontal ScrollControllers for draggable scrollbars
  final ScrollController _stockHorizontalScrollController = ScrollController();
  final ScrollController _overallStockHorizontalScrollController = ScrollController();

  // Item Price tab
  List<Map<String, dynamic>> _itemPrices = [];
  String _itemPriceSearchQuery = '';
  bool _isEditModeItemPrice = false;
  final Map<int, TextEditingController> _itemPriceQuantityControllers = {};
  final Map<int, String?> _itemPriceUnitValues = {}; // Unit dropdown selection (allowed: gram, kg, Litre, pieces, Boxes, null)
  final Map<int, TextEditingController> _itemPriceNewPriceControllers = {};
  final Map<int, TextEditingController> _itemPriceOldPriceControllers = {};
  final ScrollController _itemPriceHorizontalScrollController = ScrollController();

  static const List<String> _itemPriceUnitOptions = ['gram', 'kg', 'Litre', 'pieces', 'Boxes'];
  static String? _normalizeItemPriceUnit(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final s = v.trim();
    if (s == 'piece') return 'pieces';
    return _itemPriceUnitOptions.contains(s) ? s : null;
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex ?? 0;
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex.clamp(0, 3));
    _selectedDate = DateTime.now();
    final usernameLower = widget.username.toLowerCase();
    _isAdmin = usernameLower == 'admin' || usernameLower == 'abinaya' || usernameLower == 'srisurya';
    _loadSectors();
    _loadStockItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productionSearchController.dispose();
    for (var controller in _dailyQuantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _dailyReasonControllers.values) {
      controller.dispose();
    }
    for (var controller in _dailyQuantityMainBranchControllers.values) {
      controller.dispose();
    }
    for (var controller in _dailyQuantityThanthondrimalaiControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallRemainingStockGramControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallRemainingStockKgControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallRemainingStockLitreControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockGramControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockKgControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockLitreControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallRemainingStockPiecesControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallRemainingStockBoxesControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockPiecesControllers.values) {
      controller.dispose();
    }
    for (var controller in _overallNewStockBoxesControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemPriceQuantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemPriceNewPriceControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemPriceOldPriceControllers.values) {
      controller.dispose();
    }
    _itemPriceHorizontalScrollController.dispose();
    _stockHorizontalScrollController.dispose();
    _overallStockHorizontalScrollController.dispose();
    super.dispose();
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

  Future<void> _loadStockItems() async {
    try {
      final codes = widget.includedSectorCodes;
      final sectorParam = (codes == null || codes.isEmpty) ? widget.selectedSector : null;
      final items = await ApiService.getStockItems(sector: sectorParam);
      if (mounted) {
        final filtered = (codes != null && codes.isNotEmpty)
            ? items.where((i) => codes.contains(i['sector_code']?.toString())).toList()
            : items;
        setState(() {
          _stockItems = filtered;
        });
        _loadDailyStock();
        _loadOverallStock();
        _loadItemPrices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stock items: $e')),
        );
      }
    }
  }

  Future<void> _loadDailyStock() async {
    if (_selectedDate == null) return;
    
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final sectorParam = (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)
          ? null
          : widget.selectedSector;
      var stock = await ApiService.getDailyStock(
        month: _selectedDate!.month,
        date: dateStr,
        sector: sectorParam,
      );
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        stock = stock.where((s) => widget.includedSectorCodes!.contains(s['sector_code']?.toString())).toList();
      }
      if (mounted) {
        for (var controller in _dailyQuantityControllers.values) {
          controller.dispose();
        }
        for (var controller in _dailyReasonControllers.values) {
          controller.dispose();
        }
        for (var controller in _dailyQuantityMainBranchControllers.values) {
          controller.dispose();
        }
        for (var controller in _dailyQuantityThanthondrimalaiControllers.values) {
          controller.dispose();
        }
        _dailyQuantityControllers.clear();
        _dailyReasonControllers.clear();
        _dailyQuantityMainBranchControllers.clear();
        _dailyQuantityThanthondrimalaiControllers.clear();
        
        final existingItemIds = stock.map((s) => s['item_id'] as int).toSet();
        final missingItems = _stockItems.where((item) => !existingItemIds.contains(item['id'] as int)).toList();
        
        final allStock = List<Map<String, dynamic>>.from(stock);
        for (var item in missingItems) {
          final sectorCode = item['sector_code'] as String;
          final sectorName = _getSectorName(sectorCode);
          allStock.add({
            'id': -1,
            'item_id': item['id'] as int,
            'item_name': item['item_name'] as String,
            'sector_code': sectorCode,
            'sector_name': sectorName,
            'quantity_taken': '0',
            'reason': '',
            'quantity_taken_main_branch': '0',
            'quantity_taken_thanthondrimalai': '0',
          });
        }
        
        setState(() {
          _dailyStock = allStock;
          for (var item in _dailyStock) {
            final id = item['id'] as int;
            final itemId = item['item_id'] as int;
            final key = '${itemId}_$id';
            _dailyQuantityControllers[key] = TextEditingController(
              text: item['quantity_taken']?.toString() ?? '',
            );
            _dailyReasonControllers[key] = TextEditingController(
              text: item['reason']?.toString() ?? '',
            );
            _dailyQuantityUnits[key] = item['unit']?.toString();
            if (_isCafeDailyStock) {
              _dailyQuantityMainBranchControllers[key] = TextEditingController(
                text: item['quantity_taken_main_branch']?.toString() ?? '0',
              );
              _dailyQuantityThanthondrimalaiControllers[key] = TextEditingController(
                text: item['quantity_taken_thanthondrimalai']?.toString() ?? '0',
              );
              _dailyUnitMainBranch[key] = item['unit_main_branch']?.toString();
              _dailyUnitThanthondrimalai[key] = item['unit_thanthondrimalai']?.toString();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading daily stock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOverallStock() async {
    setState(() => _isLoading = true);
    try {
      final sectorParam = (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)
          ? null
          : widget.selectedSector;
      var stock = await ApiService.getOverallStock(
        sector: sectorParam,
      );
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        stock = stock.where((s) => widget.includedSectorCodes!.contains(s['sector_code']?.toString())).toList();
      }
      if (mounted) {
        // Clear all controllers
        for (var controller in _overallNewStockControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallRemainingStockGramControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallRemainingStockKgControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallRemainingStockLitreControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallNewStockGramControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallNewStockKgControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallNewStockLitreControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallRemainingStockPiecesControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallRemainingStockBoxesControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallNewStockPiecesControllers.values) {
          controller.dispose();
        }
        for (var controller in _overallNewStockBoxesControllers.values) {
          controller.dispose();
        }
        
        _overallNewStockControllers.clear();
        _overallNewStockUnits.clear();
        _overallRemainingStockUnits.clear();
        _overallRemainingStockGramControllers.clear();
        _overallRemainingStockKgControllers.clear();
        _overallRemainingStockLitreControllers.clear();
        _overallRemainingStockPiecesControllers.clear();
        _overallRemainingStockBoxesControllers.clear();
        _overallNewStockGramControllers.clear();
        _overallNewStockKgControllers.clear();
        _overallNewStockLitreControllers.clear();
        _overallNewStockPiecesControllers.clear();
        _overallNewStockBoxesControllers.clear();
        
        final existingItemIds = stock.map((s) => s['item_id'] as int).toSet();
        final missingItems = _stockItems.where((item) => !existingItemIds.contains(item['id'] as int)).toList();
        
        final allStock = List<Map<String, dynamic>>.from(stock);
        for (var item in missingItems) {
          final sectorCode = item['sector_code'] as String;
          final sectorName = _getSectorName(sectorCode);
          allStock.add({
            'id': -1,
            'item_id': item['id'] as int,
            'item_name': item['item_name'] as String,
            'sector_code': sectorCode,
            'sector_name': sectorName,
            'remaining_stock': '0',
            'new_stock': '0',
            'remaining_stock_gram': '0',
            'remaining_stock_kg': '0',
            'remaining_stock_litre': '0',
            'remaining_stock_pieces': '0',
            'remaining_stock_boxes': '0',
            'new_stock_gram': '0',
            'new_stock_kg': '0',
            'new_stock_litre': '0',
            'new_stock_pieces': '0',
            'new_stock_boxes': '0',
          });
        }
        
        setState(() {
          _overallStock = allStock;
          for (var item in _overallStock) {
            final id = item['id'] as int;
            final itemId = item['item_id'] as int;
            // Use item_id as key to avoid conflicts with temporary -1 ids
            final key = '${itemId}_$id';
            _overallNewStockControllers[key] = TextEditingController(
              text: item['new_stock']?.toString() ?? '',
            );
            _overallNewStockUnits[key] = item['unit']?.toString();
            _overallRemainingStockUnits[key] = item['unit']?.toString(); // Same unit for both
            
            // Initialize unit-specific controllers
            _overallRemainingStockGramControllers[key] = TextEditingController(
              text: item['remaining_stock_gram']?.toString() ?? '',
            );
            _overallRemainingStockKgControllers[key] = TextEditingController(
              text: item['remaining_stock_kg']?.toString() ?? '',
            );
            _overallRemainingStockLitreControllers[key] = TextEditingController(
              text: item['remaining_stock_litre']?.toString() ?? '',
            );
            _overallNewStockGramControllers[key] = TextEditingController(
              text: item['new_stock_gram']?.toString() ?? '',
            );
            _overallNewStockKgControllers[key] = TextEditingController(
              text: item['new_stock_kg']?.toString() ?? '',
            );
            _overallNewStockLitreControllers[key] = TextEditingController(
              text: item['new_stock_litre']?.toString() ?? '',
            );
            _overallRemainingStockPiecesControllers[key] = TextEditingController(
              text: item['remaining_stock_pieces']?.toString() ?? '',
            );
            _overallRemainingStockBoxesControllers[key] = TextEditingController(
              text: item['remaining_stock_boxes']?.toString() ?? '',
            );
            _overallNewStockPiecesControllers[key] = TextEditingController(
              text: item['new_stock_pieces']?.toString() ?? '',
            );
            _overallNewStockBoxesControllers[key] = TextEditingController(
              text: item['new_stock_boxes']?.toString() ?? '',
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading overall stock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadItemPrices() async {
    try {
      final sectorParam = (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)
          ? null
          : widget.selectedSector;
      var list = await ApiService.getItemPrices(sector: sectorParam);
      if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty) {
        list = list.where((r) => widget.includedSectorCodes!.contains(r['sector_code']?.toString())).toList();
      }
      if (mounted) {
        for (var c in _itemPriceQuantityControllers.values) {
          c.dispose();
        }
        for (var c in _itemPriceNewPriceControllers.values) {
          c.dispose();
        }
        for (var c in _itemPriceOldPriceControllers.values) {
          c.dispose();
        }
        _itemPriceQuantityControllers.clear();
        _itemPriceUnitValues.clear();
        _itemPriceNewPriceControllers.clear();
        _itemPriceOldPriceControllers.clear();
        setState(() {
          _itemPrices = list;
          for (var r in _itemPrices) {
            final id = r['item_name_id'] as int? ?? (r['id'] as int? ?? 0);
            if (id <= 0) continue;
            _itemPriceQuantityControllers[id] = TextEditingController(text: r['quantity']?.toString() ?? '');
            _itemPriceUnitValues[id] = _normalizeItemPriceUnit(r['unit']?.toString());
            _itemPriceNewPriceControllers[id] = TextEditingController(text: r['new_price']?.toString() ?? '');
            _itemPriceOldPriceControllers[id] = TextEditingController(text: r['old_price']?.toString() ?? '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading item prices: $e')));
      }
    }
  }

  Future<void> _saveItemPrices() async {
    setState(() => _isLoading = true);
    try {
      for (var r in _itemPrices) {
        final itemNameId = r['item_name_id'] as int? ?? (r['id'] as int?);
        if (itemNameId == null) continue;
        final q = _itemPriceQuantityControllers[itemNameId]?.text;
        final u = _itemPriceUnitValues[itemNameId];
        final newP = _itemPriceNewPriceControllers[itemNameId]?.text;
        final oldP = _itemPriceOldPriceControllers[itemNameId]?.text;
        double? newPriceVal;
        double? oldPriceVal;
        if (newP != null && newP.isNotEmpty) newPriceVal = double.tryParse(newP);
        if (oldP != null && oldP.isNotEmpty) oldPriceVal = double.tryParse(oldP);
        await ApiService.updateItemPrice(
          itemNameId: itemNameId,
          id: r['id'] is int ? r['id'] as int : null,
          quantity: q,
          unit: u,
          newPrice: newPriceVal,
          oldPrice: oldPriceVal,
        );
      }
      if (mounted) {
        setState(() => _isEditModeItemPrice = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item prices saved')));
        _loadItemPrices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      // Only load daily stock if we're on the Daily Stock tab (index 1)
      if (_tabController.index == 1) {
      _loadDailyStock();
    }
    }
  }


  Future<void> _saveDailyStock() async {
    setState(() => _isLoading = true);
    try {
      final updates = <Map<String, dynamic>>[];
      for (var item in _dailyStock) {
        final id = item['id'] as int;
        final itemId = item['item_id'] as int;
        final key = '${itemId}_$id';
        final quantityController = _dailyQuantityControllers[key];
        final reasonController = _dailyReasonControllers[key];
        
        if (quantityController != null && reasonController != null) {
          final update = <String, dynamic>{
            'id': id == -1 ? null : id,
            'item_id': itemId,
            'quantity_taken': quantityController.text.trim(),
            'unit': _dailyQuantityUnits[key],
            'reason': reasonController.text.trim(),
          };
          if (_isCafeDailyStock) {
            update['quantity_taken_main_branch'] = _dailyQuantityMainBranchControllers[key]?.text.trim() ?? '0';
            update['unit_main_branch'] = _dailyUnitMainBranch[key];
            update['quantity_taken_thanthondrimalai'] = _dailyQuantityThanthondrimalaiControllers[key]?.text.trim() ?? '0';
            update['unit_thanthondrimalai'] = _dailyUnitThanthondrimalai[key];
          }
          updates.add(update);
        }
      }
      
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      await ApiService.updateDailyStock(updates, date: dateStr);
      if (mounted) {
        setState(() {
          _isEditModeDaily = false;
        });
        _loadDailyStock();
        _loadOverallStock(); // Reload to sync remaining stock
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily stock updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving daily stock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveOverallStock() async {
    setState(() => _isLoading = true);
    try {
      final updates = <Map<String, dynamic>>[];
      for (var item in _overallStock) {
        final id = item['id'] as int;
        final itemId = item['item_id'] as int;
        final key = '${itemId}_$id';
        
        // Get only new stock values (remaining stock is auto-calculated)
        final newGramController = _overallNewStockGramControllers[key];
        final newKgController = _overallNewStockKgControllers[key];
        final newLitreController = _overallNewStockLitreControllers[key];
        final newPiecesController = _overallNewStockPiecesControllers[key];
        final newBoxesController = _overallNewStockBoxesControllers[key];
        
        // Get values (empty string if controller doesn't exist or is empty)
        final newGramValue = newGramController?.text.trim() ?? '';
        final newKgValue = newKgController?.text.trim() ?? '';
        final newLitreValue = newLitreController?.text.trim() ?? '';
        final newPiecesValue = newPiecesController?.text.trim() ?? '';
        final newBoxesValue = newBoxesController?.text.trim() ?? '';
        
        // Only add update if at least one column has a non-empty value
        // You don't need to fill all columns - just fill the ones you need!
        if (newGramValue.isNotEmpty || newKgValue.isNotEmpty || newLitreValue.isNotEmpty || newPiecesValue.isNotEmpty || newBoxesValue.isNotEmpty) {
          updates.add({
            'id': id == -1 ? null : id,
            'item_id': itemId,
            'remaining_stock_gram': '', // Will be auto-calculated
            'remaining_stock_kg': '', // Will be auto-calculated
            'remaining_stock_litre': '', // Will be auto-calculated
            'remaining_stock_pieces': '', // Will be auto-calculated
            'remaining_stock_boxes': '', // Will be auto-calculated
            'new_stock_gram': newGramValue,
            'new_stock_kg': newKgValue,
            'new_stock_litre': newLitreValue,
            'new_stock_pieces': newPiecesValue,
            'new_stock_boxes': newBoxesValue,
          });
        }
      }
      
      await ApiService.updateOverallStock(updates);
      if (mounted) {
        setState(() {
          _isEditModeOverall = false;
        });
        // Add a delay to ensure database transaction is committed
        await Future.delayed(const Duration(milliseconds: 500));
        // Clear existing stock data to force reload
        setState(() {
          _overallStock = [];
        });
        await _loadOverallStock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overall stock updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving overall stock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterStock(List<Map<String, dynamic>> stock) {
    if (_searchQuery.isEmpty) return List.from(stock);
    final query = _searchQuery.toLowerCase();
    return stock.where((item) {
      final itemName = item['item_name']?.toString().toLowerCase() ?? '';
      final vehicleType = item['vehicle_type']?.toString().toLowerCase() ?? '';
      final partNumber = item['part_number']?.toString().toLowerCase() ?? '';
      return itemName.contains(query) || vehicleType.contains(query) || partNumber.contains(query);
    }).toList();
  }

  static double _parseQty(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  bool _dailyStockRowHasValue(Map<String, dynamic> r) {
    final q = _parseQty(r['quantity_taken']);
    if (q > 0) return true;
    if (_isCafeDailyStock) {
      if (_parseQty(r['quantity_taken_main_branch']) > 0) return true;
      if (_parseQty(r['quantity_taken_thanthondrimalai']) > 0) return true;
    }
    return false;
  }

  bool _overallStockRowHasValue(Map<String, dynamic> r) {
    if (_parseQty(r['remaining_stock_gram']) > 0) return true;
    if (_parseQty(r['remaining_stock_kg']) > 0) return true;
    if (_parseQty(r['remaining_stock_litre']) > 0) return true;
    if (_parseQty(r['remaining_stock_pieces']) > 0) return true;
    if (_parseQty(r['remaining_stock_boxes']) > 0) return true;
    if (_parseQty(r['new_stock_gram']) > 0) return true;
    if (_parseQty(r['new_stock_kg']) > 0) return true;
    if (_parseQty(r['new_stock_litre']) > 0) return true;
    if (_parseQty(r['new_stock_pieces']) > 0) return true;
    if (_parseQty(r['new_stock_boxes']) > 0) return true;
    return false;
  }

  /// Shows Set/Remove Minimum Stock menu. On Windows: right-click. On Android/touch: long-press the row (Sector or Item Name cell).
  Future<void> _showOverallStockContextMenu(BuildContext context, Offset position, Map<String, dynamic> record) async {
    final id = record['id'] as int?;
    if (id == null) return;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem<String>(value: 'set', child: Text('Set Minimum Stock')),
        const PopupMenuItem<String>(value: 'remove', child: Text('Remove Minimum Stock')),
      ],
    );
    if (result == null || !mounted) return;
    try {
      await ApiService.setOverallStockMinimum(id, result == 'set');
      if (mounted) _loadOverallStock();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _generateStatement() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StatementDialog(selectedSector: widget.selectedSector),
    );

    if (result != null && mounted) {
      try {
        setState(() => _isLoading = true);
        final statement = await ApiService.generateStockStatement(
          fromDate: result['from_date'] as String,
          toDate: result['to_date'] as String,
          sector: result['sector'] as String?,
        );
        
        if (mounted) {
          await _showStatementPDF(statement, result['from_date'] as String, result['to_date'] as String);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating statement: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showStatementPDF(List<Map<String, dynamic>> data, String fromDate, String toDate) async {
    final pdf = pw.Document();
    final sectorName = widget.selectedSector == null 
        ? 'All Sectors' 
        : _getSectorName(widget.selectedSector);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Stock Statement', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date Range: $fromDate to $toDate'),
              pw.SizedBox(height: 5),
              pw.Text('Sector: $sectorName'),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Sector', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Stocks Used', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...data.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(item['sector_name']?.toString() ?? item['sector_code']?.toString() ?? ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(item['item_name']?.toString() ?? ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(item['stocks_used']?.toString() ?? '0'),
                      ),
                    ],
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  bool _shouldShowVehicleFieldsForItem(String? sectorCode) {
    return sectorCode == 'SSEW';
  }

  static const _cafeSectorCodes = ['SSC', 'SSCT', 'CS', 'SSCM'];
  bool get _isCafeDailyStock =>
      (widget.selectedSector != null && _cafeSectorCodes.contains(widget.selectedSector)) ||
      (widget.includedSectorCodes != null &&
          widget.includedSectorCodes!.isNotEmpty &&
          widget.includedSectorCodes!.every((c) => _cafeSectorCodes.contains(c)));

  // Daily Stock fixed header table column widths
  static const double _dailyColSector = 100;
  static const double _dailyColSiNo = 50;
  static const double _dailyColItemName = 150;
  static const double _dailyColVehicleType = 100;
  static const double _dailyColPartNumber = 100;
  static const double _dailyColQty = 90;
  static const double _dailyColUnit = 80;
  static const double _dailyColReason = 180;
  static const double _dailySpacing = 12;
  static const double _dailyHeaderHeight = 56;

  Widget _buildDailyStockFixedTable(List<Map<String, dynamic>> data, bool showSectorColumn, bool showVehicleColumns) {
    final baseWidth = (showSectorColumn ? _dailyColSector + _dailySpacing : 0) +
        _dailyColSiNo + _dailySpacing + _dailyColItemName + _dailySpacing +
        (showVehicleColumns ? _dailyColVehicleType + _dailySpacing + _dailyColPartNumber + _dailySpacing : 0) +
        _dailyColQty + _dailySpacing + _dailyColUnit + _dailySpacing +
        (_isCafeDailyStock ? (_dailyColQty + _dailySpacing + _dailyColUnit + _dailySpacing + _dailyColQty + _dailySpacing + _dailyColUnit + _dailySpacing) : 0) +
        _dailyColReason;
    final totalWidth = baseWidth;
    void sectorSort() {
      setState(() {
        _sortAscendingDaily = !_sortAscendingDaily;
        data.sort((a, b) {
          final aName = (a['sector_name']?.toString() ?? a['sector_code']?.toString() ?? '').toLowerCase();
          final bName = (b['sector_name']?.toString() ?? b['sector_code']?.toString() ?? '').toLowerCase();
          return _sortAscendingDaily ? aName.compareTo(bName) : bName.compareTo(aName);
        });
      });
    }
    final headerCells = <Widget>[
      if (showSectorColumn) ...[
        InkWell(onTap: sectorSort, child: const SizedBox(width: _dailyColSector, child: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(width: _dailySpacing),
      ],
      const SizedBox(width: _dailyColSiNo, child: Text('SI.NO', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(width: _dailySpacing),
      const SizedBox(width: _dailyColItemName, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(width: _dailySpacing),
      if (showVehicleColumns) ...[
        const SizedBox(width: _dailyColVehicleType, child: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
        const SizedBox(width: _dailyColPartNumber, child: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
      ],
      SizedBox(width: _dailyColQty, child: Text(_isCafeDailyStock ? 'Canteen' : 'Quantity Taken', style: const TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(width: _dailySpacing),
      const SizedBox(width: _dailyColUnit, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(width: _dailySpacing),
      if (_isCafeDailyStock) ...[
        const SizedBox(width: _dailyColQty, child: Text('Main branch', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
        const SizedBox(width: _dailyColUnit, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
        const SizedBox(width: _dailyColQty, child: Text('Thanthondrimalai branch', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
        const SizedBox(width: _dailyColUnit, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: _dailySpacing),
      ],
      const SizedBox(width: _dailyColReason, child: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
    return FixedHeaderTable(
      horizontalScrollController: _stockHorizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _dailyHeaderHeight,
      headerBuilder: (context) => Row(children: headerCells),
      rowCount: data.length,
      rowBuilder: (context, index) {
        final entry = data.asMap().entries.elementAt(index);
        final siNo = entry.key + 1;
        final record = entry.value;
        final id = record['id'] as int;
        final itemId = record['item_id'] as int;
        final key = '${itemId}_$id';
        final quantityController = _dailyQuantityControllers[key];
        final reasonController = _dailyReasonControllers[key];
        final itemSectorCode = record['sector_code']?.toString();
        final showVehicleForThisItem = _shouldShowVehicleFieldsForItem(itemSectorCode);
        final rowCells = <Widget>[
          if (showSectorColumn) ...[
            SizedBox(width: _dailyColSector, child: Text(record['sector_name']?.toString() ?? record['sector_code']?.toString() ?? '')),
            const SizedBox(width: _dailySpacing),
          ],
          SizedBox(width: _dailyColSiNo, child: Text('$siNo')),
          const SizedBox(width: _dailySpacing),
          SizedBox(width: _dailyColItemName, child: Text(record['item_name']?.toString() ?? 'N/A')),
          const SizedBox(width: _dailySpacing),
          if (showVehicleColumns) ...[
            SizedBox(width: _dailyColVehicleType, child: Text(showVehicleForThisItem ? (record['vehicle_type']?.toString() ?? '') : '')),
            const SizedBox(width: _dailySpacing),
            SizedBox(width: _dailyColPartNumber, child: Text(showVehicleForThisItem ? (record['part_number']?.toString() ?? '') : '')),
            const SizedBox(width: _dailySpacing),
          ],
          SizedBox(
            width: _dailyColQty,
            child: _isEditModeDaily
                ? SizedBox(
                    width: 90,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    ),
                  )
                : Text(record['quantity_taken']?.toString() ?? '0'),
          ),
          const SizedBox(width: _dailySpacing),
          SizedBox(
            width: _dailyColUnit,
            child: _isEditModeDaily
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 65, maxWidth: 80),
                    child: DropdownButtonFormField<String>(
                      initialValue: _dailyQuantityUnits[key],
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4)),
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.black))),
                        DropdownMenuItem(value: 'gram', child: Text('gram', style: TextStyle(fontSize: 11, color: Colors.black))),
                        DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 11, color: Colors.black))),
                        DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 11, color: Colors.black))),
                        DropdownMenuItem(value: 'pieces', child: Text('pieces', style: TextStyle(fontSize: 11, color: Colors.black))),
                        DropdownMenuItem(value: 'Boxes', child: Text('Boxes', style: TextStyle(fontSize: 11, color: Colors.black))),
                      ],
                      onChanged: (value) => setState(() => _dailyQuantityUnits[key] = value),
                    ),
                  )
                : Text(record['unit']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)),
          ),
          const SizedBox(width: _dailySpacing),
        ];
        if (_isCafeDailyStock) {
          rowCells.addAll([
            SizedBox(
              width: _dailyColQty,
              child: _isEditModeDaily
                  ? SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _dailyQuantityMainBranchControllers[key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      ),
                    )
                  : Text(record['quantity_taken_main_branch']?.toString() ?? '0'),
            ),
            const SizedBox(width: _dailySpacing),
            SizedBox(
              width: _dailyColUnit,
              child: _isEditModeDaily
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 65, maxWidth: 80),
                      child: DropdownButtonFormField<String>(
                        initialValue: _dailyUnitMainBranch[key],
                        isDense: true,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4)),
                        style: const TextStyle(fontSize: 11, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'gram', child: Text('gram', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'pieces', child: Text('pieces', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'Boxes', child: Text('Boxes', style: TextStyle(fontSize: 11, color: Colors.black))),
                        ],
                        onChanged: (value) => setState(() => _dailyUnitMainBranch[key] = value),
                      ),
                  )
                  : Text(record['unit_main_branch']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)),
            ),
            const SizedBox(width: _dailySpacing),
            SizedBox(
              width: _dailyColQty,
              child: _isEditModeDaily
                  ? SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _dailyQuantityThanthondrimalaiControllers[key],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      ),
                    )
                  : Text(record['quantity_taken_thanthondrimalai']?.toString() ?? '0'),
            ),
            const SizedBox(width: _dailySpacing),
            SizedBox(
              width: _dailyColUnit,
              child: _isEditModeDaily
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 65, maxWidth: 80),
                      child: DropdownButtonFormField<String>(
                        initialValue: _dailyUnitThanthondrimalai[key],
                        isDense: true,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4)),
                        style: const TextStyle(fontSize: 11, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('-', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'gram', child: Text('gram', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'pieces', child: Text('pieces', style: TextStyle(fontSize: 11, color: Colors.black))),
                          DropdownMenuItem(value: 'Boxes', child: Text('Boxes', style: TextStyle(fontSize: 11, color: Colors.black))),
                        ],
                        onChanged: (value) => setState(() => _dailyUnitThanthondrimalai[key] = value),
                      ),
                  )
                  : Text(record['unit_thanthondrimalai']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)),
            ),
            const SizedBox(width: _dailySpacing),
          ]);
        }
        rowCells.add(SizedBox(
          width: _dailyColReason,
          child: _isEditModeDaily
              ? SizedBox(
                  width: 180,
                  child: TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  ),
                )
              : Text(record['reason']?.toString() ?? ''),
        ));
        return Row(children: rowCells);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDailyStock = _filterStock(_dailyStock);
    final filteredOverallStock = _filterStock(_overallStock);
    // Rows with entered value > 0 display first (all sectors)
    filteredDailyStock.sort((a, b) {
      final aHas = _dailyStockRowHasValue(a);
      final bHas = _dailyStockRowHasValue(b);
      if (aHas && !bHas) return -1;
      if (!aHas && bHas) return 1;
      return 0;
    });
    filteredOverallStock.sort((a, b) {
      final aHas = _overallStockRowHasValue(a);
      final bHas = _overallStockRowHasValue(b);
      if (aHas && !bHas) return -1;
      if (!aHas && bHas) return 1;
      return 0;
    });
    // Show sector column when consolidated (includedSectorCodes) or All Sectors
    final showSectorColumn = widget.selectedSector == null || widget.includedSectorCodes != null;
    if (showSectorColumn) {
      filteredOverallStock.sort((a, b) {
        final aName = (a['sector_name']?.toString() ?? a['sector_code']?.toString() ?? '').toLowerCase();
        final bName = (b['sector_name']?.toString() ?? b['sector_code']?.toString() ?? '').toLowerCase();
        return _sortAscendingOverall ? aName.compareTo(bName) : bName.compareTo(aName);
      });
    }
    // Show vehicle columns for SSEW sector or for admin when All Sectors is selected or when consolidated view includes SSEW
    final showVehicleColumns = (widget.selectedSector == 'SSEW') ||
                               (widget.selectedSector == null && _isAdmin) ||
                               (widget.includedSectorCodes != null && widget.includedSectorCodes!.contains('SSEW'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (widget.includedSectorCodes != null && widget.includedSectorCodes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${_getSectorName(widget.selectedSector)} (consolidated)',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            )
          else if (widget.selectedSector != null)
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
                  Text('All Sectors', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 4),
                Text(widget.username, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                    initialSectorCodes: AuthService.initialSectorCodes,
                    isAdmin: AuthService.isAdmin,
                    isMainAdmin: AuthService.isMainAdmin,
                  ),
                ),
              );
            },
          ),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Production'),
            Tab(text: 'Daily Stock'),
            Tab(text: 'Overall Stock'),
            Tab(text: 'Item Price'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Production Tab
          Column(
            children: [
              // Search, Date, and Edit Button in same row
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _productionSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search by product name...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
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
                                ? FormatUtils.formatDateForApi(_selectedDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isProductionEditMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              final state = _productionTabKey.currentState;
                              if (state != null) (state as dynamic).cancelEdit();
                              setState(() => _isProductionEditMode = false);
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              final state = _productionTabKey.currentState;
                              if (state != null) await (state as dynamic).saveProduction();
                              // Child calls onEditModeChanged(false) when done
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () {
                              final state = _productionTabKey.currentState;
                              if (state != null) {
                                (state as dynamic).showEditDialog();
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _generateStatement,
                            icon: const Icon(Icons.description),
                            label: const Text('Statement', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Production Tab Content
              Expanded(
                child: ProductionTabContent(
                  key: _productionTabKey,
                  selectedSector: widget.selectedSector,
                  includedSectorCodes: widget.includedSectorCodes,
                  selectedDate: _selectedDate,
                  isAdmin: _isAdmin,
                  searchController: _productionSearchController,
                  onEditModeChanged: (isEditMode) {
                    setState(() => _isProductionEditMode = isEditMode);
                  },
                ),
              ),
            ],
          ),
          // Daily Stock Tab
          Column(
            children: [
              // Search, Date, and Edit Button in same row
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
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
                                ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isEditModeDaily)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeDaily = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveDailyStock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeDaily = true;
                              });
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _generateStatement,
                            icon: const Icon(Icons.description),
                            label: const Text('Statement'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Daily Stock Table
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredDailyStock.isEmpty
                        ? const Center(child: Text('No daily stock records found'))
                        : _buildDailyStockFixedTable(filteredDailyStock, showSectorColumn, showVehicleColumns),
              ),
            ],
          ),
          // Overall Stock Tab
          Column(
            children: [
              // Search, Edit, and Statement Buttons in same row
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isEditModeOverall)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeOverall = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveOverallStock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeOverall = true;
                              });
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _generateStatement,
                            icon: const Icon(Icons.description),
                            label: const Text('Statement'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Overall Stock Table (sticky header: header row fixed, only data rows scroll)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredOverallStock.isEmpty
                        ? const Center(child: Text('No overall stock records found'))
                        : _buildOverallStockTableWithStickyHeader(filteredOverallStock, showSectorColumn, showVehicleColumns),
              ),
            ],
          ),
          // Item Price Tab
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search item name...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() => _itemPriceSearchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isEditModeItemPrice)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() => _isEditModeItemPrice = false);
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveItemPrices,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () {
                          setState(() => _isEditModeItemPrice = true);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _buildItemPriceTable(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Overall Stock sticky table column widths
  static const double _overallColSector = 100;
  static const double _overallColItemName = 130;
  static const double _overallColVehicle = 85;
  static const double _overallColPart = 85;
  static const double _overallColUnit = 88;
  static const double _overallHeaderHeight = 72;
  static const double _overallRowHeight = 48;

  static const double _itemPriceColSector = 100;
  static const double _itemPriceColName = 160;
  static const double _itemPriceColQty = 90;
  static const double _itemPriceColUnit = 70;
  static const double _itemPriceColNew = 100;
  static const double _itemPriceColOld = 100;
  static const double _itemPriceHeaderHeight = 56;
  static const double _itemPriceRowHeight = 52;

  Widget _buildOverallStockTableWithStickyHeader(
    List<Map<String, dynamic>> filteredOverallStock,
    bool showSectorColumn,
    bool showVehicleColumns,
  ) {
    double totalWidth = _overallColItemName + _overallColUnit * 10;
    if (showSectorColumn) totalWidth += _overallColSector;
    if (showVehicleColumns) totalWidth += _overallColVehicle + _overallColPart;

    return FixedHeaderTable(
      horizontalScrollController: _overallStockHorizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _overallHeaderHeight,
      headerBuilder: (context) {
        final cells = <Widget>[
          if (showSectorColumn)
            SizedBox(
              width: _overallColSector,
              child: InkWell(
                onTap: () {
                  setState(() => _sortAscendingOverall = !_sortAscendingOverall);
                },
                child: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: _overallColItemName, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
          if (showVehicleColumns) ...[
            const SizedBox(width: _overallColVehicle, child: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: _overallColPart, child: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          _headerCell('Remaining Stock\nin gram', Colors.blue, _overallColUnit),
          _headerCell('Remaining Stock\nin kg', Colors.blue, _overallColUnit),
          _headerCell('Remaining Stock\nin litre', Colors.blue, _overallColUnit),
          _headerCell('Remaining Stock\nin pieces', Colors.blue, _overallColUnit),
          _headerCell('Remaining Stock\nin Boxes', Colors.blue, _overallColUnit),
          _headerCell('New Stock\nin gram', Colors.green, _overallColUnit),
          _headerCell('New Stock\nin kg', Colors.green, _overallColUnit),
          _headerCell('New Stock\nin litre', Colors.green, _overallColUnit),
          _headerCell('New Stock\nin pieces', Colors.green, _overallColUnit),
          _headerCell('New Stock\nin Boxes', Colors.green, _overallColUnit),
        ];
        return SizedBox(
          height: _overallHeaderHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: cells,
          ),
        );
      },
      rowCount: filteredOverallStock.length,
      rowBuilder: (context, index) {
        final record = filteredOverallStock[index];
        final id = record['id'] as int;
        final itemId = record['item_id'] as int;
        final key = '${itemId}_$id';
        final isMinimumStock = record['is_minimum_stock'] == true;
        final rowColor = isMinimumStock ? Colors.red.shade100 : Colors.blue.shade50;
        final itemSectorCode = record['sector_code']?.toString();
        final showVehicleForThisItem = _shouldShowVehicleFieldsForItem(itemSectorCode);

        final cells = <Widget>[
          if (showSectorColumn)
            SizedBox(
              width: _overallColSector,
              child: GestureDetector(
                onSecondaryTapDown: (d) => _showOverallStockContextMenu(context, d.globalPosition, record),
                onLongPressStart: (d) => _showOverallStockContextMenu(context, d.globalPosition, record),
                child: Container(
                  color: rowColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(record['sector_name']?.toString() ?? record['sector_code']?.toString() ?? ''),
                ),
              ),
            ),
          SizedBox(
            width: _overallColItemName,
            child: GestureDetector(
              onSecondaryTapDown: (d) => _showOverallStockContextMenu(context, d.globalPosition, record),
              onLongPressStart: (d) => _showOverallStockContextMenu(context, d.globalPosition, record),
              child: Container(
                color: rowColor,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Text(record['item_name']?.toString() ?? 'N/A'),
              ),
            ),
          ),
          if (showVehicleColumns) ...[
            SizedBox(
              width: _overallColVehicle,
              child: Container(
                color: rowColor,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(showVehicleForThisItem ? (record['vehicle_type']?.toString() ?? '') : ''),
              ),
            ),
            SizedBox(
              width: _overallColPart,
              child: Container(
                color: rowColor,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(showVehicleForThisItem ? (record['part_number']?.toString() ?? '') : ''),
              ),
            ),
          ],
          _overallCell(record['remaining_stock_gram']?.toString() ?? '0', Colors.blue.shade50, rowColor, null),
          _overallCell(record['remaining_stock_kg']?.toString() ?? '0', Colors.blue.shade50, rowColor, null),
          _overallCell(record['remaining_stock_litre']?.toString() ?? '0', Colors.blue.shade50, rowColor, null),
          _overallCell(record['remaining_stock_pieces']?.toString() ?? '0', Colors.blue.shade50, rowColor, null),
          _overallCell(record['remaining_stock_boxes']?.toString() ?? '0', Colors.blue.shade50, rowColor, null),
          _overallCell(record['new_stock_gram']?.toString() ?? '0', Colors.green.shade50, rowColor, _overallNewStockGramControllers[key]),
          _overallCell(record['new_stock_kg']?.toString() ?? '0', Colors.green.shade50, rowColor, _overallNewStockKgControllers[key]),
          _overallCell(record['new_stock_litre']?.toString() ?? '0', Colors.green.shade50, rowColor, _overallNewStockLitreControllers[key]),
          _overallCell(record['new_stock_pieces']?.toString() ?? '0', Colors.green.shade50, rowColor, _overallNewStockPiecesControllers[key]),
          _overallCell(record['new_stock_boxes']?.toString() ?? '0', Colors.green.shade50, rowColor, _overallNewStockBoxesControllers[key]),
        ];
        return SizedBox(
          height: _overallRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        );
      },
    );
  }

  Widget _headerCell(String text, MaterialColor color, double width) {
    return SizedBox(
      width: width,
      height: _overallHeaderHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  Widget _overallCell(String text, Color bgColor, Color rowColor, TextEditingController? controller) {
    return SizedBox(
      width: _overallColUnit,
      child: Container(
        color: rowColor,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: _isEditModeOverall && controller != null
              ? TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                )
              : Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildItemPriceTable() {
    final showSectorColumn = widget.selectedSector == null || widget.includedSectorCodes != null;
    final query = _itemPriceSearchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _itemPrices
        : _itemPrices.where((r) => (r['item_name']?.toString() ?? '').toLowerCase().contains(query)).toList();
    if (_itemPrices.isEmpty && !_isLoading) {
      return const Center(child: Text('No item prices. Add item names from New Entry.'));
    }
    if (filtered.isEmpty) {
      return const Center(child: Text('No matching items'));
    }
    final totalWidth = showSectorColumn
        ? (_itemPriceColSector + _itemPriceColName + _itemPriceColQty + _itemPriceColUnit + _itemPriceColNew + _itemPriceColOld)
        : (_itemPriceColName + _itemPriceColQty + _itemPriceColUnit + _itemPriceColNew + _itemPriceColOld);
    return FixedHeaderTable(
      horizontalScrollController: _itemPriceHorizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _itemPriceHeaderHeight,
      headerBuilder: (context) {
        final cells = <Widget>[
          if (showSectorColumn)
            const SizedBox(width: _itemPriceColSector, child: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: _itemPriceColName, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: _itemPriceColQty, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: _itemPriceColUnit, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: _itemPriceColNew, child: Text('New Price', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: _itemPriceColOld, child: Text('Old Price', style: TextStyle(fontWeight: FontWeight.bold))),
        ];
        return SizedBox(
          height: _itemPriceHeaderHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: cells,
          ),
        );
      },
      rowCount: filtered.length,
      rowBuilder: (context, index) {
        final r = filtered[index];
        final itemNameId = r['item_name_id'] as int? ?? (r['id'] as int? ?? 0);
        final qCtrl = _itemPriceQuantityControllers[itemNameId];
        final unitValue = _itemPriceUnitValues[itemNameId];
        final newCtrl = _itemPriceNewPriceControllers[itemNameId];
        final oldCtrl = _itemPriceOldPriceControllers[itemNameId];
        final cells = <Widget>[
          if (showSectorColumn)
            SizedBox(
              width: _itemPriceColSector,
              child: Text(_getSectorName(r['sector_code']?.toString())),
            ),
          SizedBox(
            width: _itemPriceColName,
            child: Text(r['item_name']?.toString() ?? ''),
          ),
          SizedBox(
            width: _itemPriceColQty,
            child: _isEditModeItemPrice && qCtrl != null
                ? TextField(
                    controller: qCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  )
                : Text(r['quantity']?.toString() ?? ''),
          ),
          SizedBox(
            width: _itemPriceColUnit,
            child: _isEditModeItemPrice
                ? DropdownButtonFormField<String>(
                    initialValue: unitValue != null && _itemPriceUnitOptions.contains(unitValue) ? unitValue : null,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('-', style: TextStyle(fontSize: 12, color: Colors.black))),
                      DropdownMenuItem(value: 'gram', child: Text('gram', style: TextStyle(fontSize: 12, color: Colors.black))),
                      DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 12, color: Colors.black))),
                      DropdownMenuItem(value: 'Litre', child: Text('Litre', style: TextStyle(fontSize: 12, color: Colors.black))),
                      DropdownMenuItem(value: 'pieces', child: Text('pieces', style: TextStyle(fontSize: 12, color: Colors.black))),
                      DropdownMenuItem(value: 'Boxes', child: Text('Boxes', style: TextStyle(fontSize: 12, color: Colors.black))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _itemPriceUnitValues[itemNameId] = value;
                      });
                    },
                  )
                : Text(r['unit']?.toString() ?? '-'),
          ),
          SizedBox(
            width: _itemPriceColNew,
            child: _isEditModeItemPrice && newCtrl != null
                ? TextField(
                    controller: newCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  )
                : Text(r['new_price']?.toString() ?? ''),
          ),
          SizedBox(
            width: _itemPriceColOld,
            child: _isEditModeItemPrice && oldCtrl != null
                ? TextField(
                    controller: oldCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  )
                : Text(r['old_price']?.toString() ?? ''),
          ),
        ];
        return SizedBox(
          height: _itemPriceRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: cells,
          ),
        );
      },
    );
  }
}

class _StatementDialog extends StatefulWidget {
  final String? selectedSector;

  const _StatementDialog({this.selectedSector});

  @override
  State<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends State<_StatementDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Statement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Custom:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'From Date *',
                hintText: 'Select Date',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_fromDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _fromDate = null;
                          });
                        },
                        tooltip: 'Clear From Date',
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectFromDate,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              controller: TextEditingController(
                text: _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'To Date *',
                hintText: 'Select Date',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_toDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _toDate = null;
                          });
                        },
                        tooltip: 'Clear To Date',
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectToDate,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              controller: TextEditingController(
                text: _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : '',
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Get it As:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Pdf'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _fromDate != null && _toDate != null
              ? () {
                  Navigator.pop(context, {
                    'from_date': DateFormat('yyyy-MM-dd').format(_fromDate!),
                    'to_date': DateFormat('yyyy-MM-dd').format(_toDate!),
                    'sector': widget.selectedSector,
                  });
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.brown.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
