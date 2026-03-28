import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';
import '../utils/format_utils.dart';
import '../utils/pdf_generator.dart';
import '../widgets/fixed_header_table.dart';

class ExpenseTabContent extends StatefulWidget {
  final String? selectedSector;
  final int? selectedMonth;
  final DateTime? selectedDate;
  final bool isAdmin;

  const ExpenseTabContent({
    super.key,
    this.selectedSector,
    this.selectedMonth,
    this.selectedDate,
    this.isAdmin = false,
  });

  @override
  State<ExpenseTabContent> createState() => _ExpenseTabContentState();
}

class _ExpenseTabContentState extends State<ExpenseTabContent> {
  List<Map<String, dynamic>> _expenseData = [];
  Map<String, double> _sectorExpenseSummary = {};
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column
  
  // Horizontal ScrollController for draggable scrollbar
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSectors();
    if (widget.selectedMonth != null && widget.selectedDate != null) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(ExpenseTabContent oldWidget) {
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

      final expenses = await ApiService.getDailyExpenses(month: monthStr, date: dateStr, sector: widget.selectedSector);

      if (widget.selectedSector == null && widget.isAdmin) {
        // All Sectors view for Admin - show individual items with sector column
        setState(() {
          _expenseData = expenses;
          _sectorExpenseSummary = {};
        });
      } else if (widget.selectedSector == null) {
        // All Sectors view for non-admin - create summary (shouldn't happen, but keep for safety)
        final Map<String, double> summary = {};
        for (var expense in expenses) {
          final sectorCode = expense['sector_code']?.toString();
          if (sectorCode != null && sectorCode.isNotEmpty) {
            final amount = _parseDecimalFromDynamic(expense['amount']);
            summary[sectorCode] = (summary[sectorCode] ?? 0.0) + amount;
          }
        }
        setState(() {
          _sectorExpenseSummary = summary;
          _expenseData = [];
        });
      } else {
        // Single sector view - show individual items
        setState(() {
          _expenseData = expenses;
          _sectorExpenseSummary = {};
        });
      }
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

  double _calculateTotalExpense() {
    double total = 0.0;
    for (var record in _expenseData) {
      total += _parseDecimalFromDynamic(record['amount']);
    }
    return total;
  }

  double _calculateTotalExpenseForAllSectors() {
    double total = 0.0;
    for (var amount in _sectorExpenseSummary.values) {
      total += amount;
    }
    return total;
  }

  static const double _expenseSp = 20;
  static const double _expenseWSector = 150, _expenseWAmount = 120;

  Widget _buildAllSectorsSummaryTable() {
    const double leadW = _expenseWSector;
    const double scrollW = _expenseSp + _expenseWAmount;
    final sortedSectors = _sectorExpenseSummary.isEmpty ? <String>[] : (_sectorExpenseSummary.keys.toList()..sort());
    final rowCount = _sectorExpenseSummary.isEmpty ? 1 : sortedSectors.length + 1;
    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: scrollW,
      headerHeight: 48,
      leadingWidth: leadW,
      rowExtent: 96,
      leadingHeaderBuilder: (ctx) => const SizedBox(
        width: leadW,
        height: 48,
        child: Align(alignment: Alignment.centerLeft, child: Text('Sector Name', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
      headerBuilder: (ctx) => const Row(
        children: [
          SizedBox(width: _expenseSp),
          SizedBox(width: _expenseWAmount, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
      leadingRowBuilder: (ctx, index) {
        if (_sectorExpenseSummary.isEmpty) {
          return const SizedBox(
            width: leadW,
            child: Text('No expense data available', style: TextStyle(fontStyle: FontStyle.italic)),
          );
        }
        if (index == sortedSectors.length) {
          return Container(
            color: Colors.purple.shade50,
            width: leadW,
            alignment: Alignment.centerLeft,
            child: const Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          );
        }
        final sectorCode = sortedSectors[index];
        return SizedBox(width: leadW, child: Text(_getSectorName(sectorCode)));
      },
      rowCount: rowCount,
      rowBuilder: (ctx, index) {
        if (_sectorExpenseSummary.isEmpty) {
          return const Row(
            children: [
              SizedBox(width: _expenseSp),
              SizedBox(width: _expenseWAmount),
            ],
          );
        }
        if (index == sortedSectors.length) {
          return Container(
            color: Colors.purple.shade50,
            child: Row(
              children: [
                const SizedBox(width: _expenseSp),
                SizedBox(width: _expenseWAmount, child: Text(_calculateTotalExpenseForAllSectors().toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple))),
              ],
            ),
          );
        }
        final sectorCode = sortedSectors[index];
        return Row(
          children: [
            const SizedBox(width: _expenseSp),
            SizedBox(width: _expenseWAmount, child: Text('₹${_sectorExpenseSummary[sectorCode]!.toStringAsFixed(2)}')),
          ],
        );
      },
    );
  }

  static const double _singleWSector = 120, _singleWItem = 200, _singleWAmount = 100, _singleWReason = 200, _singleWActions = 140;

  Widget _buildSingleSectorTable() {
    final showSectorColumn = widget.isAdmin && widget.selectedSector == null;
    final double leadW = showSectorColumn ? _singleWSector : _singleWItem;
    final double scrollW = showSectorColumn
        ? (_expenseSp + _singleWItem + _expenseSp + _singleWAmount + _expenseSp + _singleWReason + _expenseSp + _singleWActions)
        : (_expenseSp + _singleWAmount + _expenseSp + _singleWReason + _expenseSp + _singleWActions);
    final rowCount = _expenseData.isEmpty ? 1 : _expenseData.length + 1;
    return FixedHeaderTable(
      horizontalScrollController: _horizontalScrollController,
      totalWidth: scrollW,
      headerHeight: 48,
      leadingWidth: leadW,
      rowExtent: 96,
      leadingHeaderBuilder: (ctx) => SizedBox(
        width: leadW,
        height: 48,
        child: showSectorColumn
            ? InkWell(
                onTap: () => setState(() {
                  _sortAscending = !_sortAscending;
                  _expenseData.sort((a, b) {
                    final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                    final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                    return _sortAscending ? aName.compareTo(bName) : bName.compareTo(aName);
                  });
                }),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                    ],
                  ),
                ),
              )
            : const Align(alignment: Alignment.centerLeft, child: Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
      headerBuilder: (ctx) => Row(
        children: [
          if (showSectorColumn) ...[
            const SizedBox(width: _singleWItem, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(width: _expenseSp),
          ],
          const SizedBox(width: _singleWAmount, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(width: _expenseSp),
          const SizedBox(width: _singleWReason, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Reason for Purchase', style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(width: _expenseSp),
          const SizedBox(width: _singleWActions, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
      leadingRowBuilder: (ctx, index) {
        if (_expenseData.isEmpty) {
          return SizedBox(
            width: leadW,
            child: const Text('No expense data available', style: TextStyle(fontStyle: FontStyle.italic)),
          );
        }
        if (index == _expenseData.length) {
          return Container(
            color: Colors.purple.shade50,
            width: leadW,
            alignment: Alignment.centerLeft,
            child: Text(showSectorColumn ? '' : 'Total Expense', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          );
        }
        final record = _expenseData[index];
        return SizedBox(
          width: leadW,
          child: Text(showSectorColumn ? _getSectorName(record['sector_code']?.toString()) : (record['item_details']?.toString() ?? '')),
        );
      },
      rowCount: rowCount,
      rowBuilder: (ctx, index) {
        if (_expenseData.isEmpty) {
          return Row(
            children: [
              if (showSectorColumn) ...[
                const SizedBox(width: _singleWItem),
                const SizedBox(width: _expenseSp),
              ],
              const SizedBox(width: _singleWAmount),
              const SizedBox(width: _expenseSp),
              const SizedBox(width: _singleWReason),
              const SizedBox(width: _expenseSp),
              const SizedBox(width: _singleWActions),
            ],
          );
        }
        if (index == _expenseData.length) {
          return Container(
            color: Colors.purple.shade50,
            child: Row(
              children: [
                if (showSectorColumn) ...[
                  const SizedBox(width: _singleWItem, child: Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: _expenseSp),
                ],
                SizedBox(width: _singleWAmount, child: Text(_calculateTotalExpense().toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple))),
                const SizedBox(width: _expenseSp),
                const SizedBox(width: _singleWReason),
                const SizedBox(width: _expenseSp),
                const SizedBox(width: _singleWActions),
              ],
            ),
          );
        }
        final record = _expenseData[index];
        final actionButtons = <Widget>[
          IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewExpenseData(record)),
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), tooltip: 'Edit', onPressed: () => _editExpenseData(record)),
          if (widget.isAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Delete', onPressed: () => _deleteExpenseData(record['id'])),
        ];
        return Row(
          children: [
            if (showSectorColumn) ...[
              SizedBox(width: _singleWItem, child: Text(record['item_details']?.toString() ?? '')),
              const SizedBox(width: _expenseSp),
            ],
            SizedBox(width: _singleWAmount, child: Text(_parseDecimalFromDynamic(record['amount']).toStringAsFixed(2))),
            const SizedBox(width: _expenseSp),
            SizedBox(width: _singleWReason, child: Text(record['reason_for_purchase']?.toString() ?? '')),
            const SizedBox(width: _expenseSp),
            SizedBox(width: _singleWActions, child: Row(mainAxisSize: MainAxisSize.min, children: actionButtons)),
          ],
        );
      },
    );
  }

  Future<void> _showAddExpenseDialog() async {
    if (widget.selectedSector == null && !widget.isAdmin) {
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

    final itemDetailsController = TextEditingController();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Item Details *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Purchase',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (itemDetailsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item Details is required')),
                );
                return;
              }
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amount is required')),
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
      await _saveExpenseData(
        itemDetails: itemDetailsController.text.trim(),
        amount: _parseDoubleValue(amountController.text),
        reason: reasonController.text.trim(),
        sectorCode: widget.selectedSector,
      );
    }
  }

  Future<void> _viewExpenseData(Map<String, dynamic> record) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expense Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isAdmin && widget.selectedSector == null)
                _buildViewField('Sector', _getSectorName(record['sector_code']?.toString())),
              _buildViewField('Item Details', record['item_details']?.toString() ?? 'N/A'),
              _buildViewField('Amount', _parseDecimalFromDynamic(record['amount']).toStringAsFixed(2)),
              _buildViewField('Reason for Purchase', record['reason_for_purchase']?.toString() ?? 'N/A'),
              _buildViewField('Expense Date', record['expense_date']?.toString() ?? 'N/A'),
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

  Future<void> _editExpenseData(Map<String, dynamic> record) async {
    final itemDetailsController = TextEditingController(
      text: record['item_details']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: _parseDecimalFromDynamic(record['amount']).toString(),
    );
    final reasonController = TextEditingController(
      text: record['reason_for_purchase']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Expense Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Item Details *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Purchase',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (itemDetailsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item Details is required')),
                );
                return;
              }
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amount is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final recordId = _parseIdFromDynamic(record['id']);
      await _saveExpenseData(
        id: recordId?.toString(),
        itemDetails: itemDetailsController.text.trim(),
        amount: _parseDoubleValue(amountController.text),
        reason: reasonController.text.trim(),
        sectorCode: record['sector_code']?.toString() ?? widget.selectedSector,
      );
    }
  }

  Future<void> _saveExpenseData({
    String? id,
    required String itemDetails,
    required double amount,
    required String reason,
    String? sectorCode,
  }) async {
    if (widget.selectedDate == null) return;
    if (widget.selectedSector == null && !widget.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      final record = {
        if (id != null) 'id': _parseIdFromDynamic(id),
        'item_details': itemDetails,
        'amount': amount,
        'reason_for_purchase': reason.isEmpty ? null : reason,
        'expense_date': FormatUtils.formatDateForApi(widget.selectedDate!),
        'sector_code': sectorCode ?? widget.selectedSector,
      };

      await ApiService.saveDailyExpense(record);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense data saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense data: $e')),
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
                      initialDate: fromDate ?? widget.selectedDate ?? DateTime.now(),
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
                    child: Text(fromDate != null ? FormatUtils.formatDateForApi(fromDate!) : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: toDate ?? widget.selectedDate ?? DateTime.now(),
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
                    child: Text(toDate != null ? FormatUtils.formatDateForApi(toDate!) : 'Select Date'),
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
      await _generateExpenseStatement(
        result['fromDate'] as DateTime,
        result['toDate'] as DateTime,
      );
    }
  }

  Future<void> _generateExpenseStatement(DateTime fromDate, DateTime toDate) async {
    // Format is always PDF now
    try {
      setState(() => _isLoading = true);
      
      // Collect all expenses for months in the date range
      List<Map<String, dynamic>> allExpenses = [];
      DateTime current = DateTime(fromDate.year, fromDate.month);
      final endMonth = DateTime(toDate.year, toDate.month);
      
      while (current.isBefore(endMonth) || current.isAtSameMomentAs(endMonth)) {
        final monthStr = '${current.year}-${current.month.toString().padLeft(2, '0')}';
        try {
          final expenses = await ApiService.getDailyExpenses(
            month: monthStr,
            date: null,
            sector: widget.selectedSector,
          );
          allExpenses.addAll(expenses);
        } catch (e) {
          // Continue with next month if error
        }
        current = DateTime(current.year, current.month + 1);
      }

      // Filter by date range
      final filteredData = allExpenses.where((record) {
        final expenseDateStr = record['expense_date']?.toString();
        if (expenseDateStr == null) return false;
        try {
          final dateStr = expenseDateStr.split('T')[0].split(' ')[0];
          final expenseDate = DateTime.parse(dateStr);
          return (expenseDate.isAfter(fromDate.subtract(const Duration(days: 1))) && 
                  expenseDate.isBefore(toDate.add(const Duration(days: 1)))) ||
                 expenseDate.isAtSameMomentAs(fromDate) ||
                 expenseDate.isAtSameMomentAs(toDate);
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
        await PdfGenerator.generateAndDownloadExpensePDF(
          expenseData: filteredData,
          date: fromDate,
          dateTo: toDate,
          sectorName: sectorName,
          showSectorColumn: widget.selectedSector == null && widget.isAdmin,
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


  Future<void> _deleteExpenseData(dynamic id) async {
    final idString = id?.toString();
    if (idString == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Record'),
        content: const Text('Are you sure you want to delete this expense record?'),
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
      await ApiService.deleteDailyExpense(idString);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense record deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense record: $e')),
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

    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (widget.selectedSector == null && !widget.isAdmin
                  ? _buildAllSectorsSummaryTable()
                  : _buildSingleSectorTable()),
        ),
        if (widget.selectedSector != null || (widget.isAdmin && widget.selectedSector == null))
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showAddExpenseDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense Items', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (widget.isAdmin) ...[
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
    );
  }
}

