import 'package:flutter/material.dart';
import '../models/billing_details.dart';
import '../services/api_service.dart';

class AddBillingDetailsDialog extends StatefulWidget {
  final String? bookingId;
  final BillingDetails? billingDetails;

  const AddBillingDetailsDialog({
    super.key,
    this.bookingId,
    this.billingDetails,
  });

  @override
  State<AddBillingDetailsDialog> createState() => _AddBillingDetailsDialogState();
}

class _AddBillingDetailsDialogState extends State<AddBillingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentChargeController = TextEditingController();
  final _cleaningChargeController = TextEditingController();
  final _vesselChargeController = TextEditingController();
  final _functionHallChargeController = TextEditingController();
  final _diningHallChargeController = TextEditingController();
  final _groceryChargeController = TextEditingController();
  final _vegetableChargeController = TextEditingController();
  final _morningFoodController = TextEditingController();
  final _afternoonFoodController = TextEditingController();
  final _nightFoodController = TextEditingController();
  final _cylinderQuantityController = TextEditingController();
  final _cylinderAmountController = TextEditingController();
  final _clientNameController = TextEditingController();
  DateTime? _eventDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.billingDetails != null) {
      _currentChargeController.text = widget.billingDetails!.currentCharge.toString();
      _cleaningChargeController.text = widget.billingDetails!.cleaningCharge.toString();
      _vesselChargeController.text = widget.billingDetails!.vesselCharge.toString();
      _functionHallChargeController.text = widget.billingDetails!.functionHallCharge.toString();
      _diningHallChargeController.text = widget.billingDetails!.diningHallCharge.toString();
      _groceryChargeController.text = widget.billingDetails!.groceryCharge.toString();
      _vegetableChargeController.text = widget.billingDetails!.vegetableCharge.toString();
      _morningFoodController.text = widget.billingDetails!.morningFood.toString();
      _afternoonFoodController.text = widget.billingDetails!.afternoonFood.toString();
      _nightFoodController.text = widget.billingDetails!.nightFood.toString();
      _cylinderQuantityController.text = widget.billingDetails!.cylinderQuantity.toString();
      _cylinderAmountController.text = widget.billingDetails!.cylinderAmount.toString();
    }
  }

  @override
  void dispose() {
    _currentChargeController.dispose();
    _cleaningChargeController.dispose();
    _vesselChargeController.dispose();
    _functionHallChargeController.dispose();
    _diningHallChargeController.dispose();
    _groceryChargeController.dispose();
    _vegetableChargeController.dispose();
    _morningFoodController.dispose();
    _afternoonFoodController.dispose();
    _nightFoodController.dispose();
    _cylinderQuantityController.dispose();
    _cylinderAmountController.dispose();
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

  int _parseInt(String value) {
    return int.tryParse(value) ?? 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.bookingId == null && (_clientNameController.text.trim().isEmpty || _eventDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide Client Name and Event Date'),
          backgroundColor: Colors.red,
        ),
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

      final billingDetails = BillingDetails(
        bookingId: bookingId,
        currentCharge: _parseDouble(_currentChargeController.text),
        cleaningCharge: _parseDouble(_cleaningChargeController.text),
        vesselCharge: _parseDouble(_vesselChargeController.text),
        functionHallCharge: _parseDouble(_functionHallChargeController.text),
        diningHallCharge: _parseDouble(_diningHallChargeController.text),
        groceryCharge: _parseDouble(_groceryChargeController.text),
        vegetableCharge: _parseDouble(_vegetableChargeController.text),
        morningFood: _parseDouble(_morningFoodController.text),
        afternoonFood: _parseDouble(_afternoonFoodController.text),
        nightFood: _parseDouble(_nightFoodController.text),
        cylinderQuantity: _parseInt(_cylinderQuantityController.text),
        cylinderAmount: _parseDouble(_cylinderAmountController.text),
      );

      if (widget.billingDetails != null) {
        await ApiService.updateBillingDetails(billingDetails);
      } else {
        await ApiService.createBillingDetails(billingDetails);
      }

      if (mounted) {
        Navigator.of(context).pop(billingDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.billingDetails != null
                ? 'Billing details updated successfully'
                : 'Billing details added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                      widget.billingDetails != null ? 'Edit Billing Details' : 'Add Billing Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
                if (widget.bookingId == null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clientNameController,
                    decoration: const InputDecoration(labelText: 'Client Name *'),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectEventDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Event Date *'),
                      child: Text(_eventDate != null ? _eventDate!.toIso8601String().split('T')[0] : 'Select Date'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _currentChargeController, decoration: const InputDecoration(labelText: 'Current Charge'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _cleaningChargeController, decoration: const InputDecoration(labelText: 'Cleaning Charge'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _vesselChargeController, decoration: const InputDecoration(labelText: 'Vessel Charge'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _functionHallChargeController, decoration: const InputDecoration(labelText: 'Function Hall Charge'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _diningHallChargeController, decoration: const InputDecoration(labelText: 'Dining Hall Charge'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _groceryChargeController, decoration: const InputDecoration(labelText: 'Grocery Charge'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _vegetableChargeController, decoration: const InputDecoration(labelText: 'Vegetable Charge'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _morningFoodController, decoration: const InputDecoration(labelText: 'Morning Food'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _afternoonFoodController, decoration: const InputDecoration(labelText: 'Afternoon Food'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _nightFoodController, decoration: const InputDecoration(labelText: 'Night Food'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _cylinderQuantityController, decoration: const InputDecoration(labelText: 'Cylinder Quantity'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _cylinderAmountController, decoration: const InputDecoration(labelText: 'Cylinder Amount'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.billingDetails != null ? 'Update' : 'Add')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
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

