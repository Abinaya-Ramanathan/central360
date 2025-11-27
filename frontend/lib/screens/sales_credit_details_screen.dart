import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../utils/ui_helpers.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SalesCreditDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const SalesCreditDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<SalesCreditDetailsScreen> createState() => _SalesCreditDetailsScreenState();
}

class _SalesCreditDetailsScreenState extends State<SalesCreditDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Sector> _sectors = [];
  bool _isAdmin = false;
  
  // Sales Details Tab State
  int? _selectedMonth;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _salesData = [];
  bool _isLoadingSales = false;
  final Map<int, bool> _editModeSales = {};
  final Map<int, Map<String, TextEditingController>> _controllersSales = {};
  bool _salesSectorSortAscending = true; // Sort direction for Sector column in Sales Details
  
  // Credit Details Tab State
  List<Map<String, dynamic>> _creditData = [];
  List<Map<String, dynamic>> _filteredCreditData = [];
  bool _isLoadingCredit = false;
  final TextEditingController _creditSearchController = TextEditingController();
  bool _creditDateSortAscending = true; // true = ascending (oldest first), false = descending (newest first)
  bool _creditSectorSortAscending = true; // Sort direction for Sector column in Credit Details
  final Map<int, bool> _editModeCredit = {}; // Track which rows are in edit mode (key = record ID)
  final Map<int, TextEditingController> _balancePaidControllers = {}; // Controllers for Balance Paid field (key = record ID)
  final Map<int, DateTime?> _balancePaidDates = {}; // Selected dates for Balance Paid Date (key = record ID)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isAdmin = AuthService.isAdmin;
    _selectedMonth = DateTime.now().month;
    _selectedDate = DateTime.now();
    _loadSectors();
    _loadSalesData();
    _loadCreditData();
    
    // Reload credit data when switching to Credit Details tab
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _loadCreditData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controllers in _controllersSales.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    _creditSearchController.dispose();
    for (var controller in _balancePaidControllers.values) {
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

  Future<void> _selectMonth() async {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 12,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(months[index]),
                onTap: () => Navigator.pop(context, index + 1),
              );
            },
          ),
        ),
      ),
    );
    
    if (selected != null) {
      setState(() {
        _selectedMonth = selected;
      });
      _loadSalesData();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSalesData();
    }
  }

  Future<void> _loadSalesData() async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedMonth == null || _selectedDate == null) return;

    setState(() => _isLoadingSales = true);
    try {
      final monthStr = _selectedMonth.toString().padLeft(2, '0');
      final year = _selectedDate!.year;
      final monthParam = '$year-$monthStr';
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];

      debugPrint('Loading sales data for date: $dateStr, month: $monthParam');
      
      final sales = await ApiService.getSalesDetails(
        sector: widget.selectedSector,
        date: dateStr, // Filter by exact date - only show records from this date
        month: monthParam,
      );
      
      debugPrint('Loaded ${sales.length} sales records for date $dateStr');

      setState(() {
        _salesData = sales;
        _editModeSales.clear();
        for (var controllers in _controllersSales.values) {
          for (var controller in controllers.values) {
            controller.dispose();
          }
        }
        _controllersSales.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSales = false);
      }
    }
  }

  Future<void> _loadCreditData() async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoadingCredit = true);
    try {
      final credits = await ApiService.getCreditDetailsFromSales(
        sector: widget.selectedSector,
      );

      debugPrint('=== Loading Credit Data ===');
      debugPrint('Total credit records: ${credits.length}');
      for (var credit in credits) {
        final name = credit['name']?.toString() ?? 'N/A';
        final saleDate = credit['sale_date']?.toString().split('T')[0].split(' ')[0] ?? 'N/A';
        final creditAmount = _parseDecimal(credit['credit_amount']);
        debugPrint('  - $name: sale_date=$saleDate, credit_amount=₹$creditAmount');
      }

      setState(() {
        _creditData = credits;
        _filteredCreditData = List.from(credits);
        // Apply initial sorting
        _sortCreditData();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading credit data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  void _toggleEditModeCredit(int recordId) {
    setState(() {
      if (_editModeCredit[recordId] == true) {
        // Cancel edit mode - dispose controller and clear date
        if (_balancePaidControllers.containsKey(recordId)) {
          _balancePaidControllers[recordId]!.dispose();
          _balancePaidControllers.remove(recordId);
        }
        _balancePaidDates.remove(recordId);
        _editModeCredit[recordId] = false;
      } else {
        // Enter edit mode - find record by ID and create controller with current balance_paid value
        final record = _filteredCreditData.firstWhere(
          (r) => r['id'] == recordId,
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          final currentBalancePaid = _parseDecimal(record['balance_paid']);
          _balancePaidControllers[recordId] = TextEditingController(
            text: currentBalancePaid > 0 ? currentBalancePaid.toStringAsFixed(2) : '',
          );
          // Initialize balance_paid_date if exists
          _balancePaidDates[recordId] = FormatUtils.parseDate(record['balance_paid_date']);
          _editModeCredit[recordId] = true;
        }
      }
    });
  }

  Future<void> _saveCreditRecord(int recordId) async {
    if (!_balancePaidControllers.containsKey(recordId)) {
      return;
    }

    // Find record by ID
    final record = _filteredCreditData.firstWhere(
      (r) => r['id'] == recordId,
      orElse: () => {},
    );
    
    if (record.isEmpty) {
      return;
    }
    final balancePaidText = _balancePaidControllers[recordId]!.text.trim();
    final balancePaid = _parseDecimal(balancePaidText);
    final balancePaidDate = _balancePaidDates[recordId];

    setState(() => _isLoadingCredit = true);

    try {
      // Format balance_paid_date as YYYY-MM-DD string
      final balancePaidDateStr = balancePaidDate != null 
          ? FormatUtils.formatDate(balancePaidDate) 
          : null;

      // Update the record with new balance_paid and balance_paid_date
      final updatedRecord = {
        'id': record['id'],
        'sector_code': record['sector_code'],
        'name': record['name'],
        'contact_number': record['contact_number'],
        'address': record['address'],
        'product_name': record['product_name'],
        'quantity': record['quantity'],
        'amount_received': _parseDecimal(record['amount_received']),
        'credit_amount': _parseDecimal(record['credit_amount']),
        'balance_paid': balancePaid,
        'balance_paid_date': balancePaidDateStr,
        'sale_date': record['sale_date'],
      };

      await ApiService.saveSalesDetails(updatedRecord);

      // Exit edit mode and dispose controllers
      if (_balancePaidControllers.containsKey(recordId)) {
        _balancePaidControllers[recordId]!.dispose();
        _balancePaidControllers.remove(recordId);
      }
      _balancePaidDates.remove(recordId);
      _editModeCredit[recordId] = false;

      // Reload credit data to reflect changes
      await _loadCreditData();

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, 'Balance paid updated successfully');
      }
    } catch (e) {
      debugPrint('Error saving credit record: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error saving balance paid: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  Future<void> _deleteCreditRecord(int recordId, String name) async {
    // Show confirmation dialog
    final confirmed = await UIHelpers.showDeleteConfirmationDialog(
      context: context,
      itemName: 'credit record for "$name"',
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isLoadingCredit = true);

    try {
      await ApiService.deleteSalesDetails(recordId.toString());

      // Reload credit data to reflect changes
      await _loadCreditData();

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, 'Credit record deleted successfully');
      }
    } catch (e) {
      debugPrint('Error deleting credit record: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error deleting credit record: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  // Use utility function instead of local method
  double _parseDecimal(dynamic value) => FormatUtils.parseDecimal(value);

  // Use utility function instead of local method
  String _formatDate(dynamic dateValue) => FormatUtils.formatDate(dateValue);

  void _filterCreditData(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCreditData = List.from(_creditData);
      } else {
        final searchQuery = query.toLowerCase();
        _filteredCreditData = _creditData.where((record) {
          final name = (record['name']?.toString() ?? '').toLowerCase();
          final address = (record['address']?.toString() ?? '').toLowerCase();
          return name.contains(searchQuery) || address.contains(searchQuery);
        }).toList();
      }
      // Apply sorting after filtering
      _sortCreditData();
    });
  }

  void _sortCreditData() {
    _filteredCreditData.sort((a, b) {
      // Sort by date first if date sorting is enabled
      final dateAValue = a['sale_date'];
      final dateBValue = b['sale_date'];
      
      DateTime? dateA;
      DateTime? dateB;
      
      if (dateAValue != null) {
        try {
          if (dateAValue is DateTime) {
            dateA = dateAValue;
          } else if (dateAValue is String) {
            final dateStr = dateAValue.split('T')[0].split(' ')[0];
            dateA = DateTime.tryParse(dateStr);
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      if (dateBValue != null) {
        try {
          if (dateBValue is DateTime) {
            dateB = dateBValue;
          } else if (dateBValue is String) {
            final dateStr = dateBValue.split('T')[0].split(' ')[0];
            dateB = DateTime.tryParse(dateStr);
          }
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      if (dateA != null && dateB != null) {
        final dateComparison = dateA.compareTo(dateB);
        return _creditDateSortAscending ? dateComparison : -dateComparison;
      }
      if (dateA != null) return -1;
      if (dateB != null) return 1;
      return 0;
    });
  }

  Future<void> _showAddSalesDialog() async {
    if (widget.selectedSector == null && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector from Home page')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final addressController = TextEditingController();
    final productController = TextEditingController();
    final quantityController = TextEditingController();
    final amountReceivedController = TextEditingController();
    final creditAmountController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sales Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: productController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountReceivedController,
                decoration: const InputDecoration(
                  labelText: 'Amount Received',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: creditAmountController,
                decoration: const InputDecoration(
                  labelText: 'Credit Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              contactController.dispose();
              addressController.dispose();
              productController.dispose();
              quantityController.dispose();
              amountReceivedController.dispose();
              creditAmountController.dispose();
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              if (productController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product Name is required')),
                );
                return;
              }
              if (quantityController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveNewSales(
        name: nameController.text.trim(),
        contact: contactController.text.trim(),
        address: addressController.text.trim(),
        productName: productController.text.trim(),
        quantity: quantityController.text.trim(),
        amountReceived: _parseDecimal(amountReceivedController.text),
        creditAmount: _parseDecimal(creditAmountController.text),
      );
    }

    nameController.dispose();
    contactController.dispose();
    addressController.dispose();
    productController.dispose();
    quantityController.dispose();
    amountReceivedController.dispose();
    creditAmountController.dispose();
  }

  Future<void> _saveNewSales({
    required String name,
    required String contact,
    required String address,
    required String productName,
    required String quantity,
    required double amountReceived,
    required double creditAmount,
  }) async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedDate == null) return;

    setState(() => _isLoadingSales = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final record = {
        'sector_code': widget.selectedSector,
        'name': name,
        'contact_number': contact.isEmpty ? null : contact,
        'address': address.isEmpty ? null : address,
        'product_name': productName,
        'quantity': quantity,
        'amount_received': amountReceived,
        'credit_amount': creditAmount,
        'sale_date': dateStr,
      };

      await ApiService.saveSalesDetails(record);
      await _loadSalesData();
      await _loadCreditData(); // Reload credit data as well

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales details added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding sales details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSales = false);
      }
    }
  }

  Future<void> _toggleEditModeSales(int index) async {
    setState(() {
      if (_editModeSales[index] == true) {
        // Exiting edit mode
        if (_controllersSales.containsKey(index)) {
          for (var controller in _controllersSales[index]!.values) {
            controller.dispose();
          }
          _controllersSales.remove(index);
        }
        _editModeSales[index] = false;
      } else {
        // Entering edit mode
        final record = _salesData[index];
        final currentSaleDate = record['sale_date']?.toString().split('T')[0].split(' ')[0] ?? '';
        final selectedDateStr = _selectedDate?.toIso8601String().split('T')[0] ?? '';
        
        debugPrint('Entering edit mode - Current sale_date: $currentSaleDate, Selected date: $selectedDateStr');
        
        // Show a warning if the selected date is different from the record's sale_date
        if (currentSaleDate.isNotEmpty && currentSaleDate != selectedDateStr) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Note: Sale date will be updated from $currentSaleDate to $selectedDateStr when you save.\n'
                    'This will be the Credit Taken Date.',
                  ),
                  duration: const Duration(seconds: 4),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          });
        }
        
        _controllersSales[index] = {
          'name': TextEditingController(text: record['name']?.toString() ?? ''),
          'contact_number': TextEditingController(text: record['contact_number']?.toString() ?? ''),
          'address': TextEditingController(text: record['address']?.toString() ?? ''),
          'product_name': TextEditingController(text: record['product_name']?.toString() ?? ''),
          'quantity': TextEditingController(text: record['quantity']?.toString() ?? ''),
          'amount_received': TextEditingController(text: _parseDecimal(record['amount_received']).toString()),
          'credit_amount': TextEditingController(text: _parseDecimal(record['credit_amount']).toString()),
        };
        _editModeSales[index] = true;
      }
    });
  }

  Future<void> _saveSalesRecord(int index) async {
    final record = _salesData[index];
    final recordId = record['id'];
    if (recordId == null) return;

    if (!_controllersSales.containsKey(index)) return;

    final controllers = _controllersSales[index]!;
    if (controllers['name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (controllers['product_name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product Name is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (controllers['quantity']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity is required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoadingSales = true);
    try {
      // CRITICAL: Always use the selected date from the date picker as the sale_date
      // This ensures Credit Taken Date matches the date selected in Sales Details tab
      // When credit is added/updated, the sale_date MUST be updated to the selected date
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final oldCreditAmount = _parseDecimal(record['credit_amount']);
      final newCreditAmount = _parseDecimal(controllers['credit_amount']!.text);
      final oldSaleDate = record['sale_date']?.toString().split('T')[0].split(' ')[0] ?? '';
      
      debugPrint('=== Saving Sales Record ===');
      debugPrint('Record ID: $recordId');
      debugPrint('Selected Date (from picker): $dateStr');
      debugPrint('Old Sale Date: $oldSaleDate');
      debugPrint('Old Credit Amount: $oldCreditAmount');
      debugPrint('New Credit Amount: $newCreditAmount');
      
      // ALWAYS use the selected date when saving - this becomes the Credit Taken Date
      // This ensures that if credit is added on 27/11, the Credit Taken Date shows 27/11
      final saleDateToUse = dateStr;
      
      debugPrint('Using sale_date: $saleDateToUse (will be saved to database)');
      
      // CRITICAL: When credit is present, sale_date MUST be the selected date
      // This is the Credit Taken Date - it must reflect when credit was actually added
      // Show confirmation if the date is changing (but don't allow canceling if credit > 0)
      if (oldSaleDate.isNotEmpty && oldSaleDate != dateStr) {
        final hasCredit = newCreditAmount > 0;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: !hasCredit, // Can't dismiss if credit is present
          builder: (context) => AlertDialog(
            title: Text(hasCredit ? 'Update Credit Date Required' : 'Update Sale Date?'),
            content: Text(
              hasCredit
                  ? 'You have credit amount: ₹${newCreditAmount.toStringAsFixed(2)}\n\n'
                    'Current sale date: $oldSaleDate\n'
                    'Selected date: $dateStr\n\n'
                    'The Credit Taken Date MUST be updated to $dateStr to reflect when the credit was actually added.\n\n'
                    'This update is required when credit is present.'
                  : 'Current sale date: $oldSaleDate\n'
                    'Selected date: $dateStr\n\n'
                    'The sale date will be updated to $dateStr. Continue?',
            ),
            actions: [
              if (!hasCredit)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(hasCredit ? 'Update Date' : 'Update Date'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) {
          if (hasCredit) {
            // Should not happen, but just in case
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Date update is required when credit is present'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoadingSales = false);
          return;
        }
      }
      
      final updatedRecord = {
        'id': recordId,
        'sector_code': record['sector_code'] ?? widget.selectedSector,
        'name': controllers['name']!.text.trim(),
        'contact_number': controllers['contact_number']!.text.trim().isEmpty
            ? null
            : controllers['contact_number']!.text.trim(),
        'address': controllers['address']!.text.trim().isEmpty
            ? null
            : controllers['address']!.text.trim(),
        'product_name': controllers['product_name']!.text.trim(),
        'quantity': controllers['quantity']!.text.trim(),
        'amount_received': _parseDecimal(controllers['amount_received']!.text),
        'credit_amount': newCreditAmount,
        'sale_date': saleDateToUse, // Use selected date - this becomes the Credit Taken Date
      };

      debugPrint('Saving with sale_date: $saleDateToUse');
      final savedRecord = await ApiService.saveSalesDetails(updatedRecord);
      final savedSaleDate = savedRecord['sale_date']?.toString().split('T')[0].split(' ')[0] ?? 'N/A';
      debugPrint('✅ Saved record - sale_date in response: $savedSaleDate');
      debugPrint('Expected date: $saleDateToUse, Got: $savedSaleDate');
      
      if (savedSaleDate != saleDateToUse) {
        debugPrint('⚠️ WARNING: Date mismatch! Expected $saleDateToUse but got $savedSaleDate');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: Date mismatch. Expected $saleDateToUse but got $savedSaleDate'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      
      // Reload data to reflect the updated sale_date
      debugPrint('Reloading sales data...');
      await _loadSalesData();
      debugPrint('Reloading credit data...');
      await _loadCreditData();
      
      debugPrint('✅ Data reloaded. Credit data should now show updated date: $savedSaleDate');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales details saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sales details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSales = false);
      }
    }
  }

  Future<void> _deleteSalesRecord(int index) async {
    final record = _salesData[index];
    final recordId = record['id'];
    if (recordId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sales Record'),
        content: const Text('Are you sure you want to delete this sales record?'),
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

    setState(() => _isLoadingSales = true);
    try {
      await ApiService.deleteSalesDetails(recordId.toString());
      await _loadSalesData();
      await _loadCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales record deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting sales record: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSales = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales and Credit Details'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Sales Details'),
            Tab(text: 'Credit Details'),
          ],
        ),
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
                  Text(
                    'All Sectors',
                    style: TextStyle(fontSize: 14),
                  ),
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
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sales Details Tab
          _buildSalesDetailsTab(),
          // Credit Details Tab
          _buildCreditDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildSalesDetailsTab() {
    return Column(
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
                      _selectedMonth != null
                          ? [
                              'January',
                              'February',
                              'March',
                              'April',
                              'May',
                              'June',
                              'July',
                              'August',
                              'September',
                              'October',
                              'November',
                              'December'
                            ][_selectedMonth! - 1]
                          : 'Select Month',
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sales Table
        Expanded(
          child: _isLoadingSales
              ? const Center(child: CircularProgressIndicator())
              : _salesData.isEmpty
                  ? const Center(
                      child: Text(
                        'No sales data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DataTable(
                              columnSpacing: 20,
                              columns: [
                                if (widget.selectedSector == null && _isAdmin)
                                  DataColumn(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: Icon(
                                            _salesSectorSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _salesSectorSortAscending = !_salesSectorSortAscending;
                                              _salesData.sort((a, b) {
                                                final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                                final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                                return _salesSectorSortAscending
                                                    ? aName.compareTo(bName)
                                                    : bName.compareTo(aName);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Received', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Credit Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Pending', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _salesData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final record = entry.value;
                                final isEditMode = _editModeSales[index] == true;
                                final amountPending = _parseDecimal(record['amount_pending']);

                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null && _isAdmin)
                                      DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 150,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['name'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['name']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 150,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['contact_number'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.phone,
                                              ),
                                            )
                                          : Text(record['contact_number']?.toString() ?? 'N/A'),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: isEditMode && _controllersSales.containsKey(index)
                                            ? TextFormField(
                                                controller: _controllersSales[index]!['address'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                maxLines: 2,
                                              )
                                            : Text(
                                                record['address']?.toString() ?? 'N/A',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 150,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['product_name'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['product_name']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 100,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['quantity'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['quantity']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['amount_received'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                              ),
                                            )
                                          : Text('₹${_parseDecimal(record['amount_received']).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersSales.containsKey(index)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _controllersSales[index]!['credit_amount'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                              ),
                                            )
                                          : Text('₹${_parseDecimal(record['credit_amount']).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${amountPending.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: amountPending > 0 ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                                  tooltip: 'Save',
                                                  onPressed: () => _saveSalesRecord(index),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                  tooltip: 'Cancel',
                                                  onPressed: () => _toggleEditModeSales(index),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                  tooltip: 'Edit',
                                                  onPressed: () => _toggleEditModeSales(index),
                                                ),
                                                if (widget.isMainAdmin)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    tooltip: 'Delete',
                                                    onPressed: () => _deleteSalesRecord(index),
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
        ),
        // Add Sales Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoadingSales ? null : _showAddSalesDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Sales Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditDetailsTab() {
    return Column(
      children: [
        // Header and Search Bar
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Employees with Outstanding Credit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) {
                  return TextField(
                    controller: _creditSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Name or Address',
                      hintText: 'Enter name or address to search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _creditSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _creditSearchController.clear();
                                _filterCreditData('');
                                setState(() {}); // Update UI to hide clear button
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      _filterCreditData(value);
                      setState(() {}); // Update UI to show/hide clear button
                    },
                  );
                },
              ),
            ],
          ),
        ),
        // Credit Table
        Expanded(
          child: _isLoadingCredit
              ? const Center(child: CircularProgressIndicator())
              : _filteredCreditData.isEmpty
                  ? const Center(
                      child: Text(
                        'No employees with outstanding credit',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DataTable(
                              columnSpacing: 20,
                              columns: [
                                if (widget.selectedSector == null && _isAdmin)
                                  DataColumn(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: Icon(
                                            _creditSectorSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _creditSectorSortAscending = !_creditSectorSortAscending;
                                              _filteredCreditData.sort((a, b) {
                                                final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                                final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                                return _creditSectorSortAscending
                                                    ? aName.compareTo(bName)
                                                    : bName.compareTo(aName);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Pending', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Credit Taken Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: Icon(
                                          _creditDateSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _creditDateSortAscending = !_creditDateSortAscending;
                                            _sortCreditData();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const DataColumn(label: Text('Balance Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Balance Paid Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Overall Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _filteredCreditData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final record = entry.value;
                                final recordId = record['id'] as int;
                                final amountPending = _parseDecimal(record['amount_pending']);
                                final saleDateRaw = record['sale_date'];
                                final saleDateFormatted = _formatDate(saleDateRaw);
                                
                                // Debug log for first few records
                                if (index < 3) {
                                  debugPrint('Credit Details Row $index - Name: ${record['name']}, sale_date (raw): $saleDateRaw, formatted: $saleDateFormatted');
                                }

                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null && _isAdmin)
                                      DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                    DataCell(Text(record['name']?.toString() ?? '')),
                                    DataCell(Text(record['contact_number']?.toString() ?? 'N/A')),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          record['address']?.toString() ?? 'N/A',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(record['product_name']?.toString() ?? '')),
                                    DataCell(Text(record['quantity']?.toString() ?? '')),
                                    DataCell(
                                      Text(
                                        '₹${amountPending.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(saleDateFormatted)),
                                    // Balance Paid - editable when in edit mode
                                    DataCell(
                                      _editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _balancePaidControllers[recordId],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                                onChanged: (value) {
                                                  // Update Overall Balance in real-time
                                                  setState(() {});
                                                },
                                              ),
                                            )
                                          : Text('₹${_parseDecimal(record['balance_paid']).toStringAsFixed(2)}'),
                                    ),
                                    // Balance Paid Date - editable when in edit mode
                                    DataCell(
                                      _editModeCredit[recordId] == true
                                          ? InkWell(
                                              onTap: () async {
                                                final selectedDate = await showDatePicker(
                                                  context: context,
                                                  initialDate: _balancePaidDates[recordId] ?? DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                                if (selectedDate != null) {
                                                  setState(() {
                                                    _balancePaidDates[recordId] = selectedDate;
                                                  });
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _balancePaidDates[recordId] != null
                                                          ? _formatDate(_balancePaidDates[recordId])
                                                          : 'Select Date',
                                                      style: TextStyle(
                                                        color: _balancePaidDates[recordId] != null ? Colors.black : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Text(
                                              record['balance_paid_date'] != null
                                                  ? _formatDate(record['balance_paid_date'])
                                                  : 'N/A',
                                            ),
                                    ),
                                    // Overall Balance = Amount Pending - Balance Paid
                                    DataCell(
                                      Builder(
                                        builder: (context) {
                                          final balancePaid = _editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId)
                                              ? _parseDecimal(_balancePaidControllers[recordId]!.text)
                                              : _parseDecimal(record['balance_paid']);
                                          final overallBalance = amountPending - balancePaid;
                                          return Text(
                                            '₹${overallBalance.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: overallBalance > 0 ? Colors.red : Colors.green,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Action - Edit/Save/Delete buttons
                                    DataCell(
                                      _editModeCredit[recordId] == true
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                                  tooltip: 'Save',
                                                  onPressed: () => _saveCreditRecord(recordId),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                  tooltip: 'Cancel',
                                                  onPressed: () => _toggleEditModeCredit(recordId),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                  tooltip: 'Edit',
                                                  onPressed: () => _toggleEditModeCredit(recordId),
                                                ),
                                                // Delete button - only visible for abinaya (isMainAdmin)
                                                if (widget.isMainAdmin)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    tooltip: 'Delete',
                                                    onPressed: () => _deleteCreditRecord(recordId, record['name']?.toString() ?? 'Unknown'),
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
        ),
      ],
    );
  }
}

