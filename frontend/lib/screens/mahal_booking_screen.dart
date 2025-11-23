import 'package:flutter/material.dart';
import '../models/mahal_booking.dart';
import '../models/catering_details.dart';
import '../models/expense_details.dart';
import '../models/sector.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'add_mahal_booking_dialog.dart';
import 'add_catering_details_dialog.dart';
import 'add_expense_details_dialog.dart';
import '../utils/pdf_generator.dart';

class MahalBookingScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const MahalBookingScreen({
    super.key,
    required this.username,
    this.selectedSector,
  });

  @override
  State<MahalBookingScreen> createState() => _MahalBookingScreenState();
}

class _MahalBookingScreenState extends State<MahalBookingScreen> {
  List<MahalBooking> _eventDetails = [];
  List<CateringDetails> _cateringDetails = [];
  List<ExpenseDetails> _expenseDetails = [];
  List<Sector> _sectors = [];
  String? _selectedBookingId; // For linking tables
  bool _isLoading = false;
  bool _sortByDateDesc = true; // true for descending (newest first), false for ascending

  @override
  void initState() {
    super.initState();
    _loadSectors();
    _loadAllData();
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final eventDetails = await ApiService.getMahalBookings(sector: widget.selectedSector);
      final cateringDetails = await ApiService.getCateringDetails(bookingId: _selectedBookingId);
      final expenseDetails = await ApiService.getExpenseDetails(bookingId: _selectedBookingId);

      if (mounted) {
        setState(() {
          _eventDetails = eventDetails;
          _cateringDetails = cateringDetails;
          _expenseDetails = expenseDetails;
        });
        // Check for expiring event dates and send notifications
        _checkEventDatesAndNotify();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkEventDatesAndNotify() async {
    try {
      // Check mahal booking event dates (Event Date)
      await NotificationService().checkMahalBookingEventDates(_eventDetails);
    } catch (e) {
      // Silently handle errors - notifications are non-critical
      print('Error checking event dates: $e');
    }
  }

  void _onBookingIdSelected(String bookingId) {
    setState(() {
      _selectedBookingId = _selectedBookingId == bookingId ? null : bookingId;
    });
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mahal Booking and Catering Order'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(text: 'Event Details'),
              Tab(text: 'Catering Details'),
              Tab(text: 'Expense Details'),
            ],
          ),
          actions: [
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
                  MaterialPageRoute(builder: (context) => HomeScreen(username: widget.username)),
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
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
        body: _isLoading && _eventDetails.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildEventDetailsTab(),
                  _buildCateringDetailsTab(),
                  _buildExpenseDetailsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildEventDetailsTab() {
    List<MahalBooking> filteredEvents = _selectedBookingId != null
        ? _eventDetails.where((e) => e.bookingId == _selectedBookingId).toList()
        : List.from(_eventDetails);
    
    // Sort by Event Date (newest first)
    filteredEvents.sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return Column(
      children: [
        Expanded(
          child: filteredEvents.isEmpty
              ? Center(child: Text('No event details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      columns: [
                        const DataColumn(label: Text('Booking ID')),
                        const DataColumn(label: Text('Mahal Detail')),
                        DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Event Date'),
                              IconButton(
                                icon: Icon(_sortByDateDesc ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                                tooltip: _sortByDateDesc ? 'Sort: Newest First' : 'Sort: Oldest First',
                                onPressed: () {
                                  setState(() {
                                    _sortByDateDesc = !_sortByDateDesc;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const DataColumn(label: Text('Event Timing')),
                        DataColumn(label: Text('Event Name')),
                        DataColumn(label: Text('Client Name')),
                        DataColumn(label: Text('Client Phone 1')),
                        DataColumn(label: Text('Client Phone 2')),
                        DataColumn(label: Text('Client Address')),
                        DataColumn(label: Text('Food Service')),
                        DataColumn(label: Text('Advance Received')),
                        DataColumn(label: Text('Quoted Amount')),
                        DataColumn(label: Text('Amount Received')),
                        DataColumn(label: Text('Order Status')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: (filteredEvents..sort((a, b) {
                        final comparison = a.eventDate.compareTo(b.eventDate);
                        return _sortByDateDesc ? -comparison : comparison;
                      })).map((event) {
                        final isSelected = event.bookingId == _selectedBookingId;
                        return DataRow(
                          color: isSelected ? MaterialStateProperty.all(Colors.yellow.shade100) : null,
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _onBookingIdSelected(event.bookingId!),
                                child: Text(event.bookingId ?? 'N/A', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                            ),
                            DataCell(Text(event.mahalDetail, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.eventDate.toIso8601String().split('T')[0], style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.eventTiming ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.eventName ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.clientName, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.clientPhone1 ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.clientPhone2 ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 150, child: Text(event.clientAddress ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(Text(event.foodService ?? 'N/A', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.advanceReceived?.toStringAsFixed(2) ?? '0.00', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.quotedAmount?.toStringAsFixed(2) ?? '0.00', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.amountReceived?.toStringAsFixed(2) ?? '0.00', style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(event.orderStatus?.toUpperCase() ?? 'OPEN', style: const TextStyle(color: Colors.black87))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewEvent(event)),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editEvent(event)),
                                  if (widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya')
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteEvent(event.bookingId!)),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: widget.selectedSector == null ? null : _addEvent,
              icon: const Icon(Icons.add),
              label: const Text('Add Event Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCateringDetailsTab() {
    final filteredCatering = _selectedBookingId != null
        ? _cateringDetails.where((c) => c.bookingId == _selectedBookingId).toList()
        : _cateringDetails;

    return Column(
      children: [
        Expanded(
          child: filteredCatering.isEmpty
              ? Center(child: Text('No catering details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      columns: const [
                        DataColumn(label: Text('Booking ID')),
                        DataColumn(label: Text('Delivery Location')),
                        DataColumn(label: Text('Morning Food Count')),
                        DataColumn(label: Text('Morning Food Menu')),
                        DataColumn(label: Text('Afternoon Food Count')),
                        DataColumn(label: Text('Afternoon Food Menu')),
                        DataColumn(label: Text('Evening Food Count')),
                        DataColumn(label: Text('Evening Food Menu')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: filteredCatering.map((catering) {
                        return DataRow(
                          cells: [
                            DataCell(Text(catering.bookingId, style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 150, child: Text(catering.deliveryLocation ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(Text(catering.morningFoodCount.toString(), style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 200, child: Text(catering.morningFoodMenu ?? 'N/A', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(Text(catering.afternoonFoodCount.toString(), style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 200, child: Text(catering.afternoonFoodMenu ?? 'N/A', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(Text(catering.eveningFoodCount.toString(), style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 200, child: Text(catering.eveningFoodMenu ?? 'N/A', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewCatering(catering)),
                                  IconButton(icon: const Icon(Icons.download, color: Colors.blue, size: 20), tooltip: 'Download PDF', onPressed: () => _downloadCateringPDF(catering)),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), tooltip: 'Edit', onPressed: () => _editCatering(catering)),
                                  if (widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya')
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: 'Delete', onPressed: () => _deleteCatering(catering.bookingId)),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addCatering,
              icon: const Icon(Icons.add),
              label: const Text('Add Catering Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseDetailsTab() {
    final filteredExpense = _selectedBookingId != null
        ? _expenseDetails.where((e) => e.bookingId == _selectedBookingId).toList()
        : _expenseDetails;

    return Column(
      children: [
        Expanded(
          child: filteredExpense.isEmpty
              ? Center(child: Text('No expense details found', style: TextStyle(color: Colors.grey.shade600)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      columns: const [
                        DataColumn(label: Text('Booking ID')),
                        DataColumn(label: Text('Master Salary')),
                        DataColumn(label: Text('Cooking Helper Salary')),
                        DataColumn(label: Text('External Catering Salary')),
                        DataColumn(label: Text('Current Bill')),
                        DataColumn(label: Text('Cleaning Bill')),
                        DataColumn(label: Text('Grocery Bill')),
                        DataColumn(label: Text('Vegetable Bill')),
                        DataColumn(label: Text('Cylinder Amount')),
                        DataColumn(label: Text('Morning Food Expense')),
                        DataColumn(label: Text('Afternoon Food Expense')),
                        DataColumn(label: Text('Evening Food Expense')),
                        DataColumn(label: Text('Vehicle Expense')),
                        DataColumn(label: Text('Packing Items Charge')),
                        DataColumn(label: Text('Details')),
                        DataColumn(label: Text('Total Expense')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: filteredExpense.map((expense) {
                        return DataRow(
                          cells: [
                            DataCell(Text(expense.bookingId, style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.masterSalary.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.cookingHelperSalary.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.externalCateringSalary.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.currentBill.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.cleaningBill.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.groceryBill.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.vegetableBill.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.cylinderAmount.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.morningFoodExpense.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.afternoonFoodExpense.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.eveningFoodExpense.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.vehicleExpense.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(Text(expense.packingItemsCharge.toStringAsFixed(2), style: const TextStyle(color: Colors.black87))),
                            DataCell(SizedBox(width: 200, child: Text(expense.details ?? 'N/A', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)))),
                            DataCell(
                              Text(
                                _calculateTotalExpense(expense).toStringAsFixed(2),
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.visibility, color: Colors.green, size: 20), tooltip: 'View', onPressed: () => _viewExpense(expense)),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editExpense(expense)),
                                  if (widget.username.toLowerCase() == 'admin' || widget.username.toLowerCase() == 'srisurya')
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteExpense(expense.bookingId)),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense Details', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addEvent() async {
    final result = await showDialog<MahalBooking>(
      context: context,
      builder: (context) => AddMahalBookingDialog(selectedSector: widget.selectedSector!),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _viewEvent(MahalBooking event) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Event Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewField('Booking ID', event.bookingId ?? 'N/A'),
              _buildViewField('Mahal Detail', event.mahalDetail),
              _buildViewField('Event Date', event.eventDate.toIso8601String().split('T')[0]),
              _buildViewField('Event Timing', event.eventTiming ?? 'N/A'),
              _buildViewField('Event Name', event.eventName ?? 'N/A'),
              _buildViewField('Client Name', event.clientName),
              _buildViewField('Client Phone 1', event.clientPhone1 ?? 'N/A'),
              _buildViewField('Client Phone 2', event.clientPhone2 ?? 'N/A'),
              _buildViewField('Client Address', event.clientAddress ?? 'N/A'),
              _buildViewField('Food Service', event.foodService ?? 'N/A'),
              _buildViewField('Advance Received', event.advanceReceived?.toStringAsFixed(2) ?? '0.00'),
              _buildViewField('Quoted Amount', event.quotedAmount?.toStringAsFixed(2) ?? '0.00'),
              _buildViewField('Amount Received', event.amountReceived?.toStringAsFixed(2) ?? '0.00'),
              _buildViewField('Order Status', event.orderStatus?.toUpperCase() ?? 'OPEN'),
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

  Future<void> _viewExpense(ExpenseDetails expense) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expense Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildViewField('Booking ID', expense.bookingId),
              _buildViewField('Master Salary', expense.masterSalary.toStringAsFixed(2)),
              _buildViewField('Cooking Helper Salary', expense.cookingHelperSalary.toStringAsFixed(2)),
              _buildViewField('External Catering Salary', expense.externalCateringSalary.toStringAsFixed(2)),
              _buildViewField('Current Bill', expense.currentBill.toStringAsFixed(2)),
              _buildViewField('Cleaning Bill', expense.cleaningBill.toStringAsFixed(2)),
              _buildViewField('Grocery Bill', expense.groceryBill.toStringAsFixed(2)),
              _buildViewField('Vegetable Bill', expense.vegetableBill.toStringAsFixed(2)),
              _buildViewField('Cylinder Amount', expense.cylinderAmount.toStringAsFixed(2)),
              _buildViewField('Morning Food Expense', expense.morningFoodExpense.toStringAsFixed(2)),
              _buildViewField('Afternoon Food Expense', expense.afternoonFoodExpense.toStringAsFixed(2)),
              _buildViewField('Evening Food Expense', expense.eveningFoodExpense.toStringAsFixed(2)),
              _buildViewField('Vehicle Expense', expense.vehicleExpense.toStringAsFixed(2)),
              _buildViewField('Packing Items Charge', expense.packingItemsCharge.toStringAsFixed(2)),
              _buildViewField('Details', expense.details ?? 'N/A'),
              _buildViewField('Total Expense', _calculateTotalExpense(expense).toStringAsFixed(2)),
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
            width: 160,
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

  Future<void> _editEvent(MahalBooking event) async {
    final result = await showDialog<MahalBooking>(
      context: context,
      builder: (context) => AddMahalBookingDialog(selectedSector: widget.selectedSector!, booking: event),
    );
    if (result != null) await _loadAllData();
  }

  Future<void> _deleteEvent(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure? This will also delete related billing, catering, and expense details.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteMahalBooking(bookingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted successfully'), backgroundColor: Colors.green));
        }
        await _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _addCatering() async {
    final result = await showDialog<CateringDetails>(context: context, builder: (context) => AddCateringDetailsDialog(bookingId: _selectedBookingId));
    if (result != null) await _loadAllData();
  }

  Future<void> _editCatering(CateringDetails catering) async {
    final result = await showDialog<CateringDetails>(context: context, builder: (context) => AddCateringDetailsDialog(bookingId: catering.bookingId, cateringDetails: catering));
    if (result != null) await _loadAllData();
  }

  Future<void> _viewCatering(CateringDetails catering) async {
    final List<Widget> widgets = [
      const Text('Catering Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text('Booking ID: ${catering.bookingId}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ];

    // Add Delivery Location if it exists, right after Booking ID
    if (catering.deliveryLocation != null && catering.deliveryLocation!.isNotEmpty) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('Delivery Location: ${catering.deliveryLocation}', 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
    }

    // Only add fields that have data, in the specified order
    bool hasMorningData = (catering.morningFoodCount > 0) || (catering.morningFoodMenu != null && catering.morningFoodMenu!.isNotEmpty);
    bool hasAfternoonData = (catering.afternoonFoodCount > 0) || (catering.afternoonFoodMenu != null && catering.afternoonFoodMenu!.isNotEmpty);
    bool hasEveningData = (catering.eveningFoodCount > 0) || (catering.eveningFoodMenu != null && catering.eveningFoodMenu!.isNotEmpty);

    if (hasMorningData) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('Morning Food Count: ${catering.morningFoodCount > 0 ? catering.morningFoodCount : 0}', 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
      if (catering.morningFoodMenu != null && catering.morningFoodMenu!.isNotEmpty) {
        widgets.add(const SizedBox(height: 5));
        widgets.add(const Text('Morning Food Menu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
        widgets.add(Text(catering.morningFoodMenu!));
      }
    }

    if (hasAfternoonData) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('Afternoon Food Count: ${catering.afternoonFoodCount > 0 ? catering.afternoonFoodCount : 0}', 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
      if (catering.afternoonFoodMenu != null && catering.afternoonFoodMenu!.isNotEmpty) {
        widgets.add(const SizedBox(height: 5));
        widgets.add(const Text('Afternoon Food Menu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
        widgets.add(Text(catering.afternoonFoodMenu!));
      }
    }

    if (hasEveningData) {
      widgets.add(const SizedBox(height: 10));
      widgets.add(Text('Evening Food Count: ${catering.eveningFoodCount > 0 ? catering.eveningFoodCount : 0}', 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
      if (catering.eveningFoodMenu != null && catering.eveningFoodMenu!.isNotEmpty) {
        widgets.add(const SizedBox(height: 5));
        widgets.add(const Text('Evening Food Menu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
        widgets.add(Text(catering.eveningFoodMenu!));
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Catering Details - ${catering.bookingId}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
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

  Future<void> _downloadCateringPDF(CateringDetails catering) async {
    try {
      await PdfGenerator.generateAndDownloadCateringPDF(
        bookingId: catering.bookingId,
        deliveryLocation: catering.deliveryLocation,
        morningFoodMenu: catering.morningFoodMenu,
        morningFoodCount: catering.morningFoodCount,
        afternoonFoodMenu: catering.afternoonFoodMenu,
        afternoonFoodCount: catering.afternoonFoodCount,
        eveningFoodMenu: catering.eveningFoodMenu,
        eveningFoodCount: catering.eveningFoodCount,
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

  Future<void> _deleteCatering(String bookingId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    if (confirmed == true) {
      try {
        await ApiService.deleteCateringDetails(bookingId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        await _loadAllData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _addExpense() async {
    final result = await showDialog<ExpenseDetails>(context: context, builder: (context) => AddExpenseDetailsDialog(bookingId: _selectedBookingId));
    if (result != null) await _loadAllData();
  }

  Future<void> _editExpense(ExpenseDetails expense) async {
    final result = await showDialog<ExpenseDetails>(context: context, builder: (context) => AddExpenseDetailsDialog(bookingId: expense.bookingId, expenseDetails: expense));
    if (result != null) await _loadAllData();
  }

  double _calculateTotalExpense(ExpenseDetails expense) {
    return expense.masterSalary +
        expense.cookingHelperSalary +
        expense.externalCateringSalary +
        expense.currentBill +
        expense.cleaningBill +
        expense.groceryBill +
        expense.vegetableBill +
        expense.cylinderAmount +
        expense.morningFoodExpense +
        expense.afternoonFoodExpense +
        expense.eveningFoodExpense +
        expense.vehicleExpense +
        expense.packingItemsCharge;
  }

  Future<void> _deleteExpense(String bookingId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    if (confirmed == true) {
      try {
        await ApiService.deleteExpenseDetails(bookingId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        await _loadAllData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
