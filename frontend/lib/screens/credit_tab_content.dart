import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../widgets/fixed_header_table.dart';

class CreditTabContent extends StatefulWidget {
  final String? selectedSector;
  final int? selectedMonth;
  final DateTime? selectedDate;
  final bool isAdmin;

  const CreditTabContent({
    super.key,
    this.selectedSector,
    this.selectedMonth,
    this.selectedDate,
    this.isAdmin = false,
  });

  @override
  State<CreditTabContent> createState() => _CreditTabContentState();
}

class _CreditTabContentState extends State<CreditTabContent> {
  List<Map<String, dynamic>> _creditData = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  final Map<int, bool> _editMode = {}; // Track which rows are in edit mode
  final Map<int, Map<String, TextEditingController>> _controllers = {};
  final ScrollController _horizontalScrollController = ScrollController();

  static const double _headerHeight = 48;
  static const double _colSector = 100;
  static const double _colName = 150;
  static const double _colPhone = 120;
  static const double _colAddress = 200;
  static const double _colPurchase = 200;
  static const double _colAmount = 120;
  static const double _colAction = 80;
  static const double _colSpacing = 20;

  @override
  void initState() {
    super.initState();
    _loadSectors();
    if (widget.selectedMonth != null && widget.selectedDate != null) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(CreditTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.selectedMonth != oldWidget.selectedMonth ||
            widget.selectedDate != oldWidget.selectedDate ||
            widget.selectedSector != oldWidget.selectedSector) &&
        widget.selectedMonth != null &&
        widget.selectedDate != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    // Dispose all controllers
    for (var controllers in _controllers.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
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

  Future<void> _loadData() async {
    if (widget.selectedDate == null) return;

    setState(() => _isLoading = true);
    try {
      final year = widget.selectedDate!.year;
      final month = widget.selectedMonth ?? widget.selectedDate!.month;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final dateStr = FormatUtils.formatDateForApi(widget.selectedDate!);

      final credits = await ApiService.getCreditDetails(
        sector: widget.selectedSector,
        date: dateStr,
        month: monthStr,
      );

      setState(() {
        _creditData = credits;
        // Clear edit mode and controllers when data reloads
        _editMode.clear();
        for (var controllers in _controllers.values) {
          for (var controller in controllers.values) {
            controller.dispose();
          }
        }
        _controllers.clear();
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
          'amount_settled': TextEditingController(text: _parseDecimalFromDynamic(record['amount_settled']).toString()),
        };
        _editMode[index] = true;
      }
    });
  }

  Future<void> _saveRecord(int index) async {
    if (widget.selectedDate == null) return;

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
        'amount_settled': _parseDoubleValue(controllers['amount_settled']!.text),
        'credit_date': FormatUtils.formatDateForApi(widget.selectedDate!),
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
    if (widget.selectedSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector from Home page')),
      );
      return;
    }
    if (widget.selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final purchaseDetailsController = TextEditingController();
    final creditAmountController = TextEditingController();
    final amountSettledController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              amountSettledController.dispose();
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
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveNewCredit(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        purchaseDetails: purchaseDetailsController.text.trim(),
        creditAmount: _parseDoubleValue(creditAmountController.text),
        amountSettled: _parseDoubleValue(amountSettledController.text),
      );
    }

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    purchaseDetailsController.dispose();
    creditAmountController.dispose();
    amountSettledController.dispose();
  }

