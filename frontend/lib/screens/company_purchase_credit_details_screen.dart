import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../utils/ui_helpers.dart';
import '../utils/pdf_generator.dart';
import '../config/env_config.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class CompanyPurchaseCreditDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const CompanyPurchaseCreditDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<CompanyPurchaseCreditDetailsScreen> createState() => _CompanyPurchaseCreditDetailsScreenState();
}

class _CompanyPurchaseCreditDetailsScreenState extends State<CompanyPurchaseCreditDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Sector> _sectors = [];
  bool _isAdmin = false;
  
  // Purchase Details Tab State
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _purchaseData = [];
  bool _isLoadingPurchase = false;
  final Map<int, bool> _editModePurchase = {};
  final Map<int, Map<String, TextEditingController>> _controllersPurchase = {};
  final Map<int, List<Map<String, dynamic>>> _purchasePhotos = {}; // Store photos for each purchase
  final ImagePicker _imagePicker = ImagePicker();
  bool _purchasesSectorSortAscending = true; // Sort direction for Sector column in Purchase Details
  
  // Credit Details Tab State
  List<Map<String, dynamic>> _creditData = [];
  List<Map<String, dynamic>> _filteredCreditData = [];
  bool _isLoadingCredit = false;
  final TextEditingController _creditSearchController = TextEditingController();
  Set<String> _selectedMonthsCredit = {}; // Set of 'YYYY-MM' strings for multiple month selection
  bool _isGeneratingPDF = false;
  bool _creditDateSortAscending = true; // true = ascending (oldest first), false = descending (newest first)
  bool _creditSectorSortAscending = true; // Sort direction for Sector column in Credit Details
  final Map<int, bool> _editModeCredit = {}; // Track which rows are in edit mode (key = record ID)
  final Map<int, TextEditingController> _balancePaidControllers = {}; // Controllers for Balance Paid field (key = record ID or payment ID)
  final Map<int, DateTime?> _balancePaidDates = {}; // Selected dates for Balance Paid Date (key = record ID or payment ID)
  final Map<int, TextEditingController> _detailsControllers = {}; // Controllers for Details field (key = record ID or payment ID)
  final Map<int, List<Map<String, dynamic>>> _creditPhotos = {}; // Store photos for credit records
  final Map<int, List<Map<String, dynamic>>> _balancePayments = {}; // Store balance payments for each credit record (key = purchase_id)
  final Map<int, bool> _addingNewPayment = {}; // Track if a new payment row is being added (key = purchase_id)
  final Map<String, TextEditingController> _newPaymentControllers = {}; // Controllers for new payment rows (key = "purchaseId_new")
  final Map<String, DateTime?> _newPaymentDates = {}; // Dates for new payment rows (key = "purchaseId_new")
  final Map<String, TextEditingController> _newPaymentDetailsControllers = {}; // Details controllers for new payment rows (key = "purchaseId_new")

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isAdmin = AuthService.isAdmin;
    _selectedDate = DateTime.now();
    _loadSectors();
    _loadPurchaseData();
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
    for (var controllers in _controllersPurchase.values) {
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
      _loadPurchaseData();
    }
  }

  Future<void> _loadPurchaseData() async {
    if (widget.selectedSector == null && !_isAdmin) return;
    if (_selectedDate == null) return;

    setState(() => _isLoadingPurchase = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];

      
      // Load purchases - if date filter is used, it should match the selected date
      // But also include records that might have been saved with slightly different dates due to timezone
      final purchases = await ApiService.getCompanyPurchaseDetails(
        sector: widget.selectedSector,
        date: dateStr, // Filter by exact date - only show records from this date
      );
      
      // If no purchases found with exact date match, try loading without date filter
      // This handles cases where date might have been saved with timezone offset
      if (purchases.isEmpty) {
        final allPurchases = await ApiService.getCompanyPurchaseDetails(
          sector: widget.selectedSector,
        );
        // Filter manually to include records within 1 day of selected date (timezone tolerance)
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
        // Load photos for each purchase
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

  Future<void> _loadCreditData() async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoadingCredit = true);
    try {
      final credits = await ApiService.getCreditDetailsFromCompanyPurchases(
        sector: widget.selectedSector,
      );


      setState(() {
        _creditData = credits;
        _filteredCreditData = List.from(credits);
        // Load photos and balance payments for each credit record
        _creditPhotos.clear();
        _balancePayments.clear();
        for (var credit in credits) {
          final creditId = credit['id'];
          if (creditId != null) {
            _creditPhotos[creditId] = List<Map<String, dynamic>>.from(credit['photos'] ?? []);
            // Load balance payments from the credit record
            _balancePayments[creditId] = List<Map<String, dynamic>>.from(credit['balance_payments'] ?? []);
          }
        }
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
        // Cancel edit mode - dispose controllers and clear dates
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
        // Enter edit mode - find record by ID and create controllers
        final record = _filteredCreditData.firstWhere(
          (r) => r['id'] == recordId,
          orElse: () => {},
        );
        if (record.isNotEmpty) {
          // Initialize Balance Paid controller - sum of all payments
          final payments = _balancePayments[recordId] ?? [];
          double totalBalancePaid = 0;
          for (var payment in payments) {
            totalBalancePaid += _parseDecimal(payment['balance_paid']);
          }
          _balancePaidControllers[recordId] = TextEditingController(
            text: totalBalancePaid.toStringAsFixed(2),
          );
          
          // Initialize Balance Paid Date - latest payment date or null
          if (payments.isNotEmpty && payments.last['balance_paid_date'] != null) {
            _balancePaidDates[recordId] = FormatUtils.parseDate(payments.last['balance_paid_date']);
          } else {
            _balancePaidDates[recordId] = null;
          }
          
          // Initialize Details controller for main record
          _detailsControllers[recordId] = TextEditingController(
            text: record['details']?.toString() ?? '',
          );
          
          _editModeCredit[recordId] = true;
        }
      }
    });
  }

  void _addNewPaymentRow(int purchaseId) {
    setState(() {
      _addingNewPayment[purchaseId] = true;
      final key = '${purchaseId}_new';
      _newPaymentControllers[key] = TextEditingController();
      _newPaymentDates[key] = null;
      _newPaymentDetailsControllers[key] = TextEditingController();
    });
  }

  void _cancelNewPaymentRow(int purchaseId) {
    setState(() {
      _addingNewPayment[purchaseId] = false;
      final key = '${purchaseId}_new';
      if (_newPaymentControllers.containsKey(key)) {
        _newPaymentControllers[key]!.dispose();
        _newPaymentControllers.remove(key);
      }
      _newPaymentDates.remove(key);
      if (_newPaymentDetailsControllers.containsKey(key)) {
        _newPaymentDetailsControllers[key]!.dispose();
        _newPaymentDetailsControllers.remove(key);
      }
    });
  }

  double _calculateOverallBalance(int purchaseId, int? paymentIndex) {
    final record = _filteredCreditData.firstWhere(
      (r) => r['id'] == purchaseId,
      orElse: () => {},
    );
    if (record.isEmpty) return 0;

    final credit = _parseDecimal(record['credit']); // Amount Pending
    final payments = _balancePayments[purchaseId] ?? [];
    
    if (paymentIndex == null) {
      // Calculate for main row: Amount Pending - sum of all payments
      double totalPaid = 0;
      for (var payment in payments) {
        totalPaid += _parseDecimal(payment['balance_paid']);
      }
      return credit - totalPaid;
    } else {
      // Calculate for a specific payment row
      if (paymentIndex == 0) {
        // First payment: Amount Pending - this payment
        final payment = payments[paymentIndex];
        final balancePaid = _parseDecimal(payment['balance_paid']);
        return credit - balancePaid;
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
      final credit = _parseDecimal(record['credit']); // Amount Pending
      
      if (payments.isEmpty && balancePaid > 0) {
        // Create first payment
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
        // Update the first payment with new values
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

  Future<void> _savePaymentRow(int purchaseId, int? paymentId) async {
    setState(() => _isLoadingCredit = true);

    try {
      final record = _filteredCreditData.firstWhere(
        (r) => r['id'] == purchaseId,
        orElse: () => {},
      );
      if (record.isEmpty) return;

      final credit = _parseDecimal(record['credit']); // Amount Pending
      final payments = _balancePayments[purchaseId] ?? [];
      
      double balancePaid;
      DateTime? balancePaidDate;
      String details;
      double overallBalance;

      if (paymentId == null) {
        // Saving a new payment row
        final key = '${purchaseId}_new';
        balancePaid = _parseDecimal(_newPaymentControllers[key]?.text ?? '0');
        balancePaidDate = _newPaymentDates[key];
        details = _newPaymentDetailsControllers.containsKey(key)
            ? _newPaymentDetailsControllers[key]!.text.trim()
            : '';
        
        // Calculate overall balance: previous overall balance - this payment
        if (payments.isEmpty) {
          // First payment: Amount Pending - this payment
          overallBalance = credit - balancePaid;
        } else {
          // Subsequent payment: last payment's overall_balance - this payment
          final lastPayment = payments.last;
          final lastOverallBalance = _parseDecimal(lastPayment['overall_balance']);
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
        _cancelNewPaymentRow(purchaseId);
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
        overallBalance = _calculateOverallBalance(purchaseId, paymentIndex);

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
      await ApiService.deleteCompanyPurchaseDetails(recordId.toString());

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
      List<Map<String, dynamic>> filtered = List.from(_creditData);
      
      // Apply month filter if months are selected
      if (_selectedMonthsCredit.isNotEmpty) {
        filtered = filtered.where((record) {
          final purchaseDate = record['purchase_date'];
          if (purchaseDate == null) return false;
          
          String dateStr;
          try {
            if (purchaseDate is DateTime) {
              dateStr = '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}';
            } else if (purchaseDate is String) {
              String dateString = purchaseDate;
              if (dateString.contains('T')) {
                dateString = dateString.split('T')[0];
              }
              if (dateString.contains(' ')) {
                dateString = dateString.split(' ')[0];
              }
              
              final parsed = DateTime.tryParse(dateString);
              if (parsed == null) {
                final parts = dateString.split('-');
                if (parts.length >= 2) {
                  final year = int.tryParse(parts[0]);
                  final month = int.tryParse(parts[1]);
                  if (year != null && month != null) {
                    dateStr = '$year-${month.toString().padLeft(2, '0')}';
                  } else {
                    return false;
                  }
                } else {
                  return false;
                }
              } else {
                dateStr = '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
              }
            } else {
              return false;
            }
          } catch (e) {
            return false;
          }
          
          return _selectedMonthsCredit.contains(dateStr);
        }).toList();
      }
      
      // Apply search filter
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        filtered = filtered.where((record) {
          final itemName = (record['item_name']?.toString() ?? '').toLowerCase();
          final shopName = (record['shop_name']?.toString() ?? '').toLowerCase();
          return itemName.contains(searchQuery) || shopName.contains(searchQuery);
        }).toList();
      }
      
      _filteredCreditData = filtered;
      // Apply sorting after filtering
      _sortCreditData();
    });
  }

  Future<void> _showMonthYearPickerCredit() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    Set<String> tempSelectedMonths = Set.from(_selectedMonthsCredit);
    
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Months'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setDialogState(() {
                            selectedYear--;
                          });
                        },
                      ),
                      Text(
                        selectedYear.toString(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setDialogState(() {
                            selectedYear++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month grid
                  SizedBox(
                    height: 280,
                    child: GridView.builder(
                      shrinkWrap: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final monthKey = '$selectedYear-${month.toString().padLeft(2, '0')}';
                        final isSelected = tempSelectedMonths.contains(monthKey);
                        final monthNames = [
                          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                        ];
                        
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                tempSelectedMonths.remove(monthKey);
                              } else {
                                tempSelectedMonths.add(monthKey);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.blue.shade900 : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                monthNames[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Clear all button
                  if (tempSelectedMonths.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          tempSelectedMonths.clear();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempSelectedMonths),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedMonthsCredit = result;
        _filterCreditData(_creditSearchController.text);
      });
    }
  }

  Future<void> _downloadCompanyPurchaseCreditPDF() async {
    // Use ALL data, ignore search + filters
    final dataToUse = _creditData;

    if (dataToUse.isEmpty) {
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
      // Collect all data including payment rows and calculate total
      final List<Map<String, dynamic>> allRowsForPDF = [];
      double totalOverallBalance = 0.0;

      for (var record in dataToUse) {
        final recordId = record['id'] as int;
        final credit = _parseDecimal(record['credit']); // Amount Pending = Credit value
        final payments = _balancePayments[recordId] ?? [];

        // Calculate total paid from existing payments
        double totalPaid = 0;
        for (var payment in payments) {
          totalPaid += _parseDecimal(payment['balance_paid']);
        }

        final mainOverallBalance = credit - totalPaid;
        totalOverallBalance += mainOverallBalance;

        // Add main row
        allRowsForPDF.add({
          'type': 'main',
          'purchase_date': record['purchase_date'],
          'item_name': record['item_name']?.toString() ?? '',
          'shop_name': record['shop_name']?.toString() ?? '',
          'purchase_details': record['purchase_details']?.toString() ?? '',
          'credit': credit,
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
            paymentOverallBalance = credit - balancePaid;
          } else {
            final prevPayment = payments[i - 1];
            final prevOverallBalance = _parseDecimal(prevPayment['overall_balance']);
            paymentOverallBalance = prevOverallBalance - balancePaid;
          }

          allRowsForPDF.add({
            'type': 'payment',
            'purchase_date': null,
            'item_name': '',
            'shop_name': '',
            'purchase_details': '',
            'credit': null,
            'balance_paid': balancePaid,
            'balance_paid_date': payment['balance_paid_date'],
            'overall_balance': paymentOverallBalance,
            'details': payment['details']?.toString() ?? '',
          });
        }
      }

      // Add total row
      allRowsForPDF.add({
        'type': 'total',
        'purchase_date': null,
        'item_name': 'TOTAL',
        'shop_name': null,
        'purchase_details': null,
        'credit': null,
        'balance_paid': null,
        'balance_paid_date': null,
        'overall_balance': totalOverallBalance,
        'details': null,
      });

      await PdfGenerator.generateCompanyPurchaseCreditDetailsPDF(
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

  void _sortCreditData() {
    _filteredCreditData.sort((a, b) {
      // Sort by date first if date sorting is enabled
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
        return _creditDateSortAscending ? dateComparison : -dateComparison;
      }
      if (dateA != null) return -1;
      if (dateB != null) return 1;
      return 0;
    });
  }

  Future<void> _showAddPurchaseDialog() async {
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
        purchaseAmount: _parseDecimal(purchaseAmountController.text),
        amountPaid: _parseDecimal(amountPaidController.text),
        credit: _parseDecimal(creditController.text),
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
    if (_selectedDate == null) return;

    setState(() => _isLoadingPurchase = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
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
      await _loadCreditData(); // Reload credit data as well

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
        // Exiting edit mode
        if (_controllersPurchase.containsKey(index)) {
          for (var controller in _controllersPurchase[index]!.values) {
            controller.dispose();
          }
          _controllersPurchase.remove(index);
        }
        _editModePurchase[index] = false;
      } else {
        // Entering edit mode
        final record = _purchaseData[index];
        final currentPurchaseDate = record['purchase_date']?.toString().split('T')[0].split(' ')[0] ?? '';
        final selectedDateStr = _selectedDate?.toIso8601String().split('T')[0] ?? '';
        
        
        // Show a warning if the selected date is different from the record's purchase_date
        if (currentPurchaseDate.isNotEmpty && currentPurchaseDate != selectedDateStr) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Note: Purchase date will be updated from $currentPurchaseDate to $selectedDateStr when you save.\n'
                    'This will be the Credit Taken Date.',
                  ),
                  duration: const Duration(seconds: 4),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          });
        }
        
        _controllersPurchase[index] = {
          'item_name': TextEditingController(text: record['item_name']?.toString() ?? ''),
          'shop_name': TextEditingController(text: record['shop_name']?.toString() ?? ''),
          'purchase_details': TextEditingController(text: record['purchase_details']?.toString() ?? ''),
          'purchase_amount': TextEditingController(text: _parseDecimal(record['purchase_amount']).toString()),
          'amount_paid': TextEditingController(text: _parseDecimal(record['amount_paid']).toString()),
          'credit': TextEditingController(text: _parseDecimal(record['credit']).toString()),
        };
        _editModePurchase[index] = true;
      }
    });
  }

  Future<void> _savePurchaseRecord(int index) async {
    final record = _purchaseData[index];
    final recordId = record['id'];
    if (recordId == null) return;

    if (!_controllersPurchase.containsKey(index)) return;

    final controllers = _controllersPurchase[index]!;
    // All fields are optional now, no validation needed

    setState(() => _isLoadingPurchase = true);
    try {
      // CRITICAL: Always use the selected date from the date picker as the purchase_date
      // This ensures Credit Taken Date matches the date selected in Purchase Details tab
      // When credit is added/updated, the purchase_date MUST be updated to the selected date
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final newCredit = _parseDecimal(controllers['credit']!.text);
      final oldPurchaseDate = record['purchase_date']?.toString().split('T')[0].split(' ')[0] ?? '';
      
      
      // ALWAYS use the selected date when saving - this becomes the Credit Taken Date
      // This ensures that if credit is added on 27/11, the Credit Taken Date shows 27/11
      final purchaseDateToUse = dateStr;
      
      
      // CRITICAL: When credit is present, purchase_date MUST be the selected date
      // This is the Credit Taken Date - it must reflect when credit was actually added
      // Show confirmation if the date is changing (but don't allow canceling if credit > 0)
      if (oldPurchaseDate.isNotEmpty && oldPurchaseDate != dateStr) {
        final hasCredit = newCredit > 0;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: !hasCredit, // Can't dismiss if credit is present
          builder: (context) => AlertDialog(
            title: Text(hasCredit ? 'Update Credit Date Required' : 'Update Purchase Date?'),
            content: Text(
              hasCredit
                  ? 'You have credit amount: ₹${newCredit.toStringAsFixed(2)}\n\n'
                    'Current purchase date: $oldPurchaseDate\n'
                    'Selected date: $dateStr\n\n'
                    'The Credit Taken Date MUST be updated to $dateStr to reflect when the credit was actually added.\n\n'
                    'This update is required when credit is present.'
                  : 'Current purchase date: $oldPurchaseDate\n'
                    'Selected date: $dateStr\n\n'
                    'The purchase date will be updated to $dateStr. Continue?',
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
          setState(() => _isLoadingPurchase = false);
          return;
        }
      }
      
      final updatedRecord = {
        'id': recordId,
        'sector_code': record['sector_code'] ?? widget.selectedSector,
        'item_name': controllers['item_name']!.text.trim().isEmpty ? null : controllers['item_name']!.text.trim(),
        'shop_name': controllers['shop_name']!.text.trim().isEmpty ? null : controllers['shop_name']!.text.trim(),
        'purchase_details': controllers['purchase_details']!.text.trim().isEmpty ? null : controllers['purchase_details']!.text.trim(),
        'purchase_amount': _parseDecimal(controllers['purchase_amount']!.text),
        'amount_paid': _parseDecimal(controllers['amount_paid']!.text),
        'credit': newCredit,
        'purchase_date': purchaseDateToUse, // Use selected date - this becomes the Credit Taken Date
      };

      final savedRecord = await ApiService.saveCompanyPurchaseDetails(updatedRecord);
      
      // Parse the saved date - handle different formats
      String savedPurchaseDate = 'N/A';
      if (savedRecord['purchase_date'] != null) {
        final dateValue = savedRecord['purchase_date'].toString();
        // Handle both 'YYYY-MM-DD' and 'YYYY-MM-DDTHH:MM:SS' formats
        savedPurchaseDate = dateValue.split('T')[0].split(' ')[0];
      }
      
      
      // Only show warning if dates are significantly different (not just timezone issues)
      // Compare just the date part, ignore time
      final expectedDateOnly = purchaseDateToUse.split('T')[0].split(' ')[0];
      if (savedPurchaseDate != 'N/A' && savedPurchaseDate != expectedDateOnly) {
        // Don't show snackbar for minor timezone differences - just log it
      }
      
      // Exit edit mode BEFORE reloading to prevent index issues
      if (_editModePurchase.containsKey(index)) {
        if (_controllersPurchase.containsKey(index)) {
          for (var controller in _controllersPurchase[index]!.values) {
            controller.dispose();
          }
          _controllersPurchase.remove(index);
        }
        _editModePurchase[index] = false;
      }
      
      // Reload data to reflect the updated purchase_date
      await _loadPurchaseData();
      await _loadCreditData();

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
    final recordId = record['id'];
    if (recordId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Record'),
        content: const Text('Are you sure you want to delete this purchases record?'),
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
      await ApiService.deleteCompanyPurchaseDetails(recordId.toString());
      await _loadPurchaseData();
      await _loadCreditData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase record deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting purchases record: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  // Helper method to get image URL
  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // Images are served from the base URL, not the API endpoint
    return '${EnvConfig.apiBaseUrl}$imageUrl';
  }

  // Helper method to build photo cell
  Widget _buildPhotoCell(int purchaseId, List<Map<String, dynamic>> photos, bool isEditMode) {
    if (photos.isEmpty) {
      return const SizedBox(width: 150, height: 60, child: Center(child: Text('No images', style: TextStyle(fontSize: 12))));
    }
    
    // Constrain to row height - use smaller images to fit within row
    return SizedBox(
      width: 150,
      height: 60, // Match typical row height
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
                        // Show image in full screen dialog
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
                          onTap: () => _deletePhoto(photoId, purchaseId),
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

  // Upload photos for a purchase
  Future<void> _uploadPhotos(int purchaseId) async {
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

      // Reload purchase data to get updated photos
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

  // Delete a photo
  Future<void> _deletePhoto(int photoId, int purchaseId) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase and Credit Details'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Purchase Details'),
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
          // Purchase Details Tab
          _buildPurchaseDetailsTab(),
          // Credit Details Tab
          _buildCreditDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildPurchaseDetailsTab() {
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
        // Purchase Table
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
                                    // Item Name
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
                                    // Shop Name
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
                                    // Purchase Details
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
                                    // Purchase Amount
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
                                          : Text('₹${_parseDecimal(record['purchase_amount']).toStringAsFixed(2)}'),
                                    ),
                                    // Amount Paid
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
                                          : Text('₹${_parseDecimal(record['amount_paid']).toStringAsFixed(2)}'),
                                    ),
                                    // Credit
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
                                          : Text('₹${_parseDecimal(record['credit']).toStringAsFixed(2)}'),
                                    ),
                                    // Bill Image
                                    DataCell(
                                      purchaseId != null
                                          ? ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 150,
                                                maxHeight: 60,
                                              ),
                                              child: _buildPhotoCell(purchaseId, photos, isEditMode),
                                            )
                                          : const SizedBox(width: 150, height: 60),
                                    ),
                                    // Action
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
                                                  onPressed: purchaseId != null ? () => _uploadPhotos(purchaseId) : null,
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
        // Add Purchase Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
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
                    // Search Bar
                    SizedBox(
                      width: 250,
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          return TextField(
                            controller: _creditSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search by Item Name or Shop Name',
                              hintText: 'Enter item name or shop name to search',
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
                    // Month/Year Picker Button
                    SizedBox(
                      width: 180,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _showMonthYearPickerCredit,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedMonthsCredit.isEmpty
                              ? 'Select Months'
                              : _selectedMonthsCredit.length == 1
                                  ? _selectedMonthsCredit.first
                                  : '${_selectedMonthsCredit.length} Months',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: _selectedMonthsCredit.isEmpty ? Colors.grey : Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Download Button
                    SizedBox(
                      width: 200,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPDF ? null : _downloadCompanyPurchaseCreditPDF,
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
                    SizedBox(
                      width: 300,
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
                            Flexible(
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
                                const DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Shop Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Bill Image', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                // First, generate all rows and calculate total
                                final allRows = <DataRow>[];
                                double totalOverallBalance = 0.0;
                                
                                final rowsFromData = _filteredCreditData.expand((record) {
                                final recordId = record['id'] as int;
                                final credit = _parseDecimal(record['credit']); // Amount Pending = Credit value
                                final purchaseDateRaw = record['purchase_date'];
                                final purchaseDateFormatted = _formatDate(purchaseDateRaw);
                                final photos = _creditPhotos[recordId] ?? <Map<String, dynamic>>[];
                                final payments = _balancePayments[recordId] ?? [];
                                final isAddingNewPayment = _addingNewPayment[recordId] == true;

                                // Main row
                                final List<DataRow> rows = [];
                                
                                // Calculate overall balance for main row (Amount Pending - sum of all payments)
                                double totalPaid = 0;
                                for (var payment in payments) {
                                  totalPaid += _parseDecimal(payment['balance_paid']);
                                }
                                final mainOverallBalance = credit - totalPaid;
                                  
                                  // Add to total (only count main row's overall balance)
                                  totalOverallBalance += mainOverallBalance;
                                
                                rows.add(DataRow(
                                  color: WidgetStateProperty.all(Colors.blue.shade200),
                                  cells: [
                                    if (widget.selectedSector == null && _isAdmin)
                                      DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                    // Item Name
                                    DataCell(Text(record['item_name']?.toString() ?? '')),
                                    // Shop Name
                                    DataCell(Text(record['shop_name']?.toString() ?? '')),
                                    // Purchase Details
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          record['purchase_details']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Bill Image
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 150,
                                          maxHeight: 60,
                                        ),
                                        child: _buildPhotoCell(recordId, photos, false), // Photos not editable in credit details
                                      ),
                                    ),
                                    // Amount Pending (from Credit column) - NON-EDITABLE
                                    DataCell(
                                      Text(
                                        '₹${credit.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    // Credit Taken Date
                                    DataCell(Text(purchaseDateFormatted)),
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
                                            ? (credit - _parseDecimal(_balancePaidControllers[recordId]!.text)).toStringAsFixed(2)
                                            : mainOverallBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: (_editModeCredit[recordId] == true && _balancePaidControllers.containsKey(recordId))
                                              ? ((credit - _parseDecimal(_balancePaidControllers[recordId]!.text)) > 0 ? Colors.red : Colors.green)
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
                                                    onPressed: () => _deleteCreditRecord(recordId, record['item_name']?.toString() ?? 'Unknown'),
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
                                    paymentOverallBalance = credit - balancePaid;
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
                                      // Item Name - empty
                                      const DataCell(Text('')),
                                      // Shop Name - empty
                                      const DataCell(Text('')),
                                      // Purchase Details - empty
                                      const DataCell(Text('')),
                                      // Bill Image - empty
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
                                                            ? _formatDate(_balancePaidDates[paymentKey])
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
                                                    ? _formatDate(payment['balance_paid_date'])
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
                                                          try {
                                                            await ApiService.deleteBalancePayment(paymentId);
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
                                    // Item Name
                                    const DataCell(Text('')),
                                    // Shop Name
                                    const DataCell(Text('')),
                                    // Purchase Details
                                    const DataCell(Text('')),
                                    // Bill Image
                                    const DataCell(Text('')),
                                    // Amount Pending
                                    const DataCell(Text('')),
                                    // Credit Taken Date
                                    const DataCell(Text('')),
                                    // Balance Paid
                                    const DataCell(Text('')),
                                    // Balance Paid Date
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
                                    // Details
                                    const DataCell(Text('')),
                                    // Action
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

}

