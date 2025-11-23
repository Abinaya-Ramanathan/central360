import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/sector.dart';
import '../utils/pdf_generator.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class CreditDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const CreditDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
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

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya';
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
    super.dispose();
  }

  void _filterCreditData(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCreditData = _creditData;
      } else {
        _filteredCreditData = _creditData.where((record) {
          final name = (record['name']?.toString() ?? '').toLowerCase();
          final address = (record['address']?.toString() ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || address.contains(searchQuery);
        }).toList();
      }
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
      // Load all credit details for the selected sector (no date/month filter)
      final credits = await ApiService.getCreditDetails(
        sector: widget.selectedSector,
      );

      setState(() {
        _creditData = credits;
        _filteredCreditData = credits;
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

  Future<void> _showStatementDialog() async {
    DateTime? fromDate;
    DateTime? toDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generate Statement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Custom:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: fromDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => fromDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'From Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(fromDate != null ? fromDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: toDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => toDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'To Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(toDate != null ? toDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Get it As:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                const Text('Pdf', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (fromDate == null || toDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select From and To dates'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'fromDate': fromDate,
                  'toDate': toDate,
                });
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['fromDate'] != null && result['toDate'] != null) {
      await _generateStatement(
        result['fromDate'] as DateTime,
        result['toDate'] as DateTime,
      );
    }
  }

  Future<void> _generateStatement(DateTime fromDate, DateTime toDate) async {
    try {
      setState(() => _isLoading = true);
      // Filter credit data by date range
      final filteredData = _creditData.where((record) {
        final creditDateStr = _formatDate(record['credit_date']);
        if (creditDateStr == 'N/A') return false;
        try {
          final creditDate = DateTime.parse(creditDateStr);
          return creditDate.isAfter(fromDate.subtract(const Duration(days: 1))) && 
                 creditDate.isBefore(toDate.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();

      setState(() => _isLoading = false);

      if (filteredData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found for the selected date range'), backgroundColor: Colors.orange),
        );
        return;
      }

      final sectorName = widget.selectedSector != null 
          ? _getSectorName(widget.selectedSector)
          : 'All Sectors';

      // Convert sectors list to maps for PDF generation
      final sectorsList = _sectors.map((s) => {'code': s.code, 'name': s.name}).toList();
      
      try {
        await PdfGenerator.generateAndDownloadCreditPDF(
          creditData: filteredData,
          sectorName: sectorName,
          showSectorColumn: widget.selectedSector == null && _isAdmin,
          sectors: sectorsList,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF downloaded successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
          );
        }
        rethrow;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating statement: $errorMsg'), backgroundColor: Colors.red),
        );
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 4),
                  const Text(
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
                  builder: (context) => HomeScreen(username: widget.username),
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Name or Address',
                hintText: 'Enter name or address to search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterCreditData('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterCreditData,
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
                                    const DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
                                  const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
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
                                                  if (_isAdmin)
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
          // Add Credit Details and Statement Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
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
                if (_isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showStatementDialog,
                      icon: const Icon(Icons.description),
                      label: const Text('Statement', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