  Future<void> _saveNewCredit({
    required String name,
    required String phone,
    required String address,
    required String purchaseDetails,
    required double creditAmount,
    required double amountSettled,
  }) async {
    if (widget.selectedDate == null || widget.selectedSector == null) return;

    setState(() => _isLoading = true);
    try {
      final record = {
        'sector_code': widget.selectedSector,
        'name': name,
        'phone_number': phone.isEmpty ? null : phone,
        'address': address.isEmpty ? null : address,
        'purchase_details': purchaseDetails.isEmpty ? null : purchaseDetails,
        'credit_amount': creditAmount,
        'amount_settled': amountSettled,
        'credit_date': FormatUtils.formatDateForApi(widget.selectedDate!),
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
    if (widget.selectedMonth == null || widget.selectedDate == null) {
      return const Center(
        child: Text(
          'Please select month and date',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (widget.selectedSector == null && !widget.isAdmin) {
      return const Center(
        child: Text(
          'Please select a sector from Home page',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _creditData.isEmpty
                  ? const Center(
                      child: Text(
                        'No credit data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _buildCreditTable(),
        ),
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
    );
  }

  double _creditTableWidth() {
    final showSector = widget.selectedSector == null && widget.isAdmin;
    final n = showSector ? 8 : 7;
    double w = showSector ? _colSector : 0;
    w += _colName + _colPhone + _colAddress + _colPurchase + _colAmount * 2 + _colAction;
    return w + (n - 1) * _colSpacing;
  }

  Widget _buildCreditTable() {
    final showSector = widget.selectedSector == null && widget.isAdmin;
    final totalWidth = _creditTableWidth();
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final List<Widget> headerChildren = [];
    void addCol(double w, Widget c) {
      if (headerChildren.isNotEmpty) headerChildren.add(SizedBox(width: _colSpacing));
      headerChildren.add(SizedBox(width: w, child: c));
    }
    if (showSector) addCol(_colSector, const Text('Sector', style: bold));
    addCol(_colName, const Text('Name', style: bold));
    addCol(_colPhone, const Text('Phone Number', style: bold));
    addCol(_colAddress, const Text('Address', style: bold));
    addCol(_colPurchase, const Text('Purchase Details', style: bold));
    addCol(_colAmount, const Text('Credit Amount', style: bold));
    addCol(_colAmount, const Text('Amount Settled', style: bold));
    addCol(_colAction, const Text('Action', style: bold));

    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: totalWidth,
      headerHeight: _headerHeight,
      headerBuilder: (context) => Row(children: headerChildren),
      rowCount: _creditData.length,
      rowBuilder: (context, index) {
        final record = _creditData[index];
        final isEditMode = _editMode[index] == true;
        final List<Widget> rowChildren = [];
        void addCell(double w, Widget c) {
          if (rowChildren.isNotEmpty) rowChildren.add(SizedBox(width: _colSpacing));
          rowChildren.add(SizedBox(width: w, child: c));
        }
        if (showSector) addCell(_colSector, Text(_getSectorName(record['sector_code']?.toString())));
        addCell(_colName, isEditMode && _controllers.containsKey(index)
            ? SizedBox(width: 150, child: TextFormField(
                controller: _controllers[index]!['name'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ))
            : Text(record['name']?.toString() ?? ''));
        addCell(_colPhone, isEditMode && _controllers.containsKey(index)
            ? SizedBox(width: 150, child: TextFormField(
                controller: _controllers[index]!['phone_number'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.phone,
              ))
            : Text(record['phone_number']?.toString() ?? 'N/A'));
        addCell(_colAddress, SizedBox(width: 200, child: isEditMode && _controllers.containsKey(index)
            ? TextFormField(
                controller: _controllers[index]!['address'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                maxLines: 2,
              )
            : Text(record['address']?.toString() ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis)));
        addCell(_colPurchase, SizedBox(width: 200, child: isEditMode && _controllers.containsKey(index)
            ? TextFormField(
                controller: _controllers[index]!['purchase_details'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                maxLines: 2,
              )
            : Text(record['purchase_details']?.toString() ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis)));
        addCell(_colAmount, isEditMode && _controllers.containsKey(index)
            ? SizedBox(width: 120, child: TextFormField(
                controller: _controllers[index]!['credit_amount'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ))
            : Text('₹${_parseDecimalFromDynamic(record['credit_amount']).toStringAsFixed(2)}'));
        addCell(_colAmount, isEditMode && _controllers.containsKey(index)
            ? SizedBox(width: 120, child: TextFormField(
                controller: _controllers[index]!['amount_settled'],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ))
            : Text('₹${_parseDecimalFromDynamic(record['amount_settled']).toStringAsFixed(2)}'));
        addCell(_colAction, isEditMode
            ? IconButton(icon: const Icon(Icons.save, color: Colors.green, size: 20), tooltip: 'Save', onPressed: () => _saveRecord(index))
            : IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Edit', onPressed: () => _toggleEditMode(index)));
        return Row(children: rowChildren);
      },
    );
  }
}
