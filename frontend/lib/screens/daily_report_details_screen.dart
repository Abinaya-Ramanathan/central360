import 'package:flutter/material.dart';
import 'attendance_tab_content.dart';
import 'production_tab_content.dart';
import 'expense_tab_content.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../models/sector.dart';
import '../services/api_service.dart';

class DailyReportDetailsScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const DailyReportDetailsScreen({
    super.key,
    required this.username,
    this.selectedSector,
  });

  @override
  State<DailyReportDetailsScreen> createState() => _DailyReportDetailsScreenState();
}

class _DailyReportDetailsScreenState extends State<DailyReportDetailsScreen> with SingleTickerProviderStateMixin {
  int? _selectedMonth;
  DateTime? _selectedDate;
  late TabController _tabController;
  bool _isAdmin = false;
  List<Sector> _sectors = [];

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

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMonth = DateTime.now().month;
    _selectedDate = DateTime.now();
    _isAdmin = widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya';
    _loadSectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectMonth() async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _months.length,
            itemBuilder: (context, index) {
              final monthNumber = index + 1;
              final isSelected = monthNumber == _selectedMonth;
              return ListTile(
                title: Text(_months[index]),
                selected: isSelected,
                onTap: () => Navigator.pop(context, monthNumber),
              );
            },
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report Details'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Production'),
            Tab(text: 'Expense'),
          ],
        ),
        actions: [
          // Sector Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 4),
                Text(
                  widget.selectedSector != null
                      ? _getSectorName(widget.selectedSector)
                      : 'All Sectors',
                  style: const TextStyle(fontSize: 14),
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
                  builder: (context) => HomeScreen(username: widget.username),
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
      body: Column(
        children: [
          // Month and Date Selection
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectMonth,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Select Month',
                        prefixIcon: const Icon(Icons.calendar_month),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedMonth != null ? _months[_selectedMonth! - 1] : 'Select Month',
                        style: TextStyle(
                          color: _selectedMonth != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                        style: TextStyle(
                          color: _selectedDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Attendance Tab
                AttendanceTabContent(
                  selectedSector: widget.selectedSector,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isAdmin: _isAdmin,
                ),
                // Production Tab
                ProductionTabContent(
                  selectedSector: widget.selectedSector,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isAdmin: _isAdmin,
                ),
                // Expense Tab
                ExpenseTabContent(
                  selectedSector: widget.selectedSector,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isAdmin: _isAdmin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

