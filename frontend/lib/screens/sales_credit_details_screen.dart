import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../utils/ui_helpers.dart';
import '../utils/pdf_generator.dart';
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
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _salesData = [];
  bool _isLoadingSales = false;
  bool _isGeneratingPDF = false;
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
  final Map<int, TextEditingController> _balancePaidControllers = {}; // Controllers for Balance Paid field (key = record ID or payment ID)
  final Map<int, DateTime?> _balancePaidDates = {}; // Selected dates for Balance Paid Date (key = record ID or payment ID)
  final Map<int, TextEditingController> _detailsControllers = {}; // Controllers for Details field (key = record ID or payment ID)
  final Map<int, List<Map<String, dynamic>>> _balancePayments = {}; // Store balance payments for each credit record (key = sale_id)
  final Map<int, bool> _addingNewPayment = {}; // Track if a new payment row is being added (key = sale_id)
  final Map<String, TextEditingController> _newPaymentControllers = {}; // Controllers for new payment rows (key = "saleId_new")
  final Map<String, DateTime?> _newPaymentDates = {}; // Dates for new payment rows (key = "saleId_new")
  final Map<String, TextEditingController> _newPaymentDetailsControllers = {}; // Details controllers for new payment rows (key = "saleId_new")

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isAdmin = AuthService.isAdmin;
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
    for (var controller in _detailsControllers.values) {
      controller.dispose();
    }
    for (var controller in _newPaymentControllers.values) {
      controller.dispose();
    }
    for (var controller in _newPaymentDetailsControllers.values) {
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
    if (_selectedDate == null) return;

    setState(() => _isLoadingSales = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];

      
      final sales = await ApiService.getSalesDetails(
        sector: widget.selectedSector,
        date: dateStr, // Filter by exact date - only show records from this date
      );
      

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


      // Load balance payments for each credit record
      _balancePayments.clear();
      for (var credit in credits) {
        final creditId = credit['id'] as int;
        // Balance payments are already included in the response from backend
        _balancePayments[creditId] = List<Map<String, dynamic>>.from(credit['balance_payments'] ?? []);
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
        // Cancel edit mode - dispose controllers and clear date
        if (_balancePaidControllers.containsKey(recordId)) {
          _balancePaidControllers[recordId]!.dispose();
          _balancePaidControllers.remove(recordId);
        }
        if (_detailsControllers.containsKey(recordId)) {
          _detailsControllers[recordId]!.dispose();
          _detailsControllers.remove(recordId);
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
          // Initialize details controller
          _detailsControllers[recordId] = TextEditingController(
            text: record['details']?.toString() ?? '',
          );
          _editModeCredit[recordId] = true;
        }
      }
    });
  }

  double _calculateOverallBalance(int saleId, int? paymentIndex) {
    final record = _filteredCreditData.firstWhere(
      (r) => r['id'] == saleId,
      orElse: () => {},
    );
    if (record.isEmpty) return 0.0;
    
    final amountPending = _parseDecimal(record['amount_pending']);
    final payments = _balancePayments[saleId] ?? [];
    
    if (paymentIndex == null) {
      // Calculate for main row: Amount Pending - sum of all payments
      double totalPaid = 0;
      for (var payment in payments) {
        totalPaid += _parseDecimal(payment['balance_paid']);
      }
      return amountPending - totalPaid;
    } else {
      // Calculate for a specific payment row
      if (paymentIndex == 0) {
        // First payment: Amount Pending - this payment
        final payment = payments[paymentIndex];
        final balancePaid = _parseDecimal(payment['balance_paid']);
        return amountPending - balancePaid;
      } else {
        // Subsequent payments: previous overall_balance - this payment
        final prevPayment = payments[paymentIndex - 1];
        final prevOverallBalance = _parseDecimal(prevPayment['overall_balance']);
        final currentPayment = payments[paymentIndex];
        final balancePaid = _parseDecimal(currentPayment['balance_paid']);
        return prevOverallBalance - balancePaid;
      }
    }
  }

  Future<void> _saveCreditRecord(int recordId) async {
    // Find record by ID
    final record = _filteredCreditData.firstWhere(
      (r) => r['id'] == recordId,
      orElse: () => {},
    );
    
    if (record.isEmpty) {
      return;
    }

    // Get Balance Paid, Balance Paid Date, and Details from controllers
    final balancePaid = _balancePaidControllers.containsKey(recordId)
        ? _parseDecimal(_balancePaidControllers[recordId]!.text.trim())
        : 0.0;
    final balancePaidDate = _balancePaidDates[recordId];
    final details = _detailsControllers.containsKey(recordId)
        ? _detailsControllers[recordId]!.text.trim()
        : record['details']?.toString() ?? '';

    setState(() => _isLoadingCredit = true);

    try {
      // If this is the first payment, create a new payment record
      final payments = _balancePayments[recordId] ?? [];
      final amountPending = _parseDecimal(record['amount_pending']);
      
      if (payments.isEmpty && balancePaid > 0) {
        // Create first payment
        final overallBalance = amountPending - balancePaid;
        final payment = {
          'sale_id': recordId,
          'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };
        await ApiService.saveSalesBalancePayment(payment);
      } else if (payments.isNotEmpty && balancePaid > 0) {
        // Update the first payment with new values
        final firstPayment = payments.first;
        final firstPaymentId = firstPayment['id'] as int?;
        if (firstPaymentId != null) {
          final overallBalance = amountPending - balancePaid;
          final payment = {
            'id': firstPaymentId,
            'sale_id': recordId,
            'balance_paid': balancePaid,
            'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
            'details': details.isEmpty ? null : details,
            'overall_balance': overallBalance,
          };
          await ApiService.saveSalesBalancePayment(payment);
        }
      }
      
      // Exit edit mode after save
      _editModeCredit[recordId] = false;

      // Reload credit data to reflect changes
      await _loadCreditData();

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, 'Details updated successfully');
      }
    } catch (e) {
      debugPrint('Error saving credit record: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error saving details: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  Future<void> _savePaymentRow(int saleId, int? paymentId) async {
    setState(() => _isLoadingCredit = true);

    try {
      final record = _filteredCreditData.firstWhere(
        (r) => r['id'] == saleId,
        orElse: () => {},
      );
      if (record.isEmpty) return;

      final amountPending = _parseDecimal(record['amount_pending']);
      final payments = _balancePayments[saleId] ?? [];
      
      double balancePaid;
      DateTime? balancePaidDate;
      String details;
      double overallBalance;

      if (paymentId == null) {
        // Saving a new payment row
        final key = '${saleId}_new';
        balancePaid = _parseDecimal(_newPaymentControllers[key]?.text ?? '0');
        balancePaidDate = _newPaymentDates[key];
        details = _newPaymentDetailsControllers.containsKey(key)
            ? _newPaymentDetailsControllers[key]!.text.trim()
            : '';
        
        // Calculate overall balance: previous overall balance - this payment
        if (payments.isEmpty) {
          // First payment: Amount Pending - this payment
          overallBalance = amountPending - balancePaid;
        } else {
          // Subsequent payment: last payment's overall_balance - this payment
          final lastPayment = payments.last;
          final lastOverallBalance = _parseDecimal(lastPayment['overall_balance']);
          overallBalance = lastOverallBalance - balancePaid;
        }

        final payment = {
          'sale_id': saleId,
          'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };

        await ApiService.saveSalesBalancePayment(payment);
        _cancelNewPaymentRow(saleId);
      } else {
        // Updating an existing payment row
        final key = paymentId;
        balancePaid = _balancePaidControllers.containsKey(key)
            ? _parseDecimal(_balancePaidControllers[key]!.text.trim())
            : _parseDecimal(payments.firstWhere((p) => p['id'] == paymentId)['balance_paid']);
        balancePaidDate = _balancePaidDates[key];
        details = _detailsControllers.containsKey(key)
            ? _detailsControllers[key]!.text.trim()
            : (payments.firstWhere((p) => p['id'] == paymentId)['details']?.toString() ?? '');

        // Find payment index
        final paymentIndex = payments.indexWhere((p) => p['id'] == paymentId);
        overallBalance = _calculateOverallBalance(saleId, paymentIndex);

        final payment = {
          'id': paymentId,
          'sale_id': saleId,
          'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };

        await ApiService.saveSalesBalancePayment(payment);
      }

      // Reload credit data to reflect changes
      await _loadCreditData();

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, 'Payment saved successfully');
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error saving payment: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  void _addNewPaymentRow(int saleId) {
    setState(() {
      _addingNewPayment[saleId] = true;
    });
  }

  void _cancelNewPaymentRow(int saleId) {
    setState(() {
      _addingNewPayment[saleId] = false;
      final key = '${saleId}_new';
      if (_newPaymentControllers.containsKey(key)) {
        _newPaymentControllers[key]!.dispose();
        _newPaymentControllers.remove(key);
      }
      if (_newPaymentDetailsControllers.containsKey(key)) {
        _newPaymentDetailsControllers[key]!.dispose();
        _newPaymentDetailsControllers.remove(key);
      }
      _newPaymentDates.remove(key);
    });
  }

  Future<void> _deletePaymentRow(int saleId, int paymentId) async {
    try {
      await ApiService.deleteSalesBalancePayment(paymentId);
      await _loadCreditData();
      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, 'Payment deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error deleting payment: ${e.toString()}');
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
  String _formatDate(dynamic dateValue) => FormatUtils.formatDateDisplay(dateValue);

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
      final newCreditAmount = _parseDecimal(controllers['credit_amount']!.text);
      final oldSaleDate = record['sale_date']?.toString().split('T')[0].split(' ')[0] ?? '';
      
      
      // ALWAYS use the selected date when saving - this becomes the Credit Taken Date
      // This ensures that if credit is added on 27/11, the Credit Taken Date shows 27/11
      final saleDateToUse = dateStr;
      
      
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

      final savedRecord = await ApiService.saveSalesDetails(updatedRecord);
      final savedSaleDate = savedRecord['sale_date']?.toString().split('T')[0].split(' ')[0] ?? 'N/A';
      
      if (savedSaleDate != saleDateToUse) {
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
      await _loadSalesData();
      await _loadCreditData();

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
        title: const Text('Sales and Credit details of Customer'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Sales Details'),
            Tab(text: 'Customer Credit Details'),
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
        // Header, Search Bar, Download Button and Notes
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer with outstanding credit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    flex: 2,
                    child: StatefulBuilder(
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
                  ),
                  const SizedBox(width: 12),
                  // Download Button
                  SizedBox(
                    width: 200,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPDF ? null : _downloadCurrentPageData,
                      icon: _isGeneratingPDF
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isGeneratingPDF ? 'Generating...' : 'Download Current Page Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notes Section (Compact)
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Downloads only searched/filtered data currently displayed on the page.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                        'No customers with outstanding credit',
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
                                const DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: () {
                                // First, generate all rows and calculate totals
                                final allRows = <DataRow>[];
                                double totalOverallBalance = 0.0;
                                
                                final rowsFromData = _filteredCreditData.expand((record) {
                                final recordId = record['id'] as int;
                                final amountPending = _parseDecimal(record['amount_pending']);
                                final saleDateRaw = record['sale_date'];
                                final saleDateFormatted = _formatDate(saleDateRaw);
                                final payments = _balancePayments[recordId] ?? [];
                                final isAddingNewPayment = _addingNewPayment[recordId] == true;

                                // Main row
                                final List<DataRow> rows = [];
                                
                                // Calculate overall balance for main row (Amount Pending - sum of all payments)
                                double totalPaid = 0;
                                for (var payment in payments) {
                                  totalPaid += _parseDecimal(payment['balance_paid']);
                                }
                                  double mainOverallBalance = amountPending - totalPaid;
                                  
                                  // If in edit mode, calculate based on controller value
                                  if (_editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId)) {
                                    mainOverallBalance = amountPending - _parseDecimal(_balancePaidControllers[recordId]!.text);
                                  }
                                  
                                  // Add to total overall balance (sum of all overall balances across all records)
                                  totalOverallBalance += mainOverallBalance;
                                
                                rows.add(DataRow(
                                  color: WidgetStateProperty.all(Colors.blue.shade200),
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
                                        style: const TextStyle(
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
                                                  labelText: 'Balance Paid',
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                ],
                                                onChanged: (value) {
                                                  setState(() {}); // Update Overall Balance in real-time
                                                },
                                              ),
                                            )
                                          : Text('₹${totalPaid.toStringAsFixed(2)}'),
                                    ),
                                    // Balance Paid Date - editable when in edit mode
                                    DataCell(
                                      _editModeCredit[recordId] == true && _balancePaidDates.containsKey(recordId)
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
                                                          ? FormatUtils.formatDateDisplay(_balancePaidDates[recordId])
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
                                              payments.isNotEmpty && payments.last['balance_paid_date'] != null
                                                  ? FormatUtils.formatDateDisplay(payments.last['balance_paid_date'])
                                                  : 'N/A',
                                            ),
                                    ),
                                    // Overall Balance - calculated (Amount Pending - Balance Paid)
                                    DataCell(
                                      Text(
                                        '₹${(_editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId))
                                            ? (amountPending - _parseDecimal(_balancePaidControllers[recordId]!.text)).toStringAsFixed(2)
                                            : mainOverallBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: (_editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId))
                                              ? ((amountPending - _parseDecimal(_balancePaidControllers[recordId]!.text)) > 0 ? Colors.red : Colors.green)
                                              : (mainOverallBalance > 0 ? Colors.red : Colors.green),
                                        ),
                                      ),
                                    ),
                                    // Details (editable)
                                    DataCell(
                                      _editModeCredit[recordId] == true && _detailsControllers.containsKey(recordId)
                                          ? SizedBox(
                                              width: 200,
                                              child: TextFormField(
                                                controller: _detailsControllers[recordId],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                maxLines: 2,
                                              ),
                                            )
                                          : Text(record['details']?.toString() ?? ''),
                                    ),
                                    // Action - Edit/Save/Add/Delete buttons
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
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add,
                                                    color: Colors.orange,
                                                    size: 20,
                                                  ),
                                                  tooltip: 'Add Payment',
                                                  onPressed: () => _addNewPaymentRow(recordId),
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
                                ));

                                // Add existing payment rows
                                for (int i = 0; i < payments.length; i++) {
                                  final payment = payments[i];
                                  final paymentId = payment['id'] as int;
                                  final paymentKey = paymentId;
                                  final isEditingPayment = _balancePaidControllers.containsKey(paymentKey);
                                  
                                  // Initialize controllers if editing
                                  if (isEditingPayment && !_balancePaidControllers.containsKey(paymentKey)) {
                                    _balancePaidControllers[paymentKey] = TextEditingController(
                                      text: _parseDecimal(payment['balance_paid']).toStringAsFixed(2),
                                    );
                                    _balancePaidDates[paymentKey] = FormatUtils.parseDate(payment['balance_paid_date']);
                                    _detailsControllers[paymentKey] = TextEditingController(
                                      text: payment['details']?.toString() ?? '',
                                    );
                                  }
                                  
                                  final balancePaid = isEditingPayment && _balancePaidControllers.containsKey(paymentKey)
                                      ? _parseDecimal(_balancePaidControllers[paymentKey]!.text)
                                      : _parseDecimal(payment['balance_paid']);
                                  
                                  // Calculate overall balance for this payment
                                  double paymentOverallBalance;
                                  if (i == 0) {
                                    paymentOverallBalance = amountPending - balancePaid;
                                  } else {
                                    final prevPayment = payments[i - 1];
                                    final prevOverallBalance = _parseDecimal(prevPayment['overall_balance']);
                                    paymentOverallBalance = prevOverallBalance - balancePaid;
                                  }
                                  
                                  rows.add(DataRow(
                                    cells: [
                                      // Sector (if visible)
                                      if (widget.selectedSector == null && _isAdmin)
                                        const DataCell(Text('')), // Empty cell
                                      // Name - empty
                                      const DataCell(Text('')),
                                      // Contact Number - empty
                                      const DataCell(Text('')),
                                      // Address - empty
                                      const DataCell(Text('')),
                                      // Product Name - empty
                                      const DataCell(Text('')),
                                      // Quantity - empty
                                      const DataCell(Text('')),
                                      // Amount Pending - empty
                                      const DataCell(Text('')),
                                      // Credit Taken Date - empty
                                      const DataCell(Text('')),
                                      // Balance Paid - show value or editable field
                                      DataCell(
                                        isEditingPayment && _balancePaidControllers.containsKey(paymentKey)
                                            ? SizedBox(
                                                width: 120,
                                                child: TextFormField(
                                                  controller: _balancePaidControllers[paymentKey],
                                                  decoration: const InputDecoration(
                                                    labelText: 'Balance Paid',
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {});
                                                  },
                                                ),
                                              )
                                            : Text('₹${_parseDecimal(payment['balance_paid']).toStringAsFixed(2)}'),
                                      ),
                                      // Balance Paid Date - show value or editable field
                                      DataCell(
                                        isEditingPayment && _balancePaidDates.containsKey(paymentKey)
                                            ? InkWell(
                                                onTap: () async {
                                                  final selectedDate = await showDatePicker(
                                                    context: context,
                                                    initialDate: _balancePaidDates[paymentKey] ?? DateTime.now(),
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                                  if (selectedDate != null) {
                                                    setState(() {
                                                      _balancePaidDates[paymentKey] = selectedDate;
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
                                                        _balancePaidDates[paymentKey] != null
                                                            ? FormatUtils.formatDateDisplay(_balancePaidDates[paymentKey])
                                                            : 'Select Date',
                                                        style: TextStyle(
                                                          color: _balancePaidDates[paymentKey] != null ? Colors.black : Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                payment['balance_paid_date'] != null
                                                    ? FormatUtils.formatDateDisplay(payment['balance_paid_date'])
                                                    : 'N/A',
                                              ),
                                      ),
                                      // Overall Balance - calculated (NOT editable)
                                      DataCell(
                                        Text(
                                          '₹${paymentOverallBalance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: paymentOverallBalance > 0 ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ),
                                      // Details - show value or editable field
                                      DataCell(
                                        isEditingPayment && _detailsControllers.containsKey(paymentKey)
                                            ? SizedBox(
                                                width: 200,
                                                child: TextFormField(
                                                  controller: _detailsControllers[paymentKey],
                                                  decoration: const InputDecoration(
                                                    labelText: 'Details',
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                              )
                                            : Text(payment['details']?.toString() ?? ''),
                                      ),
                                      // Action - Edit/Save/Delete buttons
                                      DataCell(
                                        isEditingPayment
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                                    tooltip: 'Save Payment',
                                                    onPressed: () => _savePaymentRow(recordId, paymentId),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                    tooltip: 'Cancel',
                                                    onPressed: () {
                                                      setState(() {
                                                        if (_balancePaidControllers.containsKey(paymentKey)) {
                                                          _balancePaidControllers[paymentKey]!.dispose();
                                                          _balancePaidControllers.remove(paymentKey);
                                                        }
                                                        _balancePaidDates.remove(paymentKey);
                                                        if (_detailsControllers.containsKey(paymentKey)) {
                                                          _detailsControllers[paymentKey]!.dispose();
                                                          _detailsControllers.remove(paymentKey);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    tooltip: 'Edit Payment',
                                                    onPressed: () {
                                                      setState(() {
                                                        _balancePaidControllers[paymentKey] = TextEditingController(
                                                          text: _parseDecimal(payment['balance_paid']).toStringAsFixed(2),
                                                        );
                                                        _balancePaidDates[paymentKey] = FormatUtils.parseDate(payment['balance_paid_date']);
                                                        _detailsControllers[paymentKey] = TextEditingController(
                                                          text: payment['details']?.toString() ?? '',
                                                        );
                                                      });
                                                    },
                                                  ),
                                                  if (widget.isMainAdmin)
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                      tooltip: 'Delete Payment',
                                                      onPressed: () async {
                                                        final confirmed = await UIHelpers.showDeleteConfirmationDialog(
                                                          context: context,
                                                          itemName: 'payment',
                                                        );
                                                        if (confirmed == true) {
                                                          await _deletePaymentRow(recordId, paymentId);
                                                        }
                                                      },
                                                    ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ));
                                }
                                
                                // Add new payment row if adding
                                if (isAddingNewPayment) {
                                  final newKey = '${recordId}_new';
                                  final newPaymentController = _newPaymentControllers[newKey] ?? TextEditingController();
                                  final newPaymentDate = _newPaymentDates[newKey];
                                  final newDetailsController = _newPaymentDetailsControllers[newKey] ?? TextEditingController();
                                  
                                  rows.add(DataRow(
                                    cells: [
                                      if (widget.selectedSector == null && _isAdmin)
                                        const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      // Balance Paid - editable
                                      DataCell(
                                        SizedBox(
                                          width: 120,
                                          child: TextFormField(
                                            controller: newPaymentController,
                                            decoration: const InputDecoration(
                                              labelText: 'Balance Paid',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                            ],
                                            onChanged: (value) {
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ),
                                      // Balance Paid Date - editable
                                      DataCell(
                                        InkWell(
                                          onTap: () async {
                                            final selectedDate = await showDatePicker(
                                              context: context,
                                              initialDate: newPaymentDate ?? DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (selectedDate != null) {
                                              setState(() {
                                                _newPaymentDates[newKey] = selectedDate;
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
                                                  newPaymentDate != null
                                                      ? FormatUtils.formatDateDisplay(newPaymentDate)
                                                      : 'Select Date',
                                                  style: TextStyle(
                                                    color: newPaymentDate != null ? Colors.black : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Overall Balance - empty (not displayed in new payment row)
                                      const DataCell(SizedBox.shrink()),
                                      // Details - editable
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: TextFormField(
                                            controller: newDetailsController,
                                            decoration: const InputDecoration(
                                              labelText: 'Details',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            maxLines: 2,
                                          ),
                                        ),
                                      ),
                                      // Action - Save/Cancel buttons
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                              tooltip: 'Save Payment',
                                              onPressed: () => _savePaymentRow(recordId, null),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                              tooltip: 'Cancel',
                                              onPressed: () => _cancelNewPaymentRow(recordId),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ));
                                  
                                  // Store controllers if not already stored
                                  if (!_newPaymentControllers.containsKey(newKey)) {
                                    _newPaymentControllers[newKey] = newPaymentController;
                                  }
                                  if (!_newPaymentDetailsControllers.containsKey(newKey)) {
                                    _newPaymentDetailsControllers[newKey] = newDetailsController;
                                  }
                                }
                                
                                return rows;
                                }).toList();
                                
                                // Add all data rows
                                allRows.addAll(rowsFromData);
                                
                                // Add total row at the end
                                if (_filteredCreditData.isNotEmpty) {
                                  allRows.add(DataRow(
                                    color: WidgetStateProperty.all(Colors.blue.shade50),
                                    cells: [
                                      // Sector (if visible)
                                      if (widget.selectedSector == null && _isAdmin)
                                        const DataCell(Text('')),
                                      // Name
                                      const DataCell(
                                        Text(
                                          'TOTAL',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                            ),
                          ),
                        ),
                                      // Contact Number - empty
                                      const DataCell(Text('')),
                                      // Address - empty
                                      const DataCell(Text('')),
                                      // Product Name - empty
                                      const DataCell(Text('')),
                                      // Quantity - empty
                                      const DataCell(Text('')),
                                      // Amount Pending - empty
                                      const DataCell(Text('')),
                                      // Credit Taken Date - empty
                                      const DataCell(Text('')),
                                      // Balance Paid - empty
                                      const DataCell(Text('')),
                                      // Balance Paid Date - empty
                                      const DataCell(Text('')),
                                      // Overall Balance - Total
                                      DataCell(
                                        Text(
                                          '₹${totalOverallBalance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: totalOverallBalance > 0 ? Colors.red : Colors.green,
                      ),
                    ),
        ),
                                      // Details - empty
                                      const DataCell(Text('')),
                                      // Action - empty
                                      const DataCell(Text('')),
                                    ],
                                  ));
                                }
                                
                                return allRows;
                              }(),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _downloadCurrentPageData() async {
    if (_filteredCreditData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show filename input dialog
    final fileNameController = TextEditingController();
    final fileName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter File Name'),
          content: TextField(
            controller: fileNameController,
            decoration: const InputDecoration(
              labelText: 'File Name',
              hintText: 'Enter file name (without .pdf)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (fileNameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(fileNameController.text.trim());
                }
              },
              child: const Text('Download PDF'),
            ),
          ],
        );
      },
    );

    if (fileName == null || fileName.isEmpty) {
      return; // User cancelled
    }

    setState(() => _isGeneratingPDF = true);

    try {
      // Use all current filtered data - if empty, use all credit data
      // This ensures we always download the data that's visible on the page
      final filteredData = _filteredCreditData.isNotEmpty ? _filteredCreditData : _creditData;

      if (filteredData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data available to download. Filtered: ${_filteredCreditData.length}, All: ${_creditData.length}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isGeneratingPDF = false);
        return;
      }

      print('Download: Using ${filteredData.length} records for PDF');

      // Collect all data including payment rows and calculate total
      final List<Map<String, dynamic>> allRowsForPDF = [];
      double totalOverallBalance = 0.0;

      for (var record in filteredData) {
        final recordId = record['id'] as int;
        final amountPending = _parseDecimal(record['amount_pending']);
        final payments = _balancePayments[recordId] ?? [];
        final isAddingNewPayment = _addingNewPayment[recordId] == true;

        // Calculate total paid from existing payments
        double totalPaid = 0;
        for (var payment in payments) {
          totalPaid += _parseDecimal(payment['balance_paid']);
        }

        // Add new payment if being added
        if (isAddingNewPayment) {
          final newKey = '${recordId}_new';
          final newPaymentController = _newPaymentControllers[newKey];
          if (newPaymentController != null && newPaymentController.text.isNotEmpty) {
            totalPaid += _parseDecimal(newPaymentController.text);
          }
        }

        final mainOverallBalance = amountPending - totalPaid;
        totalOverallBalance += mainOverallBalance;

        // Add main row
        allRowsForPDF.add({
          'type': 'main',
          'sale_date': record['sale_date'],
          'name': record['name']?.toString() ?? '',
          'product_name': record['product_name']?.toString() ?? '',
          'credit_amount': amountPending,
          'balance_paid': totalPaid,
          'balance_paid_date': payments.isNotEmpty && payments.last['balance_paid_date'] != null 
              ? payments.last['balance_paid_date'] 
              : null,
          'overall_balance': mainOverallBalance,
          'details': record['details']?.toString() ?? '',
        });

        // Add payment rows
        for (int i = 0; i < payments.length; i++) {
          final payment = payments[i];
          final balancePaid = _parseDecimal(payment['balance_paid']);
          
          // Calculate overall balance for this payment
          double paymentOverallBalance;
          if (i == 0) {
            paymentOverallBalance = amountPending - balancePaid;
          } else {
            final prevPayment = payments[i - 1];
            final prevOverallBalance = _parseDecimal(prevPayment['overall_balance']);
            paymentOverallBalance = prevOverallBalance - balancePaid;
          }

          allRowsForPDF.add({
            'type': 'payment',
            'sale_date': null,
            'name': '',
            'product_name': '',
            'credit_amount': null,
            'balance_paid': balancePaid,
            'balance_paid_date': payment['balance_paid_date'],
            'overall_balance': paymentOverallBalance,
            'details': payment['details']?.toString() ?? '',
          });
        }

        // Add new payment row if being added
        if (isAddingNewPayment) {
          final newKey = '${recordId}_new';
          final newPaymentController = _newPaymentControllers[newKey];
          final newPaymentDate = _newPaymentDates[newKey];
          final newDetailsController = _newPaymentDetailsControllers[newKey];

          if (newPaymentController != null && newPaymentController.text.isNotEmpty) {
            final newBalancePaid = _parseDecimal(newPaymentController.text);
            final prevOverallBalance = payments.isNotEmpty 
                ? _parseDecimal(payments.last['overall_balance'])
                : mainOverallBalance;
            final newPaymentOverallBalance = prevOverallBalance - newBalancePaid;

            allRowsForPDF.add({
              'type': 'payment',
              'sale_date': null,
              'name': '',
              'product_name': '',
              'credit_amount': null,
              'balance_paid': newBalancePaid,
              'balance_paid_date': newPaymentDate,
              'overall_balance': newPaymentOverallBalance,
              'details': newDetailsController?.text ?? '',
            });
          }
        }
      }

      // Add total row
      allRowsForPDF.add({
        'type': 'total',
        'sale_date': null,
        'name': 'TOTAL',
        'product_name': null,
        'credit_amount': null,
        'balance_paid': null,
        'balance_paid_date': null,
        'overall_balance': totalOverallBalance,
        'details': null,
      });

      print('Download: Total rows collected for PDF: ${allRowsForPDF.length}');
      if (allRowsForPDF.isNotEmpty) {
        print('Download: First row type: ${allRowsForPDF.first['type']}');
      }

      await PdfGenerator.generateCustomerCreditDetailsPDF(
        creditData: allRowsForPDF,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF saved successfully to Downloads folder'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPDF = false);
      }
    }
  }
}

