import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import '../utils/pdf_generator.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class CreditDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const CreditDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<CreditDetailsScreen> createState() => _CreditDetailsScreenState();
}

class _CreditDetailsScreenState extends State<CreditDetailsScreen> {
  List<Map<String, dynamic>> _creditData = [];
  List<Map<String, dynamic>> _filteredCreditData = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  final Map<int, bool> _editMode = {}; // Track which rows are in edit mode
  final Map<int, Map<String, TextEditingController>> _controllers = {};
  bool _isAdmin = false;
  final TextEditingController _searchController = TextEditingController();
  bool _creditDateSortAscending = true; // true = ascending (oldest first), false = descending (newest first)
  bool _sectorSortAscending = true; // Sort direction for Sector column
  bool _isGeneratingPDF = false;
  String? _selectedCompanyStaffFilter; // null, 'true', or 'false'
  Set<String> _selectedMonths = {}; // Set of 'YYYY-MM' strings for multiple month selection
  
  // Horizontal ScrollControllers for draggable scrollbars
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _tableHorizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Use AuthService to get admin status (based on password, not username)
    _isAdmin = AuthService.isAdmin;
    _loadSectors();
    _loadData();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controllers in _controllers.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _tableHorizontalScrollController.dispose();
    super.dispose();
  }

  void _filterCreditData(String query) {
    setState(() {
      List<Map<String, dynamic>> filtered = List.from(_creditData);
      
      // Apply month filter if months are selected
      if (_selectedMonths.isNotEmpty) {
        filtered = filtered.where((record) {
          final creditDate = record['credit_date'];
          if (creditDate == null) return false;
          
          String dateStr;
          try {
            if (creditDate is DateTime) {
              dateStr = '${creditDate.year}-${creditDate.month.toString().padLeft(2, '0')}';
            } else if (creditDate is String) {
              String dateString = creditDate;
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
          
          return _selectedMonths.contains(dateStr);
        }).toList();
      }
      
      // Apply search filter
      if (query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        filtered = filtered.where((record) {
          final shopName = (record['name']?.toString() ?? '').toLowerCase();
          final purchaseDetails = (record['purchase_details']?.toString() ?? '').toLowerCase();
          // Search by shop name (name field) and item name (within purchase_details)
          return shopName.contains(searchQuery) || purchaseDetails.contains(searchQuery);
        }).toList();
      }
      
      _filteredCreditData = filtered;
      // Apply sorting after filtering
      _sortCreditData();
    });
  }

  void _sortCreditData() {
    _filteredCreditData.sort((a, b) {
      final dateAValue = a['credit_date'];
      final dateBValue = b['credit_date'];
      
      // Handle null values
      if (dateAValue == null && dateBValue == null) return 0;
      if (dateAValue == null) return 1;
      if (dateBValue == null) return -1;
      
      DateTime? dateA;
      DateTime? dateB;
      
      // Parse date A
      if (dateAValue is DateTime) {
        dateA = dateAValue;
      } else if (dateAValue is String) {
        // Handle ISO format with T separator or space separator
        final dateStr = dateAValue.split('T')[0].split(' ')[0];
        dateA = DateTime.tryParse(dateStr);
      }
      
      // Parse date B
      if (dateBValue is DateTime) {
        dateB = dateBValue;
      } else if (dateBValue is String) {
        // Handle ISO format with T separator or space separator
        final dateStr = dateBValue.split('T')[0].split(' ')[0];
        dateB = DateTime.tryParse(dateStr);
      }
      
      // Handle invalid dates
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      final comparison = dateA.compareTo(dateB);
      return _creditDateSortAscending ? comparison : -comparison;
    });
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

  Future<void> _showMonthYearPicker() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    Set<String> tempSelectedMonths = Set.from(_selectedMonths);
    
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
        _selectedMonths = result;
      });
      // Apply filter with current search query to preserve both month and search filters
      _filterCreditData(_searchController.text);
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      if (dateValue is String) {
        // Handle ISO format with T separator or space separator
        final dateStr = dateValue.split('T')[0].split(' ')[0];
        return dateStr;
      } else if (dateValue is DateTime) {
        return dateValue.toIso8601String().split('T')[0];
      } else {
        // Try parsing as string first
        final dateStr = dateValue.toString();
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          return parsed.toIso8601String().split('T')[0];
        }
        // If it's already in date format, split by T or space
        return dateStr.split('T')[0].split(' ')[0];
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _loadData() async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoading = true);
    try {
      // For multiple months, we'll filter on the frontend
      // since the backend only supports single month filter
      // Pass null to backend when multiple months are selected, filter locally instead
      String? monthFilter; // Always pass null, filter on frontend for multiple months
      
      // Load credit details with filters (without month filter, we'll filter on frontend)
      final credits = await ApiService.getCreditDetails(
        sector: widget.selectedSector,
        month: monthFilter,
        companyStaff: _selectedCompanyStaffFilter,
      );
      
      // Apply multiple month filter on frontend if months are selected
      List<Map<String, dynamic>> filteredCredits = credits;
      if (_selectedMonths.isNotEmpty) {
        filteredCredits = credits.where((record) {
          final creditDate = record['credit_date'];
          if (creditDate == null) return false;
          
          String dateStr;
          try {
            if (creditDate is DateTime) {
              dateStr = '${creditDate.year}-${creditDate.month.toString().padLeft(2, '0')}';
            } else if (creditDate is String) {
              // Handle different date formats from PostgreSQL
              // PostgreSQL returns dates in format: "2025-01-15T00:00:00.000Z" or "2025-01-15"
              String dateString = creditDate;
              // Remove time portion if present
              if (dateString.contains('T')) {
                dateString = dateString.split('T')[0];
              }
              // Remove time portion if space separated
              if (dateString.contains(' ')) {
                dateString = dateString.split(' ')[0];
              }
              
              final parsed = DateTime.tryParse(dateString);
              if (parsed == null) {
                // Try parsing as just YYYY-MM-DD format
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
            print('Error parsing credit_date: $creditDate, error: $e');
            return false;
          }
          
          return _selectedMonths.contains(dateStr);
        }).toList();
      }

      setState(() {
        _creditData = filteredCredits;
        _filteredCreditData = filteredCredits;
        // Clear edit mode and controllers when data reloads
        _editMode.clear();
        for (var controllers in _controllers.values) {
          for (var controller in controllers.values) {
            controller.dispose();
          }
        }
        _controllers.clear();
        // Apply sorting after loading data
        _sortCreditData();
      });
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


  double _parseDecimalFromDynamic(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
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

  double _parseDoubleValue(String value) {
    if (value.isEmpty) return 0.0;
    final parsed = double.tryParse(value);
    return parsed ?? 0.0;
  }

  void _toggleEditMode(int index) {
    setState(() {
      if (_editMode[index] == true) {
        // Exiting edit mode - dispose controllers
        if (_controllers.containsKey(index)) {
          for (var controller in _controllers[index]!.values) {
            controller.dispose();
          }
          _controllers.remove(index);
        }
        _editMode[index] = false;
      } else {
        // Entering edit mode - create controllers
        final record = _creditData[index];
        _controllers[index] = {
          'name': TextEditingController(text: record['name']?.toString() ?? ''),
          'phone_number': TextEditingController(text: record['phone_number']?.toString() ?? ''),
          'address': TextEditingController(text: record['address']?.toString() ?? ''),
          'purchase_details': TextEditingController(text: record['purchase_details']?.toString() ?? ''),
          'credit_amount': TextEditingController(text: _parseDecimalFromDynamic(record['credit_amount']).toString()),
          'credit_date': TextEditingController(text: _formatDate(record['credit_date']) != 'N/A' ? _formatDate(record['credit_date']) : ''),
          'amount_settled': TextEditingController(text: _parseDecimalFromDynamic(record['amount_settled']).toString()),
          'full_settlement_date': TextEditingController(text: _formatDate(record['full_settlement_date']) != 'N/A' ? _formatDate(record['full_settlement_date']) : ''),
          'comments': TextEditingController(text: record['comments']?.toString() ?? ''),
        };
        _editMode[index] = true;
      }
    });
  }

  Future<void> _saveRecord(int index) async {
    final record = _creditData[index];
    final recordId = _parseIdFromDynamic(record['id']);
    if (recordId == null) return;

    if (!_controllers.containsKey(index)) return;

    final controllers = _controllers[index]!;
    if (controllers['name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (controllers['credit_date']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credit Date is required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedRecord = {
        'id': recordId,
        'sector_code': record['sector_code'] ?? widget.selectedSector,
        'name': controllers['name']!.text.trim(),
        'phone_number': controllers['phone_number']!.text.trim().isEmpty
            ? null
            : controllers['phone_number']!.text.trim(),
        'address': controllers['address']!.text.trim().isEmpty
            ? null
            : controllers['address']!.text.trim(),
        'purchase_details': controllers['purchase_details']!.text.trim().isEmpty
            ? null
            : controllers['purchase_details']!.text.trim(),
        'credit_amount': _parseDoubleValue(controllers['credit_amount']!.text),
        'credit_date': controllers['credit_date']!.text.trim(),
        'amount_settled': _parseDoubleValue(controllers['amount_settled']!.text),
        'full_settlement_date': controllers['full_settlement_date']!.text.trim().isEmpty
            ? null
            : controllers['full_settlement_date']!.text.trim(),
        'comments': controllers['comments']!.text.trim().isEmpty
            ? null
            : controllers['comments']!.text.trim(),
      };

      await ApiService.saveCreditDetails(updatedRecord);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit details saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving credit details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddCreditDialog() async {
    if (widget.selectedSector == null && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector from Home page')),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final purchaseDetailsController = TextEditingController();
    final creditAmountController = TextEditingController();
    final creditDateController = TextEditingController();
    final amountSettledController = TextEditingController();
    final fullSettlementDateController = TextEditingController();
    final commentsController = TextEditingController();
    DateTime? selectedCreditDate;
    DateTime? selectedFullSettlementDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Credit Details'),
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
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
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
                controller: purchaseDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedCreditDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    selectedCreditDate = picked;
                    creditDateController.text = picked.toIso8601String().split('T')[0];
                    setDialogState(() {}); // Update dialog state to reflect the change
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Credit Date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    creditDateController.text.isEmpty
                        ? 'Select Credit Date'
                        : creditDateController.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountSettledController,
                decoration: const InputDecoration(
                  labelText: 'Amount Settled',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedFullSettlementDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    selectedFullSettlementDate = picked;
                    fullSettlementDateController.text = picked.toIso8601String().split('T')[0];
                    setDialogState(() {}); // Update dialog state to reflect the change
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Full Settlement Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    fullSettlementDateController.text.isEmpty
                        ? 'Select Full Settlement Date (Optional)'
                        : fullSettlementDateController.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentsController,
                decoration: const InputDecoration(
                  labelText: 'Comments',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              phoneController.dispose();
              addressController.dispose();
              purchaseDetailsController.dispose();
              creditAmountController.dispose();
              creditDateController.dispose();
              amountSettledController.dispose();
              fullSettlementDateController.dispose();
              commentsController.dispose();
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
              if (creditDateController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credit Date is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
      ),
    );

    if (result == true) {
      await _saveNewCredit(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        purchaseDetails: purchaseDetailsController.text.trim(),
        creditAmount: _parseDoubleValue(creditAmountController.text),
        creditDate: creditDateController.text.trim(),
        amountSettled: _parseDoubleValue(amountSettledController.text),
        fullSettlementDate: fullSettlementDateController.text.trim().isEmpty
            ? null
            : fullSettlementDateController.text.trim(),
        comments: commentsController.text.trim().isEmpty
            ? null
            : commentsController.text.trim(),
      );
    }

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    purchaseDetailsController.dispose();
    creditAmountController.dispose();
    creditDateController.dispose();
    amountSettledController.dispose();
    fullSettlementDateController.dispose();
    commentsController.dispose();
  }

  Future<void> _viewCreditRecord(int index) async {
    final record = _filteredCreditData[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Credit Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectedSector == null && _isAdmin)
                _buildViewField('Sector', _getSectorName(record['sector_code']?.toString())),
              _buildViewField('Name', record['name']?.toString() ?? 'N/A'),
              _buildViewField('Phone Number', record['phone_number']?.toString() ?? 'N/A'),
              _buildViewField('Address', record['address']?.toString() ?? 'N/A'),
              _buildViewField('Purchase Details', record['purchase_details']?.toString() ?? 'N/A'),
              _buildViewField('Credit Amount', _parseDecimalFromDynamic(record['credit_amount']).toStringAsFixed(2)),
              _buildViewField('Credit Date', _formatDate(record['credit_date'])),
              _buildViewField('Amount Settled', _parseDecimalFromDynamic(record['amount_settled']).toStringAsFixed(2)),
              _buildViewField('Full Settlement Date', _formatDate(record['full_settlement_date'])),
              _buildViewField(
                'Pending Amount',
                (_parseDecimalFromDynamic(record['credit_amount']) - _parseDecimalFromDynamic(record['amount_settled'])).toStringAsFixed(2),
              ),
              _buildViewField('Comments', record['comments']?.toString() ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCreditRecord(int index) async {
    final record = _creditData[index];
    final recordId = _parseIdFromDynamic(record['id']);
    if (recordId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Credit Record'),
        content: const Text('Are you sure you want to delete this credit record?'),
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

    setState(() => _isLoading = true);
    try {
      await ApiService.deleteCreditDetails(recordId.toString());
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit record deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting credit record: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _downloadCurrentPageData() async {
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

    setState(() => _isGeneratingPDF = true);

    try {
      // Calculate min & max date from ALL credit data
      DateTime? minDate;
      DateTime? maxDate;

      for (var record in dataToUse) {
        try {
          final dateValue = record['credit_date'];
          if (dateValue == null) continue;

          final creditDate = DateTime.parse(dateValue);

          if (minDate == null || creditDate.isBefore(minDate)) {
            minDate = creditDate;
          }
          if (maxDate == null || creditDate.isAfter(maxDate)) {
            maxDate = creditDate;
          }
        } catch (e) {
          // Ignore invalid dates
        }
      }

      final fromDate = minDate ?? DateTime.now();
      final toDate = maxDate ?? DateTime.now();

      await PdfGenerator.generateCreditDetailsPDF(
        creditData: dataToUse,
        fromDate: fromDate,
        toDate: toDate,
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

  Future<void> _saveNewCredit({
    required String name,
    required String phone,
    required String address,
    required String purchaseDetails,
    required double creditAmount,
    required String creditDate,
    required double amountSettled,
    String? fullSettlementDate,
    String? comments,
  }) async {
    if (widget.selectedSector == null && !_isAdmin) return;

    setState(() => _isLoading = true);
    try {
      final record = {
        'sector_code': widget.selectedSector,
        'name': name,
        'phone_number': phone.isEmpty ? null : phone,
        'address': address.isEmpty ? null : address,
        'purchase_details': purchaseDetails.isEmpty ? null : purchaseDetails,
        'credit_amount': creditAmount,
        'credit_date': creditDate,
        'amount_settled': amountSettled,
        'full_settlement_date': fullSettlementDate,
        'comments': comments,
      };

      await ApiService.saveCreditDetails(record);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit details added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding credit details: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Details'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Sector Display
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
          // User icon with username
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
          // Home icon
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
          // Logout icon
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
      body: Column(
        children: [
          // Search Bar, Download Button and Notes
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Scrollbar(
              thumbVisibility: true,
              interactive: true,
              controller: _horizontalScrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: Row(
                  children: [
                // Search Bar
                SizedBox(
                  width: 250,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Item Name or Shop Name',
                          hintText: 'Enter item name or shop name to search',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
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
                    initialValue: _selectedCompanyStaffFilter,
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
                        _selectedCompanyStaffFilter = value;
                      });
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Month/Year Picker Button
                SizedBox(
                  width: 180,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _showMonthYearPicker,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedMonths.isEmpty
                          ? 'Select Months'
                          : _selectedMonths.length == 1
                              ? _selectedMonths.first
                              : '${_selectedMonths.length} Months',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: _selectedMonths.isEmpty ? Colors.grey : Colors.blue),
                    ),
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
          ),
        ),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCreditData.isEmpty
                    ? const Center(
                        child: Text(
                          'No credit data available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          thumbVisibility: true,
                          interactive: true,
                          controller: _tableHorizontalScrollController,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _tableHorizontalScrollController,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DataTable(
                                columnSpacing: 20,
                                sortColumnIndex: (widget.selectedSector == null && _isAdmin) ? 0 : null,
                                sortAscending: _sectorSortAscending,
                                columns: [
                                  if (widget.selectedSector == null && _isAdmin)
                                    DataColumn(
                                      label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onSort: (columnIndex, ascending) {
                                        setState(() {
                                          _sectorSortAscending = ascending;
                                          _filteredCreditData.sort((a, b) {
                                            final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                            final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                            return ascending
                                                ? aName.compareTo(bName)
                                                : bName.compareTo(aName);
                                          });
                                        });
                                      },
                                    ),
                                  const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Company Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Credit Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Credit Date', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  const DataColumn(label: Text('Amount Settled', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Full Settlement Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Pending Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _filteredCreditData.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final record = entry.value;
                                  final isEditMode = _editMode[index] == true;

                                  return DataRow(
                                    color: WidgetStateProperty.all(Colors.blue.shade200),
                                    cells: [
                                      if (widget.selectedSector == null && _isAdmin)
                                        DataCell(Text(_getSectorName(record['sector_code']?.toString()))),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 150,
                                                child: TextFormField(
                                                  controller: _controllers[index]!['name'],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                ),
                                              )
                                            : Text(record['name']?.toString() ?? ''),
                                      ),
                                      DataCell(
                                        Text(
                                          (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? 'Yes' : 'No',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: (record['company_staff'] == true || record['company_staff'] == 'true' || record['company_staff'] == 1) ? Colors.green.shade700 : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 150,
                                                child: TextFormField(
                                                  controller: _controllers[index]!['phone_number'],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  keyboardType: TextInputType.phone,
                                                ),
                                              )
                                            : Text(record['phone_number']?.toString() ?? 'N/A'),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: isEditMode && _controllers.containsKey(index)
                                              ? TextFormField(
                                                  controller: _controllers[index]!['address'],
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
                                        SizedBox(
                                          width: 200,
                                          child: isEditMode && _controllers.containsKey(index)
                                              ? TextFormField(
                                                  controller: _controllers[index]!['purchase_details'],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  maxLines: 2,
                                                )
                                              : Text(
                                                  record['purchase_details']?.toString() ?? 'N/A',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                        ),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 120,
                                                child: TextFormField(
                                                  controller: _controllers[index]!['credit_amount'],
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
                                            : Text(_parseDecimalFromDynamic(record['credit_amount']).toStringAsFixed(2)),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 120,
                                                child: InkWell(
                                                  onTap: () async {
                                                    final DateTime? picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: _controllers[index]!['credit_date']!.text.isNotEmpty
                                                          ? DateTime.tryParse(_controllers[index]!['credit_date']!.text) ?? DateTime.now()
                                                          : DateTime.now(),
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                    if (picked != null) {
                                                      _controllers[index]!['credit_date']!.text = picked.toIso8601String().split('T')[0];
                                                    }
                                                  },
                                                  child: InputDecorator(
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      isDense: true,
                                                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                                                    ),
                                                    child: Text(
                                                      _controllers[index]!['credit_date']!.text.isEmpty
                                                          ? 'Select Date'
                                                          : _controllers[index]!['credit_date']!.text,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                _formatDate(record['credit_date']),
                                              ),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 120,
                                                child: TextFormField(
                                                  controller: _controllers[index]!['amount_settled'],
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
                                            : Text(_parseDecimalFromDynamic(record['amount_settled']).toStringAsFixed(2)),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 120,
                                                child: InkWell(
                                                  onTap: () async {
                                                    final DateTime? picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: _controllers[index]!['full_settlement_date']!.text.isNotEmpty
                                                          ? DateTime.tryParse(_controllers[index]!['full_settlement_date']!.text) ?? DateTime.now()
                                                          : DateTime.now(),
                                                      firstDate: DateTime(2000),
                                                      lastDate: DateTime(2100),
                                                    );
                                                    if (picked != null) {
                                                      setState(() {
                                                        _controllers[index]!['full_settlement_date']!.text = picked.toIso8601String().split('T')[0];
                                                      });
                                                    }
                                                  },
                                                  child: InputDecorator(
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      isDense: true,
                                                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                                                    ),
                                                    child: Text(
                                                      _controllers[index]!['full_settlement_date']!.text.isEmpty
                                                          ? 'Select Date'
                                                          : _controllers[index]!['full_settlement_date']!.text,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                _formatDate(record['full_settlement_date']),
                                              ),
                                      ),
                                      DataCell(
                                        Text(
                                          (_parseDecimalFromDynamic(record['credit_amount']) - _parseDecimalFromDynamic(record['amount_settled'])).toStringAsFixed(2),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: (_parseDecimalFromDynamic(record['credit_amount']) - _parseDecimalFromDynamic(record['amount_settled'])) > 0
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        isEditMode && _controllers.containsKey(index)
                                            ? SizedBox(
                                                width: 200,
                                                child: TextFormField(
                                                  controller: _controllers[index]!['comments'],
                                                  decoration: const InputDecoration(
                                                    border: OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                  maxLines: 2,
                                                ),
                                              )
                                            : SizedBox(
                                                width: 200,
                                                child: Text(
                                                  record['comments']?.toString() ?? 'N/A',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
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
                                                    onPressed: () => _saveRecord(index),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                                    tooltip: 'Cancel',
                                                    onPressed: () => _toggleEditMode(index),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
                                                    tooltip: 'View',
                                                    onPressed: () => _viewCreditRecord(index),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    tooltip: 'Edit',
                                                    onPressed: () => _toggleEditMode(index),
                                                  ),
                                                  if (widget.isMainAdmin)
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                      tooltip: 'Delete',
                                                      onPressed: () => _deleteCreditRecord(index),
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
          ),
          // Add Credit Details Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showAddCreditDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Credit Details', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

