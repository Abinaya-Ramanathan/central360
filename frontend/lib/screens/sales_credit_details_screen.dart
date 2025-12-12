import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../utils/ui_helpers.dart';
import '../utils/pdf_generator.dart';
import '../config/env_config.dart';
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
  final Map<int, bool> _editModeSales = {};
  final Map<int, Map<String, TextEditingController>> _controllersSales = {};
  final Map<int, bool> _companyStaffValues = {}; // Store company_staff values for editing
  bool _salesSectorSortAscending = true; // Sort direction for Sector column in Sales Details
  
  // Customer Credit Details Tab State
  List<Map<String, dynamic>> _creditData = [];
  List<Map<String, dynamic>> _filteredCreditData = [];
  bool _isLoadingCredit = false;
  final TextEditingController _creditSearchController = TextEditingController();
  bool _creditDateSortAscending = true; // true = ascending (oldest first), false = descending (newest first)
  bool _creditSectorSortAscending = true; // Sort direction for Sector column in Credit Details
  String? _selectedCompanyStaffFilterCredit; // null, 'true', or 'false' for Customer Credit Details tab
  DateTime? _fromDateCredit; // From date for Sales Credit Details filter
  DateTime? _toDateCredit; // To date for Sales Credit Details filter
  final Map<int, bool> _editModeCredit = {}; // Track which rows are in edit mode (key = record ID)
  final Map<int, TextEditingController> _balancePaidControllers = {}; // Controllers for Balance Paid field (key = record ID or payment ID)
  final Map<int, DateTime?> _balancePaidDates = {}; // Selected dates for Balance Paid Date (key = record ID or payment ID)
  final Map<int, TextEditingController> _detailsControllers = {}; // Controllers for Details field (key = record ID or payment ID)
  final Map<int, List<Map<String, dynamic>>> _balancePayments = {}; // Store balance payments for each credit record (key = sale_id)
  final Map<int, bool> _addingNewPayment = {}; // Track if a new payment row is being added (key = sale_id)
  final Map<String, TextEditingController> _newPaymentControllers = {}; // Controllers for new payment rows (key = "saleId_new")
  final Map<String, DateTime?> _newPaymentDates = {}; // Dates for new payment rows (key = "saleId_new")
  final Map<String, TextEditingController> _newPaymentDetailsControllers = {}; // Details controllers for new payment rows (key = "saleId_new")
  
  // Purchase Details Tab State
  DateTime? _selectedDatePurchase; // Separate date for purchase details
  List<Map<String, dynamic>> _purchaseData = [];
  bool _isLoadingPurchase = false;
  final Map<int, bool> _editModePurchase = {};
  final Map<int, Map<String, TextEditingController>> _controllersPurchase = {};
  final Map<int, List<Map<String, dynamic>>> _purchasePhotos = {}; // Store photos for each purchase
  final ImagePicker _imagePicker = ImagePicker();
  bool _purchasesSectorSortAscending = true; // Sort direction for Sector column in Purchase Details
  
  // Company Credit Details Tab State (from purchases)
  List<Map<String, dynamic>> _companyCreditData = [];
  List<Map<String, dynamic>> _filteredCompanyCreditData = [];
  bool _isLoadingCompanyCredit = false;
  final TextEditingController _companyCreditSearchController = TextEditingController();
  DateTime? _fromDateCompanyCredit; // From date for Purchase Credit Details filter
  DateTime? _toDateCompanyCredit; // To date for Purchase Credit Details filter
  bool _companyCreditDateSortAscending = true; // true = ascending (oldest first), false = descending (newest first)
  bool _companyCreditSectorSortAscending = true; // Sort direction for Sector column in Company Credit Details
  final Map<int, bool> _editModeCompanyCredit = {}; // Track which rows are in edit mode (key = record ID)
  final Map<int, TextEditingController> _companyBalancePaidControllers = {}; // Controllers for Balance Paid field (key = record ID or payment ID)
  final Map<int, DateTime?> _companyBalancePaidDates = {}; // Selected dates for Balance Paid Date (key = record ID or payment ID)
  final Map<int, TextEditingController> _companyDetailsControllers = {}; // Controllers for Details field (key = record ID or payment ID)
  final Map<int, List<Map<String, dynamic>>> _companyCreditPhotos = {}; // Store photos for credit records
  final Map<int, List<Map<String, dynamic>>> _companyBalancePayments = {}; // Store balance payments for each credit record (key = purchase_id)
  final Map<int, bool> _addingNewCompanyPayment = {}; // Track if a new payment row is being added (key = purchase_id)
  final Map<String, TextEditingController> _newCompanyPaymentControllers = {}; // Controllers for new payment rows (key = "purchaseId_new")
  final Map<String, DateTime?> _newCompanyPaymentDates = {}; // Dates for new payment rows (key = "purchaseId_new")
  final Map<String, TextEditingController> _newCompanyPaymentDetailsControllers = {}; // Details controllers for new payment rows (key = "purchaseId_new")
  
  // Overall Summary Tab State
  DateTime? _fromDate;
  DateTime? _toDate;
  List<Map<String, dynamic>> _allSalesDataForSummary = [];
  List<Map<String, dynamic>> _allPurchaseDataForSummary = [];
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _isAdmin = AuthService.isAdmin;
    _selectedDate = DateTime.now();
    _selectedDatePurchase = DateTime.now();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _fromDateCredit = DateTime.now();
    _toDateCredit = DateTime.now();
    _fromDateCompanyCredit = DateTime.now();
    _toDateCompanyCredit = DateTime.now();
    _loadSectors();
    _loadSalesData();
    _loadCreditData();
    _loadPurchaseData();
    _loadCompanyCreditData();
    
    // Reload data when switching tabs
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _loadSalesData(); // Sales Details - reload when switching to this tab
        } else if (_tabController.index == 1) {
          _loadCreditData(); // Sales Credit Details
        } else if (_tabController.index == 2) {
          _loadPurchaseData(); // Purchase Details
        } else if (_tabController.index == 3) {
          _loadCompanyCreditData(); // Purchase Credit Details
        } else if (_tabController.index == 4) {
          // Overall Summary tab - load all data for date range filtering
          _loadAllDataForSummary();
        }
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
    // Purchase Details cleanup
    for (var controllers in _controllersPurchase.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    // Company Credit Details cleanup
    _companyCreditSearchController.dispose();
    for (var controller in _companyBalancePaidControllers.values) {
      controller.dispose();
    }
    for (var controller in _companyDetailsControllers.values) {
      controller.dispose();
    }
    for (var controller in _newCompanyPaymentControllers.values) {
      controller.dispose();
    }
    for (var controller in _newCompanyPaymentDetailsControllers.values) {
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

  Future<void> _selectFromDateCredit() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDateCredit ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDateCredit = picked;
      });
      _filterCreditData(_creditSearchController.text);
    }
  }

  Future<void> _selectToDateCredit() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDateCredit ?? (_fromDateCredit ?? DateTime.now()),
      firstDate: _fromDateCredit ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDateCredit = picked;
      });
      _filterCreditData(_creditSearchController.text);
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
      // For multiple months, we'll filter on the frontend
      // since the backend only supports single month filter
      // Pass null to backend when multiple months are selected, filter locally instead
      String? monthFilter; // Always pass null, filter on frontend for multiple months
      
      final credits = await ApiService.getCreditDetailsFromSales(
        sector: widget.selectedSector,
        companyStaff: _selectedCompanyStaffFilterCredit,
        month: monthFilter,
      );
      
      // Load balance payments for each credit record (use original credits, not filtered)
      _balancePayments.clear();
      for (var credit in credits) {
        final creditId = credit['id'] as int;
        // Balance payments are already included in the response from backend
        _balancePayments[creditId] = List<Map<String, dynamic>>.from(credit['balance_payments'] ?? []);
      }

      setState(() {
        // Store all credits (with company staff filter applied from backend) in _creditData
        _creditData = List.from(credits);
        
        // Apply all filters (date range, search) to get the final filtered data
        // Start with the data that already has company staff filter applied
        List<Map<String, dynamic>> finalFiltered = List.from(credits);
        
        // Apply date range filter if dates are selected
        if (_fromDateCredit != null || _toDateCredit != null) {
          finalFiltered = finalFiltered.where((record) {
            final saleDate = _parseDateFromRecord(record['sale_date']);
            if (saleDate == null) return false;
            
            final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
            final fromDateOnly = _fromDateCredit != null ? DateTime(_fromDateCredit!.year, _fromDateCredit!.month, _fromDateCredit!.day) : null;
            final toDateOnly = _toDateCredit != null ? DateTime(_toDateCredit!.year, _toDateCredit!.month, _toDateCredit!.day) : null;
            
            if (fromDateOnly != null && saleDateOnly.isBefore(fromDateOnly)) return false;
            if (toDateOnly != null && saleDateOnly.isAfter(toDateOnly)) return false;
            return true;
          }).toList();
        }
        
        // Apply search filter if search query exists
        if (_creditSearchController.text.isNotEmpty) {
          final searchQuery = _creditSearchController.text.toLowerCase();
          finalFiltered = finalFiltered.where((record) {
            final name = (record['name']?.toString() ?? '').toLowerCase();
            final address = (record['address']?.toString() ?? '').toLowerCase();
            return name.contains(searchQuery) || address.contains(searchQuery);
          }).toList();
        }
        
        _filteredCreditData = finalFiltered;
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
      List<Map<String, dynamic>> filtered = List.from(_creditData);
      
      // Apply date range filter if dates are selected
      if (_fromDateCredit != null || _toDateCredit != null) {
        filtered = filtered.where((record) {
          final saleDate = _parseDateFromRecord(record['sale_date']);
          if (saleDate == null) return false;
          
          final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
          final fromDateOnly = _fromDateCredit != null ? DateTime(_fromDateCredit!.year, _fromDateCredit!.month, _fromDateCredit!.day) : null;
          final toDateOnly = _toDateCredit != null ? DateTime(_toDateCredit!.year, _toDateCredit!.month, _toDateCredit!.day) : null;
          
          if (fromDateOnly != null && saleDateOnly.isBefore(fromDateOnly)) return false;
          if (toDateOnly != null && saleDateOnly.isAfter(toDateOnly)) return false;
          return true;
        }).toList();
      }
      
      // Apply search filter
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        filtered = filtered.where((record) {
          final name = (record['name']?.toString() ?? '').toLowerCase();
          final address = (record['address']?.toString() ?? '').toLowerCase();
          return name.contains(searchQuery) || address.contains(searchQuery);
        }).toList();
      }
      
      _filteredCreditData = filtered;
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
    bool companyStaff = false; // Default to No

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Sales Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                initialValue: companyStaff,
                decoration: const InputDecoration(
                  labelText: 'Company Staff',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<bool>(value: false, child: Text('No')),
                  DropdownMenuItem<bool>(value: true, child: Text('Yes')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    companyStaff = value ?? false;
                  });
                },
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
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
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
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
        ),
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
        companyStaff: companyStaff,
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
    required bool companyStaff,
  }) async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedDate == null) return;

    setState(() => _isLoadingSales = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      
      // All fields except sector_code and sale_date are optional
      final recordToSave = {
        'sector_code': widget.selectedSector ?? '',
        'name': name.isEmpty ? null : name,
        'contact_number': contact.isEmpty ? null : contact,
        'address': address.isEmpty ? null : address,
        'product_name': productName.isEmpty ? null : productName, // Optional field
        'quantity': quantity.isEmpty ? null : quantity, // Optional field
        'amount_received': amountReceived,
        'credit_amount': creditAmount,
        'sale_date': dateStr,
        'company_staff': companyStaff,
      };

      await ApiService.saveSalesDetails(recordToSave);
      
      // Add a small delay to ensure backend has committed the transaction
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload sales data to show the newly added record
      await _loadSalesData();
      
      // Also reload credit data as it might be affected
      await _loadCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sales details added successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
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
        _companyStaffValues.remove(index);
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
        // Store company_staff value for editing
        _companyStaffValues[index] = record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1;
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
    // All fields are optional - no validation required

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
        'name': controllers['name']!.text.trim().isEmpty ? null : controllers['name']!.text.trim(),
        'contact_number': controllers['contact_number']!.text.trim().isEmpty
            ? null
            : controllers['contact_number']!.text.trim(),
        'address': controllers['address']!.text.trim().isEmpty
            ? null
            : controllers['address']!.text.trim(),
        'product_name': controllers['product_name']!.text.trim().isEmpty ? null : controllers['product_name']!.text.trim(),
        'quantity': controllers['quantity']!.text.trim().isEmpty ? null : controllers['quantity']!.text.trim(),
        'amount_received': _parseDecimal(controllers['amount_received']!.text),
        'credit_amount': newCreditAmount,
        'sale_date': saleDateToUse, // Use selected date - this becomes the Credit Taken Date
        'company_staff': _companyStaffValues[index] ?? false,
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
        title: const Text('Sales Purchase and Credit Details'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Sales Details'),
            Tab(text: 'Sales Credit Details'),
            Tab(text: 'Purchase Details'),
            Tab(text: 'Purchase Credit Details'),
            Tab(text: 'Overall Summary'),
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
          // Sales Credit Details Tab
          _buildCreditDetailsTab(),
          // Purchase Details Tab
          _buildPurchaseDetailsTab(),
          // Purchase Credit Details Tab
          _buildCompanyCreditDetailsTab(),
          // Overall Income Expense and Credit Details Tab
          _buildOverallIncomeExpenseTab(),
        ],
      ),
    );
  }

  Widget _buildSalesDetailsTab() {
    return Column(
      children: [
        // Date Selection and Add Sales Button
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
              const SizedBox(width: 16),
              SizedBox(
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
                                const DataColumn(label: Text('Company Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Received', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Credit Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _salesData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final record = entry.value;
                                final isEditMode = _editModeSales[index] == true;

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
                                              width: 120,
                                              child: DropdownButton<bool>(
                                                value: _companyStaffValues[index] ?? (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1),
                                                isExpanded: true,
                                                items: const [
                                                  DropdownMenuItem<bool>(value: false, child: Text('No')),
                                                  DropdownMenuItem<bool>(value: true, child: Text('Yes')),
                                                ],
                                                onChanged: (value) {
                                                  setState(() {
                                                    _companyStaffValues[index] = value ?? false;
                                                  });
                                                },
                                              ),
                                            )
                                          : Text(
                                              (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? 'Yes' : 'No',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? Colors.green.shade700 : Colors.grey,
                                              ),
                                            ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer with outstanding credit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, size: 24),
                    tooltip: 'Download PDF',
                    onPressed: _isLoadingCredit ? null : _downloadCreditDetailsPDF,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Search Bar
                    SizedBox(
                      width: 250,
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
                  // Company Staff Filter
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedCompanyStaffFilterCredit,
                      decoration: InputDecoration(
                        labelText: 'Company Staff',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('All')),
                        DropdownMenuItem<String?>(value: 'true', child: Text('Yes')),
                        DropdownMenuItem<String?>(value: 'false', child: Text('No')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCompanyStaffFilterCredit = value;
                        });
                        _loadCreditData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // From Date Picker
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  SizedBox(
                        width: 160,
                    height: 56,
                        child: InkWell(
                          onTap: _selectFromDateCredit,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'From Date',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              _fromDateCredit != null
                                  ? _fromDateCredit!.toIso8601String().split('T')[0]
                                  : 'From Date',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      if (_fromDateCredit != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _fromDateCredit = null;
                            });
                            _filterCreditData(_creditSearchController.text);
                          },
                          tooltip: 'Clear From Date',
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // To Date Picker
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  SizedBox(
                        width: 160,
                        height: 56,
                        child: InkWell(
                          onTap: _selectToDateCredit,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'To Date',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              _toDateCredit != null
                                  ? _toDateCredit!.toIso8601String().split('T')[0]
                                  : 'To Date',
                              style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                      ),
                      if (_toDateCredit != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _toDateCredit = null;
                            });
                            _filterCreditData(_creditSearchController.text);
                          },
                          tooltip: 'Clear To Date',
                        ),
                    ],
                  ),
                  ],
                ),
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
                                const DataColumn(label: Text('Company Staff', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                    DataCell(
                                      Text(
                                        (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? 'Yes' : 'No',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? Colors.green.shade700 : Colors.grey,
                                        ),
                                      ),
                                    ),
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
                                      // Company Staff - empty
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
                                      const DataCell(Text('')), // Name
                                      const DataCell(Text('')), // Company Staff
                                      const DataCell(Text('')), // Contact Number
                                      const DataCell(Text('')), // Address
                                      const DataCell(Text('')), // Product Name
                                      const DataCell(Text('')), // Quantity
                                      const DataCell(Text('')), // Amount Pending
                                      const DataCell(Text('')), // Credit Taken Date
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
                                      // Company Staff - empty
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


  // ========== Purchase Details Methods ==========
  
  Future<void> _selectDatePurchase() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDatePurchase ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDatePurchase = picked;
      });
      _loadPurchaseData();
    }
  }

  Future<void> _loadPurchaseData() async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedDatePurchase == null) return;

    setState(() => _isLoadingPurchase = true);
    try {
      final dateStr = _selectedDatePurchase!.toIso8601String().split('T')[0];

      final purchases = await ApiService.getCompanyPurchaseDetails(
        sector: widget.selectedSector,
        date: dateStr,
      );
      
      if (purchases.isEmpty) {
        final allPurchases = await ApiService.getCompanyPurchaseDetails(
          sector: widget.selectedSector,
        );
        final filteredPurchases = allPurchases.where((p) {
          final purchaseDate = p['purchase_date']?.toString().split('T')[0].split(' ')[0] ?? '';
          return purchaseDate == dateStr;
        }).toList();
        if (filteredPurchases.isNotEmpty) {
          setState(() {
            _purchaseData = filteredPurchases;
            _editModePurchase.clear();
            for (var controllers in _controllersPurchase.values) {
              for (var controller in controllers.values) {
                controller.dispose();
              }
            }
            _controllersPurchase.clear();
            _purchasePhotos.clear();
            for (var purchase in filteredPurchases) {
              final purchaseId = purchase['id'];
              if (purchaseId != null) {
                _purchasePhotos[purchaseId] = List<Map<String, dynamic>>.from(purchase['photos'] ?? []);
              }
            }
          });
          return;
        }
      }

      setState(() {
        _purchaseData = purchases;
        _editModePurchase.clear();
        for (var controllers in _controllersPurchase.values) {
          for (var controller in controllers.values) {
            controller.dispose();
          }
        }
        _controllersPurchase.clear();
        _purchasePhotos.clear();
        for (var purchase in purchases) {
          final purchaseId = purchase['id'];
          if (purchaseId != null) {
            _purchasePhotos[purchaseId] = List<Map<String, dynamic>>.from(purchase['photos'] ?? []);
          }
        }
      });
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading purchases data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  Future<void> _showAddPurchaseDialog() async {
    if (widget.selectedSector == null && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector from Home page')),
      );
      return;
    }

    if (_selectedDatePurchase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    final itemNameController = TextEditingController();
    final shopNameController = TextEditingController();
    final purchaseDetailsController = TextEditingController();
    final purchaseAmountController = TextEditingController();
    final amountPaidController = TextEditingController();
    final creditController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Purchase Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemNameController,
            decoration: const InputDecoration(
                  labelText: 'Item Name',
              border: OutlineInputBorder(),
            ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: shopNameController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: purchaseDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: purchaseAmountController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountPaidController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: creditController,
                decoration: const InputDecoration(
                  labelText: 'Credit',
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
              itemNameController.dispose();
              shopNameController.dispose();
              purchaseDetailsController.dispose();
              purchaseAmountController.dispose();
              amountPaidController.dispose();
              creditController.dispose();
              Navigator.pop(context, false);
            },
              child: const Text('Cancel'),
            ),
          FilledButton(
              onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveNewPurchase(
        itemName: itemNameController.text.trim(),
        shopName: shopNameController.text.trim(),
        purchaseDetails: purchaseDetailsController.text.trim(),
        purchaseAmount: FormatUtils.parseDecimal(purchaseAmountController.text),
        amountPaid: FormatUtils.parseDecimal(amountPaidController.text),
        credit: FormatUtils.parseDecimal(creditController.text),
      );
    }

    itemNameController.dispose();
    shopNameController.dispose();
    purchaseDetailsController.dispose();
    purchaseAmountController.dispose();
    amountPaidController.dispose();
    creditController.dispose();
  }

  Future<void> _saveNewPurchase({
    required String itemName,
    required String shopName,
    required String purchaseDetails,
    required double purchaseAmount,
    required double amountPaid,
    required double credit,
  }) async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedDatePurchase == null) return;

    setState(() => _isLoadingPurchase = true);
    try {
      final dateStr = _selectedDatePurchase!.toIso8601String().split('T')[0];
      final record = {
        'sector_code': widget.selectedSector,
        'item_name': itemName.isEmpty ? null : itemName,
        'shop_name': shopName.isEmpty ? null : shopName,
        'purchase_details': purchaseDetails.isEmpty ? null : purchaseDetails,
        'purchase_amount': purchaseAmount,
        'amount_paid': amountPaid,
        'credit': credit,
        'purchase_date': dateStr,
      };

      await ApiService.saveCompanyPurchaseDetails(record);
      await _loadPurchaseData();
      await _loadCompanyCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase details added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding purchase details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  Future<void> _toggleEditModePurchase(int index) async {
    setState(() {
      if (_editModePurchase[index] == true) {
        if (_controllersPurchase.containsKey(index)) {
          for (var controller in _controllersPurchase[index]!.values) {
            controller.dispose();
          }
          _controllersPurchase.remove(index);
        }
        _editModePurchase[index] = false;
      } else {
        final record = _purchaseData[index];
        _controllersPurchase[index] = {
          'item_name': TextEditingController(text: record['item_name']?.toString() ?? ''),
          'shop_name': TextEditingController(text: record['shop_name']?.toString() ?? ''),
          'purchase_details': TextEditingController(text: record['purchase_details']?.toString() ?? ''),
          'purchase_amount': TextEditingController(text: FormatUtils.parseDecimal(record['purchase_amount']).toStringAsFixed(2)),
          'amount_paid': TextEditingController(text: FormatUtils.parseDecimal(record['amount_paid']).toStringAsFixed(2)),
          'credit': TextEditingController(text: FormatUtils.parseDecimal(record['credit']).toStringAsFixed(2)),
        };
        _editModePurchase[index] = true;
      }
    });
  }

  Future<void> _savePurchaseRecord(int index) async {
    final record = _purchaseData[index];
    final recordId = record['id'] as int?;
    if (recordId == null) return;

    setState(() => _isLoadingPurchase = true);
    try {
      final updatedRecord = {
        'id': recordId,
        'sector_code': widget.selectedSector,
        'item_name': _controllersPurchase[index]!['item_name']!.text.trim().isEmpty ? null : _controllersPurchase[index]!['item_name']!.text.trim(),
        'shop_name': _controllersPurchase[index]!['shop_name']!.text.trim().isEmpty ? null : _controllersPurchase[index]!['shop_name']!.text.trim(),
        'purchase_details': _controllersPurchase[index]!['purchase_details']!.text.trim().isEmpty ? null : _controllersPurchase[index]!['purchase_details']!.text.trim(),
        'purchase_amount': FormatUtils.parseDecimal(_controllersPurchase[index]!['purchase_amount']!.text),
        'amount_paid': FormatUtils.parseDecimal(_controllersPurchase[index]!['amount_paid']!.text),
        'credit': FormatUtils.parseDecimal(_controllersPurchase[index]!['credit']!.text),
        'purchase_date': _selectedDatePurchase!.toIso8601String().split('T')[0],
      };

      await ApiService.saveCompanyPurchaseDetails(updatedRecord);
      await _loadPurchaseData();
      await _loadCompanyCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase details saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving purchases details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  Future<void> _deletePurchaseRecord(int index) async {
    final record = _purchaseData[index];
    final recordId = record['id'] as int?;
    if (recordId == null) return;

    final confirmed = await UIHelpers.showDeleteConfirmationDialog(
      context: context,
      itemName: record['item_name']?.toString() ?? 'purchase',
    );

    if (confirmed != true) return;

    setState(() => _isLoadingPurchase = true);
    try {
      await ApiService.deleteCompanyPurchaseDetails(recordId.toString());
      await _loadPurchaseData();
      await _loadCompanyCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase record deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting purchase record: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '${EnvConfig.apiBaseUrl}$imageUrl';
  }

  Widget _buildPhotoCellPurchase(int purchaseId, List<Map<String, dynamic>> photos, bool isEditMode) {
    if (photos.isEmpty) {
      return const SizedBox(width: 150, height: 60, child: Center(child: Text('No images', style: TextStyle(fontSize: 12))));
    }
    
    return SizedBox(
      width: 150,
      height: 60,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...photos.map((photo) {
              final imageUrl = photo['image_url'] as String? ?? '';
              final photoId = photo['id'] as int?;
              final fullUrl = _getImageUrl(imageUrl);
              
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Stack(
                              children: [
                                Image.network(
                                  fullUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.broken_image, size: 50),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            fullUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30),
                          ),
                        ),
                      ),
                    ),
                    if (isEditMode && photoId != null)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: GestureDetector(
                          onTap: () => _deletePhotoPurchase(photoId, purchaseId),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhotosPurchase(int purchaseId) async {
    try {
      List<XFile> images = [];
      
      if (kIsWeb) {
        images = await _imagePicker.pickMultiImage();
      } else if (Platform.isAndroid || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        images = await _imagePicker.pickMultiImage();
      } else {
        images = await _imagePicker.pickMultiImage();
      }

      if (images.isEmpty) return;

      setState(() => _isLoadingPurchase = true);
      
      List<File> files = [];
      for (var xFile in images) {
        if (!kIsWeb) {
          files.add(File(xFile.path));
        }
      }

      if (files.isEmpty) {
        setState(() => _isLoadingPurchase = false);
        return;
      }

      final uploadedPhotos = await ApiService.uploadCompanyPurchasePhotos(
        purchaseId: purchaseId,
        photoFiles: files,
      );

      await _loadPurchaseData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${uploadedPhotos.length} photo(s) uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  Future<void> _deletePhotoPurchase(int photoId, int purchaseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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

    setState(() => _isLoadingPurchase = true);
    try {
      await ApiService.deleteCompanyPurchasePhoto(photoId);
      await _loadPurchaseData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  Widget _buildPurchaseDetailsTab() {
    return Column(
      children: [
        // Date Selection and Add Purchase Button
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDatePurchase,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedDatePurchase != null
                          ? _selectedDatePurchase!.toIso8601String().split('T')[0]
                          : 'Select Date',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingPurchase ? null : _showAddPurchaseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Purchase Details', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingPurchase
              ? const Center(child: CircularProgressIndicator())
              : _purchaseData.isEmpty
                  ? const Center(
                      child: Text(
                        'No purchases data available',
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
                                            _purchasesSectorSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _purchasesSectorSortAscending = !_purchasesSectorSortAscending;
                                              _purchaseData.sort((a, b) {
                                                final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                                final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                                return _purchasesSectorSortAscending
                                                    ? aName.compareTo(bName)
                                                    : bName.compareTo(aName);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Shop Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Purchase Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Bill Image', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _purchaseData.asMap().entries.map((entry) {
                                final index = entry.key;
                                final record = entry.value;
                                final isEditMode = _editModePurchase[index] == true;
                                final purchaseId = record['id'] as int?;
                                final photos = purchaseId != null ? (_purchasePhotos[purchaseId] ?? []) : <Map<String, dynamic>>[];

                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null && _isAdmin)
                                      DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                    DataCell(
                                      isEditMode && _controllersPurchase.containsKey(index)
                                          ? SizedBox(
                                              width: 150,
                                              child: TextFormField(
                                                controller: _controllersPurchase[index]!['item_name'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['item_name']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersPurchase.containsKey(index)
                                          ? SizedBox(
                                              width: 150,
                                              child: TextFormField(
                                                controller: _controllersPurchase[index]!['shop_name'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            )
                                          : Text(record['shop_name']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: isEditMode && _controllersPurchase.containsKey(index)
                                            ? TextFormField(
                                                controller: _controllersPurchase[index]!['purchase_details'],
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                maxLines: 2,
                                              )
                                            : Text(
                                                record['purchase_details']?.toString() ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersPurchase.containsKey(index)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _controllersPurchase[index]!['purchase_amount'],
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
                                          : Text('₹${FormatUtils.parseDecimal(record['purchase_amount']).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersPurchase.containsKey(index)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _controllersPurchase[index]!['amount_paid'],
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
                                          : Text('₹${FormatUtils.parseDecimal(record['amount_paid']).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      isEditMode && _controllersPurchase.containsKey(index)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextFormField(
                                                controller: _controllersPurchase[index]!['credit'],
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
                                          : Text('₹${FormatUtils.parseDecimal(record['credit']).toStringAsFixed(2)}'),
                                    ),
                                    DataCell(
                                      purchaseId != null
                                          ? ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 150,
                                                maxHeight: 60,
                                              ),
                                              child: _buildPhotoCellPurchase(purchaseId, photos, isEditMode),
                                            )
                                          : const SizedBox(width: 150, height: 60),
                                    ),
                                    DataCell(
                                      isEditMode
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.save, color: Colors.green, size: 20),
                                                  tooltip: 'Save',
                                                  onPressed: () => _savePurchaseRecord(index),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                  tooltip: 'Cancel',
                                                  onPressed: () => _toggleEditModePurchase(index),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                  tooltip: 'Edit',
                                                  onPressed: () => _toggleEditModePurchase(index),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.upload, color: Colors.orange, size: 20),
                                                  tooltip: 'Upload Photos',
                                                  onPressed: purchaseId != null ? () => _uploadPhotosPurchase(purchaseId) : null,
                                                ),
                                                if (widget.isMainAdmin)
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    tooltip: 'Delete',
                                                    onPressed: () => _deletePurchaseRecord(index),
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

  // ========== Company Credit Details Methods ==========
  
  Future<void> _loadCompanyCreditData() async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoadingCompanyCredit = true);
    try {
      final credits = await ApiService.getCreditDetailsFromCompanyPurchases(
        sector: widget.selectedSector,
      );

      setState(() {
        _companyCreditData = credits;
        _filteredCompanyCreditData = List.from(credits);
        _companyCreditPhotos.clear();
        _companyBalancePayments.clear();
        for (var credit in credits) {
          final creditId = credit['id'];
          if (creditId != null) {
            _companyCreditPhotos[creditId] = List<Map<String, dynamic>>.from(credit['photos'] ?? []);
            _companyBalancePayments[creditId] = List<Map<String, dynamic>>.from(credit['balance_payments'] ?? []);
          }
        }
        _sortCompanyCreditData();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading credit data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCompanyCredit = false);
      }
    }
  }

  void _filterCompanyCreditData(String query) {
    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_companyCreditData);
      
      // Apply date range filter if dates are selected
      if (_fromDateCompanyCredit != null || _toDateCompanyCredit != null) {
        filtered = filtered.where((record) {
          final purchaseDate = _parseDateFromRecord(record['purchase_date']);
          if (purchaseDate == null) return false;
          
          final purchaseDateOnly = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
          final fromDateOnly = _fromDateCompanyCredit != null ? DateTime(_fromDateCompanyCredit!.year, _fromDateCompanyCredit!.month, _fromDateCompanyCredit!.day) : null;
          final toDateOnly = _toDateCompanyCredit != null ? DateTime(_toDateCompanyCredit!.year, _toDateCompanyCredit!.month, _toDateCompanyCredit!.day) : null;
          
          if (fromDateOnly != null && purchaseDateOnly.isBefore(fromDateOnly)) return false;
          if (toDateOnly != null && purchaseDateOnly.isAfter(toDateOnly)) return false;
          return true;
        }).toList();
      }
      
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        filtered = filtered.where((record) {
          final itemName = (record['item_name']?.toString() ?? '').toLowerCase();
          final shopName = (record['shop_name']?.toString() ?? '').toLowerCase();
          return itemName.contains(searchQuery) || shopName.contains(searchQuery);
        }).toList();
      }
      
      _filteredCompanyCreditData = filtered;
      _sortCompanyCreditData();
    });
  }

  void _sortCompanyCreditData() {
    _filteredCompanyCreditData.sort((a, b) {
      final dateAValue = a['purchase_date'];
      final dateBValue = b['purchase_date'];
      
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
        return _companyCreditDateSortAscending ? dateComparison : -dateComparison;
      }
      if (dateA != null) return -1;
      if (dateB != null) return 1;
      return 0;
    });
  }

  Future<void> _selectFromDateCompanyCredit() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDateCompanyCredit ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDateCompanyCredit = picked;
      });
      _filterCompanyCreditData(_companyCreditSearchController.text);
    }
  }

  Future<void> _selectToDateCompanyCredit() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDateCompanyCredit ?? (_fromDateCompanyCredit ?? DateTime.now()),
      firstDate: _fromDateCompanyCredit ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDateCompanyCredit = picked;
      });
      _filterCompanyCreditData(_companyCreditSearchController.text);
    }
  }

  void _toggleEditModeCompanyCredit(int recordId) {
    setState(() {
      if (_editModeCompanyCredit[recordId] == true) {
        if (_companyBalancePaidControllers.containsKey(recordId)) {
          _companyBalancePaidControllers[recordId]!.dispose();
          _companyBalancePaidControllers.remove(recordId);
        }
        if (_companyDetailsControllers.containsKey(recordId)) {
          _companyDetailsControllers[recordId]!.dispose();
          _companyDetailsControllers.remove(recordId);
        }
        _companyBalancePaidDates.remove(recordId);
        _editModeCompanyCredit[recordId] = false;
      } else {
        final record = _filteredCompanyCreditData.firstWhere(
          (r) => r['id'] == recordId,
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          final payments = _companyBalancePayments[recordId] ?? [];
          double totalBalancePaid = 0;
        for (var payment in payments) {
            totalBalancePaid += FormatUtils.parseDecimal(payment['balance_paid']);
          }
          _companyBalancePaidControllers[recordId] = TextEditingController(
            text: totalBalancePaid.toStringAsFixed(2),
          );
          
          if (payments.isNotEmpty && payments.last['balance_paid_date'] != null) {
            _companyBalancePaidDates[recordId] = FormatUtils.parseDate(payments.last['balance_paid_date']);
          } else {
            _companyBalancePaidDates[recordId] = null;
          }
          
          _companyDetailsControllers[recordId] = TextEditingController(
            text: record['details']?.toString() ?? '',
          );
          
          _editModeCompanyCredit[recordId] = true;
        }
      }
    });
  }

  void _addNewCompanyPaymentRow(int purchaseId) {
    setState(() {
      _addingNewCompanyPayment[purchaseId] = true;
      final key = '${purchaseId}_new';
      _newCompanyPaymentControllers[key] = TextEditingController();
      _newCompanyPaymentDates[key] = null;
      _newCompanyPaymentDetailsControllers[key] = TextEditingController();
    });
  }

  void _cancelNewCompanyPaymentRow(int purchaseId) {
    setState(() {
      _addingNewCompanyPayment[purchaseId] = false;
      final key = '${purchaseId}_new';
      if (_newCompanyPaymentControllers.containsKey(key)) {
        _newCompanyPaymentControllers[key]!.dispose();
        _newCompanyPaymentControllers.remove(key);
      }
      _newCompanyPaymentDates.remove(key);
      if (_newCompanyPaymentDetailsControllers.containsKey(key)) {
        _newCompanyPaymentDetailsControllers[key]!.dispose();
        _newCompanyPaymentDetailsControllers.remove(key);
      }
    });
  }

  double _calculateCompanyOverallBalance(int purchaseId, int? paymentIndex) {
    final record = _filteredCompanyCreditData.firstWhere(
      (r) => r['id'] == purchaseId,
      orElse: () => {},
    );
    if (record.isEmpty) return 0;

    final credit = FormatUtils.parseDecimal(record['credit']);
    final payments = _companyBalancePayments[purchaseId] ?? [];
    
    if (paymentIndex == null) {
      double totalPaid = 0;
      for (var payment in payments) {
        totalPaid += FormatUtils.parseDecimal(payment['balance_paid']);
      }
      return credit - totalPaid;
          } else {
      if (paymentIndex == 0) {
        final payment = payments[paymentIndex];
        final balancePaid = FormatUtils.parseDecimal(payment['balance_paid']);
        return credit - balancePaid;
      } else {
        final prevPayment = payments[paymentIndex - 1];
        final prevOverallBalance = FormatUtils.parseDecimal(prevPayment['overall_balance']);
        final currentPayment = payments[paymentIndex];
        final balancePaid = FormatUtils.parseDecimal(currentPayment['balance_paid']);
        return prevOverallBalance - balancePaid;
      }
    }
  }

  Future<void> _saveCompanyCreditRecord(int recordId) async {
    final record = _filteredCompanyCreditData.firstWhere(
      (r) => r['id'] == recordId,
      orElse: () => {},
    );
    
    if (record.isEmpty) {
      return;
    }

    final balancePaid = _companyBalancePaidControllers.containsKey(recordId)
        ? FormatUtils.parseDecimal(_companyBalancePaidControllers[recordId]!.text.trim())
        : 0.0;
    final balancePaidDate = _companyBalancePaidDates[recordId];
    final details = _companyDetailsControllers.containsKey(recordId)
        ? _companyDetailsControllers[recordId]!.text.trim()
        : record['details']?.toString() ?? '';

    setState(() => _isLoadingCompanyCredit = true);

    try {
      final payments = _companyBalancePayments[recordId] ?? [];
      final credit = FormatUtils.parseDecimal(record['credit']);
      
      if (payments.isEmpty && balancePaid > 0) {
        final overallBalance = credit - balancePaid;
        final payment = {
          'purchase_id': recordId,
            'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };
        await ApiService.saveBalancePayment(payment);
      } else if (payments.isNotEmpty && balancePaid > 0) {
        final firstPayment = payments.first;
        final firstPaymentId = firstPayment['id'] as int?;
        if (firstPaymentId != null) {
          final overallBalance = credit - balancePaid;
          final payment = {
            'id': firstPaymentId,
            'purchase_id': recordId,
            'balance_paid': balancePaid,
            'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
            'details': details.isEmpty ? null : details,
            'overall_balance': overallBalance,
          };
          await ApiService.saveBalancePayment(payment);
        }
      }
      
      _editModeCompanyCredit[recordId] = false;

      await _loadCompanyCreditData();

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
        setState(() => _isLoadingCompanyCredit = false);
      }
    }
  }

  Future<void> _saveCompanyPaymentRow(int purchaseId, int? paymentId) async {
    setState(() => _isLoadingCompanyCredit = true);

    try {
      final record = _filteredCompanyCreditData.firstWhere(
        (r) => r['id'] == purchaseId,
        orElse: () => {},
      );
      if (record.isEmpty) return;

      final credit = FormatUtils.parseDecimal(record['credit']);
      final payments = _companyBalancePayments[purchaseId] ?? [];
      
      double balancePaid;
      DateTime? balancePaidDate;
      String details;
      double overallBalance;

      if (paymentId == null) {
        final key = '${purchaseId}_new';
        balancePaid = FormatUtils.parseDecimal(_newCompanyPaymentControllers[key]?.text ?? '0');
        balancePaidDate = _newCompanyPaymentDates[key];
        details = _newCompanyPaymentDetailsControllers.containsKey(key)
            ? _newCompanyPaymentDetailsControllers[key]!.text.trim()
            : '';
        
        if (payments.isEmpty) {
          overallBalance = credit - balancePaid;
        } else {
          final lastPayment = payments.last;
          final lastOverallBalance = FormatUtils.parseDecimal(lastPayment['overall_balance']);
          overallBalance = lastOverallBalance - balancePaid;
        }

        final payment = {
          'purchase_id': purchaseId,
          'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };

        await ApiService.saveBalancePayment(payment);
        _cancelNewCompanyPaymentRow(purchaseId);
      } else {
        final key = paymentId;
        balancePaid = _companyBalancePaidControllers.containsKey(key)
            ? FormatUtils.parseDecimal(_companyBalancePaidControllers[key]!.text.trim())
            : FormatUtils.parseDecimal(payments.firstWhere((p) => p['id'] == paymentId)['balance_paid']);
        balancePaidDate = _companyBalancePaidDates[key];
        details = _companyDetailsControllers.containsKey(key)
            ? _companyDetailsControllers[key]!.text.trim()
            : (payments.firstWhere((p) => p['id'] == paymentId)['details']?.toString() ?? '');

        final paymentIndex = payments.indexWhere((p) => p['id'] == paymentId);
        overallBalance = _calculateCompanyOverallBalance(purchaseId, paymentIndex);

        final payment = {
          'id': paymentId,
          'purchase_id': purchaseId,
          'balance_paid': balancePaid,
          'balance_paid_date': balancePaidDate != null ? FormatUtils.formatDate(balancePaidDate) : null,
          'details': details.isEmpty ? null : details,
          'overall_balance': overallBalance,
        };

        await ApiService.saveBalancePayment(payment);
      }

      await _loadCompanyCreditData();

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
        setState(() => _isLoadingCompanyCredit = false);
      }
    }
  }

  Future<void> _deleteCompanyCreditRecord(int recordId, String name) async {
    final confirmed = await UIHelpers.showDeleteConfirmationDialog(
      context: context,
      itemName: 'credit record for "$name"',
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isLoadingCompanyCredit = true);

    try {
      await ApiService.deleteCompanyPurchaseDetails(recordId.toString());

      await _loadCompanyCreditData();

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
        setState(() => _isLoadingCompanyCredit = false);
      }
    }
  }


  Widget _buildCompanyCreditDetailsTab() {
    // Note: This is a simplified version. The full table implementation would be very similar
    // to _buildCreditDetailsTab but using _companyCredit* variables instead.
    // For now, this provides the basic structure with search and filtering.
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Purchases with Outstanding Credit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          return TextField(
                            controller: _companyCreditSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search by Item Name or Shop Name',
                              hintText: 'Enter item name or shop name to search',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _companyCreditSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _companyCreditSearchController.clear();
                                        _filterCompanyCreditData('');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              _filterCompanyCreditData(value);
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // From Date Picker
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 56,
                          child: InkWell(
                            onTap: _selectFromDateCompanyCredit,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'From Date',
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                _fromDateCompanyCredit != null
                                    ? _fromDateCompanyCredit!.toIso8601String().split('T')[0]
                                    : 'From Date',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        if (_fromDateCompanyCredit != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _fromDateCompanyCredit = null;
                              });
                              _filterCompanyCreditData(_companyCreditSearchController.text);
                            },
                            tooltip: 'Clear From Date',
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // To Date Picker
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 56,
                          child: InkWell(
                            onTap: _selectToDateCompanyCredit,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'To Date',
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                _toDateCompanyCredit != null
                                    ? _toDateCompanyCredit!.toIso8601String().split('T')[0]
                                    : 'To Date',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        if (_toDateCompanyCredit != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _toDateCompanyCredit = null;
                              });
                              _filterCompanyCreditData(_companyCreditSearchController.text);
                            },
                            tooltip: 'Clear To Date',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCompanyCredit
              ? const Center(child: CircularProgressIndicator())
              : _filteredCompanyCreditData.isEmpty
                  ? const Center(
                      child: Text(
                        'No purchases with outstanding credit',
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
                                            _companyCreditSectorSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _companyCreditSectorSortAscending = !_companyCreditSectorSortAscending;
                                              _filteredCompanyCreditData.sort((a, b) {
                                                final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                                final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                                return _companyCreditSectorSortAscending
                                                    ? aName.compareTo(bName)
                                                    : bName.compareTo(aName);
                                              });
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Shop Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Amount Pending', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Credit Taken Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: Icon(
                                          _companyCreditDateSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _companyCreditDateSortAscending = !_companyCreditDateSortAscending;
                                            _sortCompanyCreditData();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const DataColumn(label: Text('Balance Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Overall Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _filteredCompanyCreditData.map((record) {
                                final recordId = record['id'] as int;
                                final credit = FormatUtils.parseDecimal(record['credit']);
                                final payments = _companyBalancePayments[recordId] ?? [];
                                double totalPaid = 0;
                                for (var payment in payments) {
                                  totalPaid += FormatUtils.parseDecimal(payment['balance_paid']);
                                }
                                final overallBalance = credit - totalPaid;
                                
                                return DataRow(
                                  cells: [
                                    if (widget.selectedSector == null && _isAdmin)
                                      DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                    DataCell(Text(record['item_name']?.toString() ?? '')),
                                    DataCell(Text(record['shop_name']?.toString() ?? '')),
                                    DataCell(Text(record['purchase_details']?.toString() ?? '')),
                                    DataCell(Text('₹${credit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                                    DataCell(Text(FormatUtils.formatDate(record['purchase_date']))),
                                    DataCell(Text('₹${totalPaid.toStringAsFixed(2)}')),
                                    DataCell(Text('₹${overallBalance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: overallBalance > 0 ? Colors.red : Colors.green))),
                                    DataCell(Text(record['details']?.toString() ?? '')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            tooltip: 'Edit',
                                            onPressed: () => _toggleEditModeCompanyCredit(recordId),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, color: Colors.orange, size: 20),
                                            tooltip: 'Add Payment',
                                            onPressed: () => _addNewCompanyPaymentRow(recordId),
                                          ),
                                          if (widget.isMainAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteCompanyCreditRecord(recordId, record['item_name']?.toString() ?? 'Unknown'),
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

  // ========== Overall Income Expense and Credit Details Tab ==========
  
  Future<void> _loadAllDataForSummary() async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoadingSummary = true);
    try {
      // Load all sales data without date filter
      final allSales = await ApiService.getSalesDetails(
        sector: widget.selectedSector,
        // No date parameter to get all data
      );
      
      // Load all purchase data without date filter
      final allPurchases = await ApiService.getCompanyPurchaseDetails(
        sector: widget.selectedSector,
        // No date parameter to get all data
      );

      setState(() {
        _allSalesDataForSummary = allSales;
        _allPurchaseDataForSummary = allPurchases;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading summary data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  DateTime? _parseDateFromRecord(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is String) {
        String dateStr = dateValue;
        if (dateStr.contains('T')) {
          dateStr = dateStr.split('T')[0];
        }
        if (dateStr.contains(' ')) {
          dateStr = dateStr.split(' ')[0];
        }
        return DateTime.tryParse(dateStr);
      }
    } catch (e) {
      // Ignore parse errors
    }
    return null;
  }

  Future<void> _downloadSalesDetailsPDF() async {
    if (_salesData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales data to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingSales = true);
    try {
      final fromDate = _selectedDate ?? DateTime.now();
      final toDate = _selectedDate ?? DateTime.now();
      
      final filePath = await PdfGenerator.generateSalesDetailsPDF(
        salesData: _salesData,
        fromDate: fromDate,
        toDate: toDate,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSales = false);
      }
    }
  }

  Future<void> _downloadCreditDetailsPDF() async {
    // IMPORTANT: Use _filteredCreditData if it has data, otherwise fall back to _creditData
    // This ensures PDF works even when no filters are applied
    List<Map<String, dynamic>> dataToUse = _filteredCreditData.isNotEmpty 
        ? _filteredCreditData 
        : _creditData;
    
    if (dataToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No credit data to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show dialog to get filename
    final fileNameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter File Name'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(
            labelText: 'File Name',
            hintText: 'Enter file name (without extension)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (fileNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
      } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a file name'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final fileName = fileNameController.text.trim();
    fileNameController.dispose();

    setState(() => _isLoadingCredit = true);
    try {
      // Generate PDF with currently visible table data
      // IMPORTANT: Use _filteredCreditData if it has data, otherwise fall back to _creditData
      // This ensures PDF works even when no filters are applied
      List<Map<String, dynamic>> dataToUse = _filteredCreditData.isNotEmpty 
          ? _filteredCreditData 
          : _creditData;
      
      print('Download PDF: _filteredCreditData.length = ${_filteredCreditData.length}');
      print('Download PDF: _creditData.length = ${_creditData.length}');
      print('Download PDF: dataToUse.length = ${dataToUse.length}');
      print('Download PDF: _balancePayments.length = ${_balancePayments.length}');
      
      if (dataToUse.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data to download. Please ensure there is data in the table.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Convert sector codes to names for PDF
      final Map<String, String> sectorNameMap = {};
      for (var sector in _sectors) {
        sectorNameMap[sector.code] = sector.name;
      }
      
      final filePath = await PdfGenerator.generateSalesCreditDetailsPDFFromTable(
        creditData: dataToUse, // Use filtered data if available, otherwise use all credit data
        balancePayments: _balancePayments,
        showSector: widget.selectedSector == null && _isAdmin,
        sectorNameMap: sectorNameMap,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCredit = false);
      }
    }
  }

  Future<void> _downloadOverallSummaryPDF() async {
    // Filter data by date range (same as in _buildOverallIncomeExpenseTab)
    List<Map<String, dynamic>> filteredSales = _allSalesDataForSummary;
    List<Map<String, dynamic>> filteredPurchases = _allPurchaseDataForSummary;
    
    if (_fromDate != null || _toDate != null) {
      filteredSales = _allSalesDataForSummary.where((sale) {
        final saleDate = _parseDateFromRecord(sale['sale_date']);
        if (saleDate == null) return false;
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        final fromDateOnly = _fromDate != null ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) : null;
        final toDateOnly = _toDate != null ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day) : null;
        
        if (fromDateOnly != null && saleDateOnly.isBefore(fromDateOnly)) return false;
        if (toDateOnly != null && saleDateOnly.isAfter(toDateOnly)) return false;
        return true;
      }).toList();
      
      filteredPurchases = _allPurchaseDataForSummary.where((purchase) {
        final purchaseDate = _parseDateFromRecord(purchase['purchase_date']);
        if (purchaseDate == null) return false;
        final purchaseDateOnly = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
        final fromDateOnly = _fromDate != null ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) : null;
        final toDateOnly = _toDate != null ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day) : null;
        
        if (fromDateOnly != null && purchaseDateOnly.isBefore(fromDateOnly)) return false;
        if (toDateOnly != null && purchaseDateOnly.isAfter(toDateOnly)) return false;
        return true;
      }).toList();
    }

    if (filteredSales.isEmpty && filteredPurchases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
          content: Text('No data to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingSummary = true);
    try {
      final fromDate = _fromDate ?? DateTime.now();
      final toDate = _toDate ?? DateTime.now();
      
      final filePath = await PdfGenerator.generateSalesDetailsPDF(
        salesData: filteredSales,
        fromDate: fromDate,
        toDate: toDate,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }

  Future<void> _downloadCompanyCreditDetailsPDF() async {
    if (_filteredCompanyCreditData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No purchase credit data to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingCompanyCredit = true);
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final fileName = 'Purchase_Credit_Details_${dateFormat.format(DateTime.now())}.pdf';
      
      final filePath = await PdfGenerator.generateCompanyPurchaseCreditDetailsPDF(
        creditData: _filteredCompanyCreditData,
        fileName: fileName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded successfully: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCompanyCredit = false);
      }
    }
  }

  Widget _buildOverallIncomeExpenseTab() {
    // Filter data by date range
    List<Map<String, dynamic>> filteredSales = _allSalesDataForSummary;
    List<Map<String, dynamic>> filteredPurchases = _allPurchaseDataForSummary;
    
    if (_fromDate != null || _toDate != null) {
      filteredSales = _allSalesDataForSummary.where((sale) {
        final saleDate = _parseDateFromRecord(sale['sale_date']);
        if (saleDate == null) return false;
        final saleDateOnly = DateTime(saleDate.year, saleDate.month, saleDate.day);
        final fromDateOnly = _fromDate != null ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) : null;
        final toDateOnly = _toDate != null ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day) : null;
        
        if (fromDateOnly != null && saleDateOnly.isBefore(fromDateOnly)) return false;
        if (toDateOnly != null && saleDateOnly.isAfter(toDateOnly)) return false;
        return true;
      }).toList();
      
      filteredPurchases = _allPurchaseDataForSummary.where((purchase) {
        final purchaseDate = _parseDateFromRecord(purchase['purchase_date']);
        if (purchaseDate == null) return false;
        final purchaseDateOnly = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
        final fromDateOnly = _fromDate != null ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day) : null;
        final toDateOnly = _toDate != null ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day) : null;
        
        if (fromDateOnly != null && purchaseDateOnly.isBefore(fromDateOnly)) return false;
        if (toDateOnly != null && purchaseDateOnly.isAfter(toDateOnly)) return false;
        return true;
      }).toList();
    }
    
    // Group by sector if all sectors is selected
    final showSectorColumn = widget.selectedSector == null && _isAdmin;
    Map<String, Map<String, double>> sectorData = {};
    
    if (showSectorColumn) {
      // Group sales data by sector
      for (var sale in filteredSales) {
        final sectorCode = sale['sector_code']?.toString() ?? 'Unknown';
        if (!sectorData.containsKey(sectorCode)) {
          sectorData[sectorCode] = {
            'salesIncome': 0.0,
            'salesCredit': 0.0,
            'purchaseExpense': 0.0,
            'purchaseCredit': 0.0,
          };
        }
        sectorData[sectorCode]!['salesIncome'] = sectorData[sectorCode]!['salesIncome']! + FormatUtils.parseDecimal(sale['amount_received']);
        sectorData[sectorCode]!['salesCredit'] = sectorData[sectorCode]!['salesCredit']! + FormatUtils.parseDecimal(sale['credit_amount']);
      }
      
      // Group purchase data by sector
      for (var purchase in filteredPurchases) {
        final sectorCode = purchase['sector_code']?.toString() ?? 'Unknown';
        if (!sectorData.containsKey(sectorCode)) {
          sectorData[sectorCode] = {
            'salesIncome': 0.0,
            'salesCredit': 0.0,
            'purchaseExpense': 0.0,
            'purchaseCredit': 0.0,
          };
        }
        sectorData[sectorCode]!['purchaseExpense'] = sectorData[sectorCode]!['purchaseExpense']! + FormatUtils.parseDecimal(purchase['purchase_amount']);
        sectorData[sectorCode]!['purchaseCredit'] = sectorData[sectorCode]!['purchaseCredit']! + FormatUtils.parseDecimal(purchase['credit']);
      }
    }
    
    // Calculate totals
    double totalSalesIncome = 0.0;
    double totalSalesCredit = 0.0;
    double totalPurchaseExpense = 0.0;
    double totalPurchaseCredit = 0.0;
    
    for (var sale in filteredSales) {
      totalSalesIncome += FormatUtils.parseDecimal(sale['amount_received']);
      totalSalesCredit += FormatUtils.parseDecimal(sale['credit_amount']);
    }
    
    for (var purchase in filteredPurchases) {
      totalPurchaseExpense += FormatUtils.parseDecimal(purchase['purchase_amount']);
      totalPurchaseCredit += FormatUtils.parseDecimal(purchase['credit']);
    }
    
    return Column(
      children: [
        // Header with Date Range
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Overall Income, Expense and Credit Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              // Date Range Selection - Only visible for admin or abinaya
              if (_isAdmin || widget.username.toLowerCase() == 'abinaya') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectFromDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'From Date',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _fromDate != null
                                      ? _fromDate!.toIso8601String().split('T')[0]
                                      : 'Select From Date',
                                ),
                              ),
                            ),
                          ),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectToDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'To Date',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _toDate != null
                                      ? _toDate!.toIso8601String().split('T')[0]
                                      : 'Select To Date',
                                ),
                              ),
                            ),
                          ),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Table
        Expanded(
          child: _isLoadingSummary
              ? const Center(child: CircularProgressIndicator())
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
                            if (showSectorColumn)
                              const DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Sales Income', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Sales Credit', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Purchase Expense', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Purchase Credit', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [
                            // Sector-wise rows if all sectors is selected
                            if (showSectorColumn)
                              ...sectorData.entries.map((entry) {
                                final sectorCode = entry.key;
                                final data = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(_getSectorName(sectorCode))),
                                    DataCell(Text('₹${data['salesIncome']!.toStringAsFixed(2)}')),
                                    DataCell(Text('₹${data['salesCredit']!.toStringAsFixed(2)}')),
                                    DataCell(Text('₹${data['purchaseExpense']!.toStringAsFixed(2)}')),
                                    DataCell(Text('₹${data['purchaseCredit']!.toStringAsFixed(2)}')),
                                  ],
                                );
                              }).toList(),
                            // Total row
                            DataRow(
                              color: WidgetStateProperty.all(Colors.blue.shade50),
                              cells: [
                                if (showSectorColumn)
                                  DataCell(
                                    const Text(
                                      'TOTAL',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                DataCell(
                                  Text(
                                    '₹${totalSalesIncome.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${totalSalesCredit.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${totalPurchaseExpense.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${totalPurchaseCredit.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

