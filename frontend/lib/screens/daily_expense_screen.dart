import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class DailyExpenseScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final int? preSelectedMonth;
  final DateTime? preSelectedDate;

  const DailyExpenseScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.preSelectedMonth,
    this.preSelectedDate,
  });

  @override
  State<DailyExpenseScreen> createState() => _DailyExpenseScreenState();
}

class _DailyExpenseScreenState extends State<DailyExpenseScreen> {
  int? _selectedMonth;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _expenseData = [];
  Map<String, double> _sectorExpenseSummary = {}; // sector_code -> total amount
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.preSelectedMonth ?? DateTime.now().month;
    _selectedDate = widget.preSelectedDate ?? DateTime.now();
    _loadSectors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDate != null) {
        _loadExpenseData();
      }
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
      // Handle error silently or show snackbar if needed
    }
  }

  // Get sector name from code
  String _getSectorName(String? sectorCode) {
    if (sectorCode == null) return 'All Sectors';
    final sector = _sectors.firstWhere(
      (s) => s.code == sectorCode,
      orElse: () => Sector(code: sectorCode, name: sectorCode),
    );
    return sector.name;
  }

  // Calculate total expense across all sectors
  double _calculateTotalExpenseForAllSectors() {
    double total = 0.0;
    for (var amount in _sectorExpenseSummary.values) {
      total += amount;
    }
    return total;
  }

  Future<void> _selectMonth() async {
    final DateTime now = DateTime.now();
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int selectedMonth = _selectedMonth ?? now.month;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Month'),
              content: SizedBox(
                width: 300,
                height: 200,
                child: ListView.builder(
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final monthNames = [
                      'January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'
                    ];
                    return ListTile(
                      title: Text(monthNames[index]),
                      selected: selectedMonth == month,
                      onTap: () {
                        setState(() {
                          selectedMonth = month;
                        });
                        Navigator.pop(context, selectedMonth);
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
      await _loadExpenseData();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadExpenseData();
    }
  }

  Future<void> _loadExpenseData() async {
    if (_selectedDate == null) return;
    
    setState(() => _isLoading = true);
    try {
      final year = _selectedDate!.year;
      final month = _selectedMonth ?? _selectedDate!.month;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      
      if (widget.selectedSector == null) {
        // All Sectors selected - fetch all expenses and group by sector
        final records = await ApiService.getDailyExpenses(month: monthStr, date: dateStr);
        
        // Group expenses by sector and calculate totals
        final Map<String, double> sectorTotals = {};
        for (var record in records) {
          final sectorCode = record['sector_code']?.toString();
          if (sectorCode == null || sectorCode.isEmpty) {
            // Skip records with null or empty sector_code
            continue;
          }
          final amount = _parseDecimalFromDynamic(record['amount']);
          sectorTotals[sectorCode] = (sectorTotals[sectorCode] ?? 0.0) + amount;
        }
        
        if (mounted) {
          setState(() {
            _expenseData = [];
            _sectorExpenseSummary = sectorTotals;
          });
        }
      } else {
        // Single sector selected - show individual expense items
        final records = await ApiService.getDailyExpenses(month: monthStr, date: dateStr, sector: widget.selectedSector);
        
        if (mounted) {
          setState(() {
            _expenseData = records;
            _sectorExpenseSummary = {};
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expense data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper function to safely parse decimal from dynamic value
  double _parseDecimalFromDynamic(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Helper function to safely parse id from dynamic value
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

  // Calculate total expense for the day (single sector)
  double _calculateTotalExpense() {
    double total = 0.0;
    for (var record in _expenseData) {
      total += _parseDecimalFromDynamic(record['amount']);
    }
    return total;
  }

  // Build table for All Sectors view (summary by sector)
  Widget _buildAllSectorsSummaryTable() {
    if (_sectorExpenseSummary.isEmpty) {
      return DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Sector Name', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: const [
          DataRow(
            cells: [
              DataCell(
                Text(
                  'No expense data available',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              DataCell(SizedBox.shrink()),
            ],
          ),
        ],
      );
    }

    // Sort sectors by name for consistent display
    final sortedSectors = _sectorExpenseSummary.keys.toList()..sort();

    return DataTable(
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Sector Name', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        ...sortedSectors.map((sectorCode) {
          return DataRow(
            cells: [
              DataCell(Text(_getSectorName(sectorCode))),
              DataCell(Text('₹${_sectorExpenseSummary[sectorCode]!.toStringAsFixed(2)}')),
            ],
          );
        }),
        // Total Expense Row
        DataRow(
          color: WidgetStateProperty.all(Colors.purple.shade50),
          cells: [
            const DataCell(
              Text(
                'Total Expense',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            DataCell(
              Text(
                '₹${_calculateTotalExpenseForAllSectors().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build table for Single Sector view (individual expense items)
  Widget _buildSingleSectorTable() {
    return DataTable(
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Reason for Purchase', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: _expenseData.isEmpty
          ? [
              const DataRow(
                cells: [
                  DataCell(
                    Text(
                      'No expense data available',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                ],
              ),
            ]
          : [
              ..._expenseData.map((record) {
                return DataRow(
                  cells: [
                    DataCell(Text(record['item_details']?.toString() ?? '')),
                    DataCell(Text('₹${_parseDecimalFromDynamic(record['amount']).toStringAsFixed(2)}')),
                    DataCell(Text(record['reason_for_purchase']?.toString() ?? '')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            tooltip: 'Edit',
                            onPressed: () => _editExpenseData(record),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: 'Delete',
                            onPressed: () => _deleteExpenseData(record['id']),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              // Total Expense Row
              DataRow(
                color: WidgetStateProperty.all(Colors.purple.shade50),
                cells: [
                  const DataCell(
                    Text(
                      'Total Expense',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${_calculateTotalExpense().toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  const DataCell(SizedBox.shrink()),
                  const DataCell(SizedBox.shrink()),
                ],
              ),
            ],
    );
  }

  Future<void> _showAddExpenseDialog() async {
    if (widget.selectedSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector from Home page')),
      );
      return;
    }
    if (_selectedDate == null) {
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
      );
    }
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
      );
    }
  }

  Future<void> _saveExpenseData({
    String? id,
    required String itemDetails,
    required double amount,
    required String reason,
  }) async {
    if (_selectedDate == null || widget.selectedSector == null) return;

    setState(() => _isLoading = true);
    try {
      final record = {
        if (id != null) 'id': _parseIdFromDynamic(id),
        'item_details': itemDetails,
        'amount': amount,
        'reason_for_purchase': reason.isEmpty ? null : reason,
        'expense_date': _selectedDate!.toIso8601String().split('T')[0],
        'sector_code': widget.selectedSector,
      };

      await ApiService.saveDailyExpense(record);
      await _loadExpenseData();
      
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
      await _loadExpenseData();
      
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expense Details'),
        backgroundColor: Colors.purple.shade700,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 4),
                Text(
                  widget.username,
                  style: const TextStyle(fontSize: 16),
                ),
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
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.purple.shade100,
            ],
          ),
        ),
        child: Column(
          children: [
            // Month and Date Selection - only show if not pre-selected
            if (widget.preSelectedMonth == null && widget.preSelectedDate == null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectMonth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Month',
                            prefixIcon: const Icon(Icons.calendar_month, color: Colors.purple),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedMonth != null
                                ? [
                                    'January', 'February', 'March', 'April', 'May', 'June',
                                    'July', 'August', 'September', 'October', 'November', 'December'
                                  ][_selectedMonth! - 1]
                                : 'Select Month',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.purple),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _selectedDate != null
                                ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                                : 'Select Date',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Expense Table
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: widget.selectedSector == null
                        ? _buildAllSectorsSummaryTable()
                        : _buildSingleSectorTable(),
                  ),
                ),
              ),
            // Add Expense Item Button (only show for single sector view)
            if (widget.selectedSector != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showAddExpenseDialog,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Add Expense Items',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

