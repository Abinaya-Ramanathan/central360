import 'package:flutter/material.dart';
import '../models/expense_details.dart';
import '../services/api_service.dart';

class AddExpenseDetailsDialog extends StatefulWidget {
  final String? bookingId;
  final ExpenseDetails? expenseDetails;

  const AddExpenseDetailsDialog({
    super.key,
    this.bookingId,
    this.expenseDetails,
  });

  @override
  State<AddExpenseDetailsDialog> createState() => _AddExpenseDetailsDialogState();
}

class _AddExpenseDetailsDialogState extends State<AddExpenseDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _masterSalaryController = TextEditingController();
  final _cookingHelperSalaryController = TextEditingController();
  final _externalCateringSalaryController = TextEditingController();
  final _currentBillController = TextEditingController();
  final _cleaningBillController = TextEditingController();
  final _groceryBillController = TextEditingController();
  final _vegetableBillController = TextEditingController();
  final _cylinderAmountController = TextEditingController();
  final _morningFoodExpenseController = TextEditingController();
  final _afternoonFoodExpenseController = TextEditingController();
  final _eveningFoodExpenseController = TextEditingController();
  final _vehicleExpenseController = TextEditingController();
  final _packingItemsChargeController = TextEditingController();
  final _detailsController = TextEditingController();
  final _clientNameController = TextEditingController();
  DateTime? _eventDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseDetails != null) {
      _masterSalaryController.text = widget.expenseDetails!.masterSalary.toString();
      _cookingHelperSalaryController.text = widget.expenseDetails!.cookingHelperSalary.toString();
      _externalCateringSalaryController.text = widget.expenseDetails!.externalCateringSalary.toString();
      _currentBillController.text = widget.expenseDetails!.currentBill.toString();
      _cleaningBillController.text = widget.expenseDetails!.cleaningBill.toString();
      _groceryBillController.text = widget.expenseDetails!.groceryBill.toString();
      _vegetableBillController.text = widget.expenseDetails!.vegetableBill.toString();
      _cylinderAmountController.text = widget.expenseDetails!.cylinderAmount.toString();
      _morningFoodExpenseController.text = widget.expenseDetails!.morningFoodExpense.toString();
      _afternoonFoodExpenseController.text = widget.expenseDetails!.afternoonFoodExpense.toString();
      _eveningFoodExpenseController.text = widget.expenseDetails!.eveningFoodExpense.toString();
      _vehicleExpenseController.text = widget.expenseDetails!.vehicleExpense.toString();
      _packingItemsChargeController.text = widget.expenseDetails!.packingItemsCharge.toString();
      _detailsController.text = widget.expenseDetails!.details ?? '';
    }
  }

  @override
  void dispose() {
    _masterSalaryController.dispose();
    _cookingHelperSalaryController.dispose();
    _externalCateringSalaryController.dispose();
    _currentBillController.dispose();
    _cleaningBillController.dispose();
    _groceryBillController.dispose();
    _vegetableBillController.dispose();
    _cylinderAmountController.dispose();
    _morningFoodExpenseController.dispose();
    _afternoonFoodExpenseController.dispose();
    _eveningFoodExpenseController.dispose();
    _vehicleExpenseController.dispose();
    _packingItemsChargeController.dispose();
    _detailsController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _selectEventDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  double _parseDouble(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  Future<void> _submit() async {
    if (widget.bookingId == null && (_clientNameController.text.trim().isEmpty || _eventDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide Client Name and Event Date'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String bookingId = widget.bookingId ?? '';
      if (bookingId.isEmpty) {
        final cleanClientName = _clientNameController.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        bookingId = '${cleanClientName}_${_eventDate!.toIso8601String().split('T')[0]}';
      }

      final expenseDetails = ExpenseDetails(
        bookingId: bookingId,
        masterSalary: _parseDouble(_masterSalaryController.text),
        cookingHelperSalary: _parseDouble(_cookingHelperSalaryController.text),
        externalCateringSalary: _parseDouble(_externalCateringSalaryController.text),
        currentBill: _parseDouble(_currentBillController.text),
        cleaningBill: _parseDouble(_cleaningBillController.text),
        groceryBill: _parseDouble(_groceryBillController.text),
        vegetableBill: _parseDouble(_vegetableBillController.text),
        cylinderAmount: _parseDouble(_cylinderAmountController.text),
        morningFoodExpense: _parseDouble(_morningFoodExpenseController.text),
        afternoonFoodExpense: _parseDouble(_afternoonFoodExpenseController.text),
        eveningFoodExpense: _parseDouble(_eveningFoodExpenseController.text),
        vehicleExpense: _parseDouble(_vehicleExpenseController.text),
        packingItemsCharge: _parseDouble(_packingItemsChargeController.text),
        details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      );

      if (widget.expenseDetails != null) {
        await ApiService.updateExpenseDetails(expenseDetails);
      } else {
        await ApiService.createExpenseDetails(expenseDetails);
      }

      if (mounted) {
        Navigator.of(context).pop(expenseDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expenseDetails != null ? 'Expense details updated successfully' : 'Expense details added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.expenseDetails != null ? 'Edit Expense Details' : 'Add Expense Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(null)),
                  ],
                ),
                if (widget.bookingId == null) ...[
                  const SizedBox(height: 16),
                  TextFormField(controller: _clientNameController, decoration: const InputDecoration(labelText: 'Client Name *'), validator: (value) => value?.isEmpty ?? true ? 'Required' : null),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectEventDate,
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Event Date *'), child: Text(_eventDate != null ? _eventDate!.toIso8601String().split('T')[0] : 'Select Date')),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(controller: _masterSalaryController, decoration: const InputDecoration(labelText: 'Master Salary'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _cookingHelperSalaryController, decoration: const InputDecoration(labelText: 'Cooking Helper Salary'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _externalCateringSalaryController, decoration: const InputDecoration(labelText: 'External Catering Salary'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _currentBillController, decoration: const InputDecoration(labelText: 'Current Bill'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _cleaningBillController, decoration: const InputDecoration(labelText: 'Cleaning Bill'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _groceryBillController, decoration: const InputDecoration(labelText: 'Grocery Bill'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _vegetableBillController, decoration: const InputDecoration(labelText: 'Vegetable Bill'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _cylinderAmountController, decoration: const InputDecoration(labelText: 'Cylinder Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _morningFoodExpenseController, decoration: const InputDecoration(labelText: 'Morning Food Expense'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _afternoonFoodExpenseController, decoration: const InputDecoration(labelText: 'Afternoon Food Expense'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _eveningFoodExpenseController, decoration: const InputDecoration(labelText: 'Evening Food Expense'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _vehicleExpenseController, decoration: const InputDecoration(labelText: 'Vehicle Expense'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _packingItemsChargeController, decoration: const InputDecoration(labelText: 'Packing Items Charge'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _detailsController, decoration: const InputDecoration(labelText: 'Details'), maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.expenseDetails != null ? 'Update' : 'Add')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

