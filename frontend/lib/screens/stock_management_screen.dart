import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import 'login_screen.dart';
import 'home_screen.dart';
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
  int? _selectedMonthOverall;
  DateTime? _selectedDateOverall;
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
  final Map<String, TextEditingController> _dailyQuantityControllers = {};
  final Map<String, TextEditingController> _dailyReasonControllers = {};
  final Map<String, TextEditingController> _overallNewStockControllers = {};

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedMonth = DateTime.now().month;
    _selectedDate = DateTime.now();
    _selectedMonthOverall = DateTime.now().month;
    _selectedDateOverall = DateTime.now();
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
    if (_selectedMonthOverall == null || _selectedDateOverall == null) return;
    
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDateOverall!);
      final stock = await ApiService.getOverallStock(
        month: _selectedMonthOverall,
        date: dateStr,
        sector: widget.selectedSector,
      );
      if (mounted) {
        for (var controller in _overallNewStockControllers.values) {
          controller.dispose();
        }
        _overallNewStockControllers.clear();
        
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
      _loadDailyStock();
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
      _loadDailyStock();
    }
  }

  Future<void> _selectMonthOverall() async {
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
              final isSelected = monthNumber == _selectedMonthOverall;
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
        _selectedMonthOverall = picked;
      });
      _loadOverallStock();
    }
  }

  Future<void> _selectDateOverall() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOverall ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateOverall = picked;
      });
      _loadOverallStock();
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
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDateOverall!);
      for (var item in _overallStock) {
        final id = item['id'] as int;
        final itemId = item['item_id'] as int;
        final key = '${itemId}_$id';
        final newStockController = _overallNewStockControllers[key];
        
        if (newStockController != null) {
          updates.add({
            'id': id == -1 ? null : id,
            'item_id': itemId,
            'new_stock': newStockController.text.trim(),
          });
        }
      }
      
      await ApiService.updateOverallStock(updates, date: dateStr);
      if (mounted) {
        setState(() {
          _isEditModeOverall = false;
        });
        _loadOverallStock();
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
            Tab(text: 'Daily Stock'),
            Tab(text: 'Overall Stock'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
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
                              columns: [
                                if (widget.selectedSector == null)
                                  const DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                if (showVehicleColumns) ...[
                                  const DataColumn(label: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                const DataColumn(label: Text('Quantity Taken', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                              width: 100,
                                              child: TextField(
                                                controller: quantityController,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['quantity_taken']?.toString() ?? '0'),
                                    ),
                                    DataCell(
                                      _isEditModeDaily
                                          ? SizedBox(
                                              width: 200,
                                              child: TextField(
                                                controller: reasonController,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
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
                            onPressed: _selectMonthOverall,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(_selectedMonthOverall != null ? _months[_selectedMonthOverall! - 1] : 'Select Month'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectDateOverall,
                            icon: const Icon(Icons.date_range),
                            label: Text(_selectedDateOverall != null
                                ? DateFormat('dd/MM/yyyy').format(_selectedDateOverall!)
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
                              columns: [
                                if (widget.selectedSector == null)
                                  const DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                if (showVehicleColumns) ...[
                                  const DataColumn(label: Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Part Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                const DataColumn(label: Text('Remaining Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('New Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredOverallStock.map((record) {
                                final id = record['id'] as int;
                                final itemId = record['item_id'] as int;
                                final key = '${itemId}_$id';
                                final newStockController = _overallNewStockControllers[key];
                                
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
                                    DataCell(Text(record['remaining_stock']?.toString() ?? '0')),
                                    DataCell(
                                      _isEditModeOverall
                                          ? SizedBox(
                                              width: 100,
                                              child: TextField(
                                                controller: newStockController,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['new_stock']?.toString() ?? '0'),
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
