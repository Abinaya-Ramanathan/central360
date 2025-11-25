import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class DailyProductionScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final int? preSelectedMonth;
  final DateTime? preSelectedDate;

  const DailyProductionScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.preSelectedMonth,
    this.preSelectedDate,
  });

  @override
  State<DailyProductionScreen> createState() => _DailyProductionScreenState();
}

class _DailyProductionScreenState extends State<DailyProductionScreen> {
  int? _selectedMonth;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _productionData = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.preSelectedMonth ?? DateTime.now().month;
    _selectedDate = widget.preSelectedDate ?? DateTime.now();
    _loadSectors();
    // Load products first, then production data after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.selectedSector != null) {
        await _loadProducts();
        if (_selectedDate != null) {
          await _loadProductionData();
        }
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

  Future<void> _loadProducts({bool showLoading = true}) async {
    print('Daily Production: _loadProducts() called, sector: ${widget.selectedSector}, showLoading: $showLoading');
    if (widget.selectedSector == null) {
      print('Daily Production: No sector selected, returning early');
      return;
    }

    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final products = await ApiService.getProducts(sector: widget.selectedSector);
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      // Reload products if sector is selected, then load production data
      if (widget.selectedSector != null) {
        await _loadProducts();
      }
      await _loadProductionData();
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
      await _loadProductionData();
    }
  }

  Future<void> _loadProductionData() async {
    if (_selectedDate == null) {
      print('Daily Production: Cannot load production data - date is null');
      return;
    }
    
    // Always ensure products are loaded first
    if (widget.selectedSector == null) {
      print('Daily Production: Cannot load production data - no sector selected');
      if (mounted) {
        setState(() {
          _productionData = [];
        });
      }
      return;
    }
    
    if (_products.isEmpty) {
      await _loadProducts(showLoading: false);
      
      if (_products.isEmpty) {
        if (mounted) {
          setState(() {
            _productionData = [];
            _isLoading = false;
          });
        }
        return;
      }
    }
    
    setState(() => _isLoading = true);
    try {
      final year = _selectedDate!.year;
      final month = _selectedMonth ?? _selectedDate!.month;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      
      final records = await ApiService.getDailyProduction(month: monthStr, date: dateStr);
      
      // Create a map of existing records by product name
      final Map<String, Map<String, dynamic>> existingRecordsMap = {};
      for (var record in records) {
        final productName = record['product_name']?.toString() ?? '';
        existingRecordsMap[productName] = record;
      }
      
      // Build the final list: products from database (with saved data if exists, or empty entries)
      final List<Map<String, dynamic>> finalData = [];
      
      for (var product in _products) {
        final productName = product['product_name']?.toString() ?? '';
        if (existingRecordsMap.containsKey(productName)) {
          // Use saved data
          finalData.add(existingRecordsMap[productName]!);
          existingRecordsMap.remove(productName);
        } else {
          // Add empty entry for product
          finalData.add({
            'product_name': productName,
            'morning_production': 0,
            'afternoon_production': 0,
            'evening_production': 0,
            'production_date': dateStr,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _productionData = finalData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading production data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper function to safely parse int from dynamic value
  int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
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

  int _parseIntValue(String value) {
    if (value.isEmpty) return 0;
    final parsed = int.tryParse(value);
    return parsed ?? 0;
  }

  Future<void> _showEditProductionDialog() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    if (_productionData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available for this sector')),
      );
      return;
    }

    // Create controllers for each product
    final Map<String, TextEditingController> morningControllers = {};
    final Map<String, TextEditingController> afternoonControllers = {};
    final Map<String, TextEditingController> eveningControllers = {};

    for (var record in _productionData) {
      final productName = record['product_name']?.toString() ?? '';
      morningControllers[productName] = TextEditingController(
        text: _parseIntFromDynamic(record['morning_production']).toString(),
      );
      afternoonControllers[productName] = TextEditingController(
        text: _parseIntFromDynamic(record['afternoon_production']).toString(),
      );
      eveningControllers[productName] = TextEditingController(
        text: _parseIntFromDynamic(record['evening_production']).toString(),
      );
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Production Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _productionData.map((record) {
                final productName = record['product_name']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: morningControllers[productName],
                              decoration: const InputDecoration(
                                labelText: 'Morning',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: afternoonControllers[productName],
                              decoration: const InputDecoration(
                                labelText: 'Afternoon',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: eveningControllers[productName],
                              decoration: const InputDecoration(
                                labelText: 'Evening',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Dispose controllers
              for (var controller in morningControllers.values) {
                controller.dispose();
              }
              for (var controller in afternoonControllers.values) {
                controller.dispose();
              }
              for (var controller in eveningControllers.values) {
                controller.dispose();
              }
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Save all production data
              setState(() => _isLoading = true);
              try {
                final dateStr = _selectedDate!.toIso8601String().split('T')[0];
                
                for (var record in _productionData) {
                  final productName = record['product_name']?.toString() ?? '';
                  final recordId = _parseIdFromDynamic(record['id']);
                  
                  final productionRecord = {
                    if (recordId != null) 'id': recordId,
                    'product_name': productName,
                    'morning_production': _parseIntValue(morningControllers[productName]!.text),
                    'afternoon_production': _parseIntValue(afternoonControllers[productName]!.text),
                    'evening_production': _parseIntValue(eveningControllers[productName]!.text),
                    'production_date': dateStr,
                  };

                  try {
                    await ApiService.saveDailyProduction(productionRecord);
                  } catch (e) {
                    debugPrint('Error saving production for $productName: $e');
                    // Continue with other records even if one fails
                  }
                }

                // Dispose controllers
                for (var controller in morningControllers.values) {
                  controller.dispose();
                }
                for (var controller in afternoonControllers.values) {
                  controller.dispose();
                }
                for (var controller in eveningControllers.values) {
                  controller.dispose();
                }

                if (mounted) {
                  Navigator.pop(context, true);
                  // Reload production data to show updated values
                  await _loadProductionData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Production data saved successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Dispose controllers
                for (var controller in morningControllers.values) {
                  controller.dispose();
                }
                for (var controller in afternoonControllers.values) {
                  controller.dispose();
                }
                for (var controller in eveningControllers.values) {
                  controller.dispose();
                }
                
                if (mounted) {
                  String errorMessage = e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving production data: $errorMessage'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Production Details'),
        backgroundColor: Colors.orange.shade700,
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
              Colors.orange.shade50,
              Colors.orange.shade100,
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
                            prefixIcon: const Icon(Icons.calendar_month, color: Colors.orange),
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
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.orange),
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
            // Production Table
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Morning Production', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Afternoon Production', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Evening Production', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _productionData.isEmpty
                          ? [
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      widget.selectedSector == null
                                          ? 'Please select a sector from Home page'
                                          : 'No products available for this sector',
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                  const DataCell(SizedBox.shrink()),
                                ],
                              ),
                            ]
                          : _productionData.map((record) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(record['product_name']?.toString() ?? '')),
                                  DataCell(Text('${_parseIntFromDynamic(record['morning_production'])}')),
                                  DataCell(Text('${_parseIntFromDynamic(record['afternoon_production'])}')),
                                  DataCell(Text('${_parseIntFromDynamic(record['evening_production'])}')),
                                ],
                              );
                            }).toList(),
                    ),
                  ),
                ),
              ),
            // Edit Production Details Button
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showEditProductionDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    'Edit Production Details',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
