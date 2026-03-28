import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format_utils.dart';
import '../utils/pdf_generator.dart';
import '../widgets/fixed_header_table.dart';
import '../widgets/sector_notes_app_bar_button.dart';
import 'home_screen.dart';
import 'month_year_picker.dart';

class DailyIncomeExpenseScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const DailyIncomeExpenseScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<DailyIncomeExpenseScreen> createState() => _DailyIncomeExpenseScreenState();
}

class _DailyIncomeExpenseScreenState extends State<DailyIncomeExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Daily Income/Expense state
  List<Map<String, dynamic>> _incomeExpenseData = [];
  DateTime _selectedIncomeExpenseDate = DateTime.now();
  bool _isLoadingIncomeExpense = false;
  final Map<int, Map<String, TextEditingController>> _incomeExpenseControllers = {};
  final Map<int, bool> _editModeIncomeExpense = {};

  // Overall Income/Expense state
  List<Map<String, dynamic>> _overallData = [];
  bool _isLoadingOverall = false;
  final List<DateTime> _selectedDates = [];
  final List<String> _selectedMonths = [];
  DateTime? _tempSelectedDate;
  String? _tempSelectedMonth;
  
  // Horizontal ScrollControllers for draggable scrollbars (separate for each tab)
  final ScrollController _dailyTabHorizontalScrollController = ScrollController();
  final ScrollController _overallTabHorizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    if (widget.selectedSector != null) {
      _loadIncomeExpenseData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    _dailyTabHorizontalScrollController.dispose();
    _overallTabHorizontalScrollController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (var controllers in _incomeExpenseControllers.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    _incomeExpenseControllers.clear();
  }

  // Helper function to safely parse amount values (handles both String and num types)
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Daily Income/Expense Tab Methods
  Future<void> _loadIncomeExpenseData() async {
    if (widget.selectedSector == null) return;

    setState(() => _isLoadingIncomeExpense = true);
    try {
      final dateStr = FormatUtils.formatDateForApi(_selectedIncomeExpenseDate);
      final data = await ApiService.getDailyIncomeExpense(
        sector: widget.selectedSector!,
        date: dateStr,
      );
      setState(() {
        _incomeExpenseData = data;
        _editModeIncomeExpense.clear();
        _disposeControllers();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading income/expense: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingIncomeExpense = false);
      }
    }
  }

  Future<void> _addIncomeExpenseItem() async {
    if (widget.selectedSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector first'), backgroundColor: Colors.red),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddIncomeExpenseDialog(),
    );

    if (result != null) {
      setState(() => _isLoadingIncomeExpense = true);
      try {
        final dateStr = FormatUtils.formatDateForApi(_selectedIncomeExpenseDate);
        await ApiService.saveDailyIncomeExpense({
          'sector_code': widget.selectedSector,
          'item_name': result['item_name'] ?? '',
          'quantity': result['quantity'] ?? '',
          'income_amount': result['income_amount'] ?? 0,
          'expense_amount': result['expense_amount'] ?? 0,
          'entry_date': dateStr,
        });
        await _loadIncomeExpenseData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding item: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingIncomeExpense = false);
        }
      }
    }
  }

  void _editIncomeExpenseItem(int index) {
    final item = _incomeExpenseData[index];
    setState(() {
      _editModeIncomeExpense[index] = true;
      _incomeExpenseControllers[index] = {
        'item_name': TextEditingController(text: item['item_name']?.toString() ?? ''),
        'quantity': TextEditingController(text: item['quantity']?.toString() ?? ''),
        'income_amount': TextEditingController(
          text: _parseAmount(item['income_amount']).toString(),
        ),
        'expense_amount': TextEditingController(
          text: _parseAmount(item['expense_amount']).toString(),
        ),
      };
    });
  }

  Future<void> _saveIncomeExpenseItem(int index) async {
    final item = _incomeExpenseData[index];
    final controllers = _incomeExpenseControllers[index];
    if (controllers == null) return;

    setState(() => _isLoadingIncomeExpense = true);
    try {
      final dateStr = FormatUtils.formatDateForApi(_selectedIncomeExpenseDate);
      await ApiService.saveDailyIncomeExpense({
        'id': item['id'],
        'sector_code': widget.selectedSector,
        'item_name': controllers['item_name']!.text.trim().isEmpty
            ? null
            : controllers['item_name']!.text.trim(),
        'quantity': controllers['quantity']!.text.trim().isEmpty
            ? null
            : controllers['quantity']!.text.trim(),
        'income_amount': double.tryParse(controllers['income_amount']!.text) ?? 0,
        'expense_amount': double.tryParse(controllers['expense_amount']!.text) ?? 0,
        'entry_date': dateStr,
      });
      await _loadIncomeExpenseData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingIncomeExpense = false);
      }
    }
  }

  Future<void> _deleteIncomeExpenseItem(int index) async {
    final item = _incomeExpenseData[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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

    setState(() => _isLoadingIncomeExpense = true);
    try {
      await ApiService.deleteDailyIncomeExpense(item['id'].toString());
      await _loadIncomeExpenseData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingIncomeExpense = false);
      }
    }
  }

  Widget _buildDailyIncomeExpenseTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedIncomeExpenseDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedIncomeExpenseDate = picked;
                    });
                    _loadIncomeExpenseData();
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${_selectedIncomeExpenseDate.year}-${_selectedIncomeExpenseDate.month.toString().padLeft(2, '0')}-${_selectedIncomeExpenseDate.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingIncomeExpense
                ? const Center(child: CircularProgressIndicator())
                : _incomeExpenseData.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No data available for selected date'),
                        ),
                      )
                    : _buildIncomeExpenseTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseTable() {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var item in _incomeExpenseData) {
      // Safely parse income_amount (handle both String and num types)
      final incomeValue = item['income_amount'];
      if (incomeValue is num) {
        totalIncome += incomeValue.toDouble();
      } else if (incomeValue is String) {
        totalIncome += double.tryParse(incomeValue) ?? 0;
      }
      
      // Safely parse expense_amount (handle both String and num types)
      final expenseValue = item['expense_amount'];
      if (expenseValue is num) {
        totalExpense += expenseValue.toDouble();
      } else if (expenseValue is String) {
        totalExpense += double.tryParse(expenseValue) ?? 0;
      }
    }

    const double sp = 20;
    const double wItem = 150, wQty = 100, wIncome = 120, wExpense = 120, wAction = 160;
    const totalWidth = wItem + sp + wQty + sp + wIncome + sp + wExpense + sp + wAction;
    return FixedHeaderTable(
      horizontalScrollController: _dailyTabHorizontalScrollController,
      totalWidth: (sp + wQty + sp + wIncome + sp + wExpense + sp + wAction).toDouble(),
      headerHeight: 52,
      rowExtent: 96,
      leadingWidth: wItem,
      leadingHeaderBuilder: (ctx) => Container(
        color: Colors.blue.shade100,
        child: const SizedBox(
          width: wItem,
          height: 48,
          child: Align(alignment: Alignment.centerLeft, child: Text('Item Name')),
        ),
      ),
      headerBuilder: (ctx) => Container(
        color: Colors.blue.shade100,
        child: const Row(
          children: [
            SizedBox(width: sp),
            SizedBox(width: wQty, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Quantity'))),
            SizedBox(width: sp),
            SizedBox(width: wIncome, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Income'))),
            SizedBox(width: sp),
            SizedBox(width: wExpense, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Expense'))),
            SizedBox(width: sp),
            SizedBox(width: wAction, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Action'))),
          ],
        ),
      ),
      rowCount: _incomeExpenseData.length + 1,
      leadingRowBuilder: (ctx, index) {
        if (index == _incomeExpenseData.length) {
          return const SizedBox(
            width: wItem,
            child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
          );
        }
        final item = _incomeExpenseData[index];
        final isEditing = _editModeIncomeExpense[index] ?? false;
        final controllers = _incomeExpenseControllers[index] ?? {};
        return SizedBox(
          width: wItem,
          child: isEditing
              ? SizedBox(
                  width: 150,
                  child: TextField(
                    controller: controllers['item_name'],
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                )
              : Text(item['item_name']?.toString() ?? ''),
        );
      },
      rowBuilder: (ctx, index) {
        if (index == _incomeExpenseData.length) {
          return Container(
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const SizedBox(width: sp),
                const SizedBox(width: wQty),
                const SizedBox(width: sp),
                SizedBox(width: wIncome, child: Text('₹${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: sp),
                SizedBox(width: wExpense, child: Text('₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: sp),
                const SizedBox(width: wAction),
              ],
            ),
          );
        }
        final item = _incomeExpenseData[index];
        final isEditing = _editModeIncomeExpense[index] ?? false;
        final controllers = _incomeExpenseControllers[index] ?? {};
        return Row(
          children: [
            const SizedBox(width: sp),
            SizedBox(width: wQty, child: isEditing ? SizedBox(width: 100, child: TextField(controller: controllers['quantity'], decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))) : Text(item['quantity']?.toString() ?? '')),
            const SizedBox(width: sp),
            SizedBox(width: wIncome, child: isEditing ? SizedBox(width: 120, child: TextField(controller: controllers['income_amount'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))) : Text('₹${_parseAmount(item['income_amount']).toStringAsFixed(2)}')),
            const SizedBox(width: sp),
            SizedBox(width: wExpense, child: isEditing ? SizedBox(width: 120, child: TextField(controller: controllers['expense_amount'], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))) : Text('₹${_parseAmount(item['expense_amount']).toStringAsFixed(2)}')),
            const SizedBox(width: sp),
            SizedBox(width: wAction, child: Row(mainAxisSize: MainAxisSize.min, children: [if (isEditing) IconButton(icon: const Icon(Icons.save, color: Colors.green), tooltip: 'Save', onPressed: () => _saveIncomeExpenseItem(index)) else IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Edit', onPressed: () => _editIncomeExpenseItem(index)), if (widget.isMainAdmin) IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Delete', onPressed: () => _deleteIncomeExpenseItem(index))])),
          ],
        );
      },
    );
  }

  // Overall Income/Expense Tab Methods
  Future<void> _loadOverallData() async {
    if (_selectedDates.isEmpty && _selectedMonths.isEmpty) {
      setState(() {
        _overallData = [];
      });
      return;
    }

    setState(() => _isLoadingOverall = true);
    try {
      final data = await ApiService.getOverallIncomeExpense(
        dates: _selectedDates.map((d) => FormatUtils.formatDateForApi(d)).toList(),
        months: _selectedMonths,
      );
      setState(() {
        _overallData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading overall data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOverall = false);
      }
    }
  }

  Future<void> _addDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _tempSelectedDate = picked;
        final dateStr = FormatUtils.formatDateForApi(picked);
        if (!_selectedDates.any((d) => FormatUtils.formatDateForApi(d) == dateStr)) {
          _selectedDates.add(picked);
          _selectedDates.sort();
        }
      });
      _loadOverallData();
    }
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.removeWhere((d) => FormatUtils.formatDateForApi(d) == FormatUtils.formatDateForApi(date));
    });
    _loadOverallData();
  }

  Future<void> _addMonth() async {
    final now = DateTime.now();
    final initialDate = _tempSelectedMonth != null
        ? DateTime.parse('$_tempSelectedMonth-01')
        : DateTime(now.year, now.month);
    
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => MonthYearPicker(
        initialDate: initialDate,
        firstDate: DateTime(2020, 1),
        lastDate: DateTime(2100, 12),
      ),
    );

    if (picked != null) {
      final monthStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      setState(() {
        _tempSelectedMonth = monthStr;
        if (!_selectedMonths.contains(monthStr)) {
          _selectedMonths.add(monthStr);
          _selectedMonths.sort();
        }
      });
      _loadOverallData();
    }
  }

  void _removeMonth(String month) {
    setState(() {
      _selectedMonths.remove(month);
    });
    _loadOverallData();
  }

  Future<void> _downloadPDF() async {
    if (_overallData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to download'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      await PdfGenerator.generateOverallIncomeExpenseReport(
        data: _overallData,
        selectedDates: _selectedDates,
        selectedMonths: _selectedMonths,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF downloaded successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOverallIncomeExpenseTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Date and Month Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Dates and Months',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addDate,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Add Date'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addMonth,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Add Month'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDates.isNotEmpty || _selectedMonths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._selectedDates.map((date) {
                          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          return Chip(
                            label: Text(dateStr),
                            onDeleted: () => _removeDate(date),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }),
                        ..._selectedMonths.map((month) {
                          return Chip(
                            label: Text(month),
                            onDeleted: () => _removeMonth(month),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Table
          Expanded(
            child: _isLoadingOverall
                ? const Center(child: CircularProgressIndicator())
                : _overallData.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Select dates or months to view data'),
                        ),
                      )
                    : _buildOverallTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallTable() {
    double grandTotalIncome = 0;
    double grandTotalExpense = 0;

    for (var item in _overallData) {
      grandTotalIncome += _parseAmount(item['total_income']);
      grandTotalExpense += _parseAmount(item['total_expense']);
    }

    const double sp = 20;
    const double wSector = 150, wIncome = 130, wExpense = 130;
    const totalWidth = wSector + sp + wIncome + sp + wExpense;
    return FixedHeaderTable(
      horizontalScrollController: _overallTabHorizontalScrollController,
      totalWidth: (sp + wIncome + sp + wExpense).toDouble(),
      headerHeight: 52,
      rowExtent: 96,
      leadingWidth: wSector,
      leadingHeaderBuilder: (ctx) => Container(
        color: Colors.blue.shade100,
        child: const SizedBox(
          width: wSector,
          height: 48,
          child: Align(alignment: Alignment.centerLeft, child: Text('Sector Name')),
        ),
      ),
      headerBuilder: (ctx) => Container(
        color: Colors.blue.shade100,
        child: const Row(
          children: [
            SizedBox(width: sp),
            SizedBox(width: wIncome, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Total Income'))),
            SizedBox(width: sp),
            SizedBox(width: wExpense, height: 48, child: Align(alignment: Alignment.centerLeft, child: Text('Total Expense'))),
          ],
        ),
      ),
      rowCount: _overallData.length + 1,
      leadingRowBuilder: (ctx, index) {
        if (index == _overallData.length) {
          return const SizedBox(
            width: wSector,
            child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
          );
        }
        final item = _overallData[index];
        return SizedBox(
          width: wSector,
          child: Text(item['sector_name']?.toString() ?? ''),
        );
      },
      rowBuilder: (ctx, index) {
        if (index == _overallData.length) {
          return Container(
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const SizedBox(width: sp),
                SizedBox(width: wIncome, child: Text('₹${grandTotalIncome.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: sp),
                SizedBox(width: wExpense, child: Text('₹${grandTotalExpense.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }
        final item = _overallData[index];
        return Row(
          children: [
            const SizedBox(width: sp),
            SizedBox(width: wIncome, child: Text('₹${_parseAmount(item['total_income']).toStringAsFixed(2)}')),
            const SizedBox(width: sp),
            SizedBox(width: wExpense, child: Text('₹${_parseAmount(item['total_expense']).toStringAsFixed(2)}')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Income and Expense Details'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily Income/Expense'),
            Tab(text: 'Overall Income/Expense'),
          ],
        ),
        actions: [
          SectorNotesAppBarButton(sectorCode: widget.selectedSector),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: widget.username,
                    initialSectorCodes: AuthService.initialSectorCodes,
                    isAdmin: AuthService.isAdmin,
                    isMainAdmin: widget.isMainAdmin,
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Action button: top-right in body, just below AppBar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_tabController.index == 0)
                  ElevatedButton.icon(
                    onPressed: _addIncomeExpenseItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (_tabController.index == 1 && _overallData.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _downloadPDF,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download PDF', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyIncomeExpenseTab(),
                _buildOverallIncomeExpenseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddIncomeExpenseDialog extends StatefulWidget {
  @override
  State<_AddIncomeExpenseDialog> createState() => _AddIncomeExpenseDialogState();
}

class _AddIncomeExpenseDialogState extends State<_AddIncomeExpenseDialog> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _incomeController.dispose();
    _expenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Income/Expense Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _incomeController,
              decoration: const InputDecoration(
                labelText: 'Income Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _expenseController,
              decoration: const InputDecoration(
                labelText: 'Expense Amount',
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'item_name': _itemNameController.text.trim(),
              'quantity': _quantityController.text.trim(),
              'income_amount': double.tryParse(_incomeController.text) ?? 0,
              'expense_amount': double.tryParse(_expenseController.text) ?? 0,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

