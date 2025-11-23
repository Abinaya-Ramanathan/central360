import 'package:flutter/material.dart';
import '../models/catering_details.dart';
import '../services/api_service.dart';

class AddCateringDetailsDialog extends StatefulWidget {
  final String? bookingId;
  final CateringDetails? cateringDetails;

  const AddCateringDetailsDialog({
    super.key,
    this.bookingId,
    this.cateringDetails,
  });

  @override
  State<AddCateringDetailsDialog> createState() => _AddCateringDetailsDialogState();
}

class _AddCateringDetailsDialogState extends State<AddCateringDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryLocationController = TextEditingController();
  final _morningFoodMenuController = TextEditingController();
  final _morningFoodCountController = TextEditingController();
  final _afternoonFoodMenuController = TextEditingController();
  final _afternoonFoodCountController = TextEditingController();
  final _eveningFoodMenuController = TextEditingController();
  final _eveningFoodCountController = TextEditingController();
  final _clientNameController = TextEditingController();
  DateTime? _eventDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.cateringDetails != null) {
      _deliveryLocationController.text = widget.cateringDetails!.deliveryLocation ?? '';
      _morningFoodMenuController.text = widget.cateringDetails!.morningFoodMenu ?? '';
      _morningFoodCountController.text = widget.cateringDetails!.morningFoodCount.toString();
      _afternoonFoodMenuController.text = widget.cateringDetails!.afternoonFoodMenu ?? '';
      _afternoonFoodCountController.text = widget.cateringDetails!.afternoonFoodCount.toString();
      _eveningFoodMenuController.text = widget.cateringDetails!.eveningFoodMenu ?? '';
      _eveningFoodCountController.text = widget.cateringDetails!.eveningFoodCount.toString();
    }
  }

  @override
  void dispose() {
    _deliveryLocationController.dispose();
    _morningFoodMenuController.dispose();
    _morningFoodCountController.dispose();
    _afternoonFoodMenuController.dispose();
    _afternoonFoodCountController.dispose();
    _eveningFoodMenuController.dispose();
    _eveningFoodCountController.dispose();
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

      final cateringDetails = CateringDetails(
        bookingId: bookingId,
        deliveryLocation: _deliveryLocationController.text.trim().isEmpty ? null : _deliveryLocationController.text.trim(),
        morningFoodMenu: _morningFoodMenuController.text.trim().isEmpty ? null : _morningFoodMenuController.text.trim(),
        morningFoodCount: int.tryParse(_morningFoodCountController.text) ?? 0,
        afternoonFoodMenu: _afternoonFoodMenuController.text.trim().isEmpty ? null : _afternoonFoodMenuController.text.trim(),
        afternoonFoodCount: int.tryParse(_afternoonFoodCountController.text) ?? 0,
        eveningFoodMenu: _eveningFoodMenuController.text.trim().isEmpty ? null : _eveningFoodMenuController.text.trim(),
        eveningFoodCount: int.tryParse(_eveningFoodCountController.text) ?? 0,
      );

      if (widget.cateringDetails != null) {
        await ApiService.updateCateringDetails(cateringDetails);
      } else {
        await ApiService.createCateringDetails(cateringDetails);
      }

      if (mounted) {
        Navigator.of(context).pop(cateringDetails);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cateringDetails != null ? 'Catering details updated successfully' : 'Catering details added successfully'),
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
                      widget.cateringDetails != null ? 'Edit Catering Details' : 'Add Catering Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
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
                TextFormField(controller: _deliveryLocationController, decoration: const InputDecoration(labelText: 'Delivery Location'), maxLines: 2),
                const SizedBox(height: 16),
                TextFormField(controller: _morningFoodCountController, decoration: const InputDecoration(labelText: 'Morning Food Count'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _morningFoodMenuController, decoration: const InputDecoration(labelText: 'Morning Food Menu'), maxLines: 3),
                const SizedBox(height: 16),
                TextFormField(controller: _afternoonFoodCountController, decoration: const InputDecoration(labelText: 'Afternoon Food Count'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _afternoonFoodMenuController, decoration: const InputDecoration(labelText: 'Afternoon Food Menu'), maxLines: 3),
                const SizedBox(height: 16),
                TextFormField(controller: _eveningFoodCountController, decoration: const InputDecoration(labelText: 'Evening Food Count'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextFormField(controller: _eveningFoodMenuController, decoration: const InputDecoration(labelText: 'Evening Food Menu'), maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.cateringDetails != null ? 'Update' : 'Add')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
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

