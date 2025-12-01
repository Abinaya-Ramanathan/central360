import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'production_tab_content.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StockManagementScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const StockManagementScreen({
    super.key,
    required this.username,
    this.selectedSector,
  });

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> with SingleTickerProviderStateMixin {
  int? _selectedMonth;
  DateTime? _selectedDate;
  late TabController _tabController;
  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _dailyStock = [];
  List<Map<String, dynamic>> _overallStock = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _isEditModeDaily = false;
  bool _isEditModeOverall = false;
  bool _isAdmin = false;
  String _searchQuery = '';
  bool _sortAscendingDaily = true; // Sort direction for Sector column in Daily Stock
  bool _sortAscendingOverall = true; // Sort direction for Sector column in Overall Stock
  final Map<String, TextEditingController> _dailyQuantityControllers = {};
  final Map<String, TextEditingController> _dailyReasonControllers = {};
  final Map<String, String?> _dailyQuantityUnits = {}; // Store unit for each quantity
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

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime.now().month;
    _selectedDate = DateTime.now();
    final usernameLower = widget.username.toLowerCase();
    _isAdmin = usernameLower == 'admin' || usernameLower == 'abinaya' || usernameLower == 'srisurya';
    _loadSectors();
    _loadStockItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _dailyQuantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _dailyReasonControllers.values) {
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

  Future<void> _loadStockItems() async {
    try {
      final items = await ApiService.getStockItems(sector: widget.selectedSector);
      if (mounted) {
        setState(() {
          _stockItems = items;
        });
        _loadDailyStock();
        _loadOverallStock();
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
    if (_selectedMonth == null || _selectedDate == null) return;
    
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final stock = await ApiService.getDailyStock(
        month: _selectedMonth,
        date: dateStr,
        sector: widget.selectedSector,
      );
      if (mounted) {
        for (var controller in _dailyQuantityControllers.values) {
          controller.dispose();
        }
        for (var controller in _dailyReasonControllers.values) {
          controller.dispose();
        }
        _dailyQuantityControllers.clear();
        _dailyReasonControllers.clear();
        
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
          });
        }
        
        setState(() {
          _dailyStock = allStock;
          for (var item in _dailyStock) {
            final id = item['id'] as int;
            final itemId = item['item_id'] as int;
            // Use item_id as key to avoid conflicts with temporary -1 ids
            final key = '${itemId}_$id';
            _dailyQuantityControllers[key] = TextEditingController(
              text: item['quantity_taken']?.toString() ?? '',
            );
            _dailyReasonControllers[key] = TextEditingController(
              text: item['reason']?.toString() ?? '',
            );
            _dailyQuantityUnits[key] = item['unit']?.toString();
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
      final stock = await ApiService.getOverallStock(
        sector: widget.selectedSector,
      );
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

  Future<void> _selectMonth() async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _months.length,
            itemBuilder: (context, index) {
              final monthNumber = index + 1;
              final isSelected = monthNumber == _selectedMonth;
              return ListTile(
                title: Text(_months[index]),
                selected: isSelected,
                onTap: () => Navigator.pop(context, monthNumber),
              );
            },
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedMonth = picked;
      });
      // Only load daily stock if we're on the Daily Stock tab (index 1)
      if (_tabController.index == 1) {
      _loadDailyStock();
      }
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
          updates.add({
            'id': id == -1 ? null : id,
            'item_id': itemId,
            'quantity_taken': quantityController.text.trim(),
            'unit': _dailyQuantityUnits[key],
            'reason': reasonController.text.trim(),
          });
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
    if (_searchQuery.isEmpty) return stock;
    final query = _searchQuery.toLowerCase();
    return stock.where((item) {
      final itemName = item['item_name']?.toString().toLowerCase() ?? '';
      final vehicleType = item['vehicle_type']?.toString().toLowerCase() ?? '';
      final partNumber = item['part_number']?.toString().toLowerCase() ?? '';
      return itemName.contains(query) || vehicleType.contains(query) || partNumber.contains(query);
    }).toList();
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
    // Show only for SSEW sector items
    return sectorCode == 'SSEW';
  }

  @override
  Widget build(BuildContext context) {
    final filteredDailyStock = _filterStock(_dailyStock);
    final filteredOverallStock = _filterStock(_overallStock);
    
    // Show vehicle columns for SSEW sector or for admin when All Sectors is selected
    final showVehicleColumns = (widget.selectedSector == 'SSEW') || 
                               (widget.selectedSector == null && _isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        actions: [
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
                    initialSector: widget.selectedSector,
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Production Tab
          Column(
            children: [
              // Month and Date Selection
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectMonth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Select Month',
                            prefixIcon: const Icon(Icons.calendar_month),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedMonth != null ? _months[_selectedMonth! - 1] : 'Select Month',
                            style: TextStyle(
                              color: _selectedMonth != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
              // Production Tab Content
              Expanded(
                child: ProductionTabContent(
                  selectedSector: widget.selectedSector,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isAdmin: _isAdmin,
                ),
              ),
            ],
          ),
          // Daily Stock Tab
          Column(
            children: [
              // Month and Date Selection
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectMonth,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(_selectedMonth != null ? _months[_selectedMonth! - 1] : 'Select Month'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.date_range),
                            label: Text(_selectedDate != null
                                ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                : 'Select Date'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by Item Name, Vehicle Type, or Part Number',
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
                  ],
                ),
              ),
              // Daily Stock Table
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredDailyStock.isEmpty
                        ? const Center(child: Text('No daily stock records found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                              columnSpacing: 12,
                              sortColumnIndex: widget.selectedSector == null ? 0 : null,
                              sortAscending: _sortAscendingDaily,
                              columns: [
                                if (widget.selectedSector == null)
                                  DataColumn(
                                    label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onSort: (columnIndex, ascending) {
                                      setState(() {
                                        _sortAscendingDaily = ascending;
                                        filteredDailyStock.sort((a, b) {
                                          final aName = (a['sector_name']?.toString() ?? a['sector_code']?.toString() ?? '').toLowerCase();
                                          final bName = (b['sector_name']?.toString() ?? b['sector_code']?.toString() ?? '').toLowerCase();
                                          return ascending
                                              ? aName.compareTo(bName)
                                              : bName.compareTo(aName);
                                        });
                                      });
                                    },
                                  ),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                if (showVehicleColumns) ...[
                                  const DataColumn(label: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                const DataColumn(label: Text('Quantity Taken', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredDailyStock.map((record) {
                                final id = record['id'] as int;
                                final itemId = record['item_id'] as int;
                                final key = '${itemId}_$id';
                                final quantityController = _dailyQuantityControllers[key];
                                final reasonController = _dailyReasonControllers[key];
                                final itemSectorCode = record['sector_code']?.toString();
                                final showVehicleForThisItem = _shouldShowVehicleFieldsForItem(itemSectorCode);
                                
                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null)
                                      DataCell(Text(record['sector_name']?.toString() ?? record['sector_code']?.toString() ?? '')),
                                    DataCell(Text(record['item_name']?.toString() ?? 'N/A')),
                                    if (showVehicleColumns) ...[
                                      DataCell(Text(showVehicleForThisItem ? (record['vehicle_type']?.toString() ?? '') : '')),
                                      DataCell(Text(showVehicleForThisItem ? (record['part_number']?.toString() ?? '') : '')),
                                    ],
                                    DataCell(
                                      _isEditModeDaily
                                          ? SizedBox(
                                              width: 90,
                                              child: TextField(
                                                controller: quantityController,
                                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                ],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            )
                                          : Text(record['quantity_taken']?.toString() ?? '0'),
                                    ),
                                    DataCell(
                                      _isEditModeDaily
                                          ? ConstrainedBox(
                                              constraints: const BoxConstraints(minWidth: 65, maxWidth: 80),
                                              child: DropdownButtonFormField<String>(
                                                value: _dailyQuantityUnits[key],
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
                                                  DropdownMenuItem(value: 'Boxes', child: Text('Boxes', style: TextStyle(fontSize: 11, color: Colors.black))),
                                                ],
                                                onChanged: (value) {
                                                  setState(() {
                                                    _dailyQuantityUnits[key] = value;
                                                  });
                                                },
                                              ),
                                            )
                                          : Text(record['unit']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Colors.black)),
                                    ),
                                    DataCell(
                                      _isEditModeDaily
                                          ? SizedBox(
                                              width: 180,
                                              child: TextField(
                                                controller: reasonController,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            )
                                          : Text(record['reason']?.toString() ?? ''),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
              ),
              // Edit Button
              Container(
                padding: const EdgeInsets.all(16),
                child: _isEditModeDaily
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeDaily = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
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
                    : ElevatedButton.icon(
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
              ),
            ],
          ),
          // Overall Stock Tab
          Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by Item Name, Vehicle Type, or Part Number',
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
              // Overall Stock Table
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredOverallStock.isEmpty
                        ? const Center(child: Text('No overall stock records found'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                              columnSpacing: 12,
                              sortColumnIndex: widget.selectedSector == null ? 0 : null,
                              sortAscending: _sortAscendingOverall,
                              columns: [
                                if (widget.selectedSector == null)
                                  DataColumn(
                                    label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onSort: (columnIndex, ascending) {
                                      setState(() {
                                        _sortAscendingOverall = ascending;
                                        filteredOverallStock.sort((a, b) {
                                          final aName = (a['sector_name']?.toString() ?? a['sector_code']?.toString() ?? '').toLowerCase();
                                          final bName = (b['sector_name']?.toString() ?? b['sector_code']?.toString() ?? '').toLowerCase();
                                          return ascending
                                              ? aName.compareTo(bName)
                                              : bName.compareTo(aName);
                                        });
                                      });
                                    },
                                  ),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                if (showVehicleColumns) ...[
                                  const DataColumn(label: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Remaining Stock\nin gram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Remaining Stock\nin kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Remaining Stock\nin litre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Remaining Stock\nin pieces', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Remaining Stock\nin Boxes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('New Stock\nin gram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('New Stock\nin kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('New Stock\nin litre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('New Stock\nin pieces', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('New Stock\nin Boxes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ],
                              rows: filteredOverallStock.map((record) {
                                final id = record['id'] as int;
                                final itemId = record['item_id'] as int;
                                final key = '${itemId}_$id';
                                
                                final itemSectorCode = record['sector_code']?.toString();
                                final showVehicleForThisItem = _shouldShowVehicleFieldsForItem(itemSectorCode);
                                
                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null)
                                      DataCell(Text(record['sector_name']?.toString() ?? record['sector_code']?.toString() ?? '')),
                                    DataCell(Text(record['item_name']?.toString() ?? 'N/A')),
                                    if (showVehicleColumns) ...[
                                      DataCell(Text(showVehicleForThisItem ? (record['vehicle_type']?.toString() ?? '') : '')),
                                      DataCell(Text(showVehicleForThisItem ? (record['part_number']?.toString() ?? '') : '')),
                                    ],
                                    // Remaining Stock in gram (read-only, auto-calculated)
                                    DataCell(
                                      Container(
                                        color: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Text(
                                          record['remaining_stock_gram']?.toString() ?? '0',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    // Remaining Stock in kg (read-only, auto-calculated)
                                    DataCell(
                                      Container(
                                        color: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Text(
                                          record['remaining_stock_kg']?.toString() ?? '0',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    // Remaining Stock in litre (read-only, auto-calculated)
                                    DataCell(
                                      Container(
                                        color: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Text(
                                          record['remaining_stock_litre']?.toString() ?? '0',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    // Remaining Stock in pieces (read-only, auto-calculated)
                                    DataCell(
                                      Container(
                                        color: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Text(
                                          record['remaining_stock_pieces']?.toString() ?? '0',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    // Remaining Stock in Boxes (read-only, auto-calculated)
                                    DataCell(
                                      Container(
                                        color: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: Text(
                                          record['remaining_stock_boxes']?.toString() ?? '0',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    // New Stock in gram
                                    DataCell(
                                      Container(
                                        color: Colors.green.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: _isEditModeOverall
                                          ? SizedBox(
                                                width: 90,
                                              child: TextField(
                                                  controller: _overallNewStockGramControllers[key],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                  ],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            )
                                            : Text(record['new_stock_gram']?.toString() ?? '0'),
                                      ),
                                    ),
                                    // New Stock in kg
                                    DataCell(
                                      Container(
                                        color: Colors.green.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: _isEditModeOverall
                                            ? SizedBox(
                                                width: 90,
                                                child: TextField(
                                                  controller: _overallNewStockKgControllers[key],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                  ],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                ),
                                              )
                                            : Text(record['new_stock_kg']?.toString() ?? '0'),
                                      ),
                                    ),
                                    // New Stock in litre
                                    DataCell(
                                      Container(
                                        color: Colors.green.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: _isEditModeOverall
                                            ? SizedBox(
                                                width: 90,
                                                child: TextField(
                                                  controller: _overallNewStockLitreControllers[key],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                  ],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                ),
                                              )
                                            : Text(record['new_stock_litre']?.toString() ?? '0'),
                                      ),
                                    ),
                                    // New Stock in pieces
                                    DataCell(
                                      Container(
                                        color: Colors.green.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: _isEditModeOverall
                                            ? SizedBox(
                                                width: 90,
                                                child: TextField(
                                                  controller: _overallNewStockPiecesControllers[key],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                  ],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                ),
                                              )
                                            : Text(record['new_stock_pieces']?.toString() ?? '0'),
                                      ),
                                    ),
                                    // New Stock in Boxes
                                    DataCell(
                                      Container(
                                        color: Colors.green.shade50,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        child: _isEditModeOverall
                                            ? SizedBox(
                                                width: 90,
                                                child: TextField(
                                                  controller: _overallNewStockBoxesControllers[key],
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                  ],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                ),
                                              )
                                            : Text(record['new_stock_boxes']?.toString() ?? '0'),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
              ),
              // Edit and Statement Buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: _isEditModeOverall
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _isEditModeOverall = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(width: 16),
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
              ),
            ],
          ),
        ],
      ),
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectFromDate,
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectToDate,
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
