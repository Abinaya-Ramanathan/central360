import 'package:flutter/material.dart';
import '../models/vehicle_license.dart';
import '../services/api_service.dart';

class AddVehicleLicenseDialog extends StatefulWidget {
  final String? selectedSector;
  final VehicleLicense? vehicleLicense;

  const AddVehicleLicenseDialog({
    super.key,
    this.selectedSector,
    this.vehicleLicense,
  });

  @override
  State<AddVehicleLicenseDialog> createState() => _AddVehicleLicenseDialogState();
}

class _AddVehicleLicenseDialogState extends State<AddVehicleLicenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  DateTime? _permitDate;
  DateTime? _insuranceDate;
  DateTime? _fitnessDate;
  DateTime? _pollutionDate;
  DateTime? _taxDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleLicense != null) {
      _nameController.text = widget.vehicleLicense!.name;
      _modelController.text = widget.vehicleLicense!.model;
      _registrationNumberController.text = widget.vehicleLicense!.registrationNumber;
      _permitDate = widget.vehicleLicense!.permitDate;
      _insuranceDate = widget.vehicleLicense!.insuranceDate;
      _fitnessDate = widget.vehicleLicense!.fitnessDate;
      _pollutionDate = widget.vehicleLicense!.pollutionDate;
      _taxDate = widget.vehicleLicense!.taxDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final vehicleLicense = VehicleLicense(
          id: widget.vehicleLicense?.id,
          sectorCode: widget.selectedSector,
          name: _nameController.text.trim(),
          model: _modelController.text.trim(),
          registrationNumber: _registrationNumberController.text.trim(),
          permitDate: _permitDate,
          insuranceDate: _insuranceDate,
          fitnessDate: _fitnessDate,
          pollutionDate: _pollutionDate,
          taxDate: _taxDate,
        );

        if (widget.vehicleLicense != null) {
          await ApiService.updateVehicleLicense(vehicleLicense);
        } else {
          await ApiService.createVehicleLicense(vehicleLicense);
        }

        if (mounted) {
          Navigator.of(context).pop(vehicleLicense);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.vehicleLicense != null ? 'Vehicle license updated successfully' : 'Vehicle license added successfully'),
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
                      widget.vehicleLicense != null ? 'Edit Vehicle License' : 'Add Vehicle License Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(null)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _registrationNumberController,
                  decoration: const InputDecoration(labelText: 'Registration Number *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, _permitDate, (date) => _permitDate = date),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Permit Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_permitDate != null ? _permitDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, _insuranceDate, (date) => _insuranceDate = date),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Insurance Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_insuranceDate != null ? _insuranceDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, _fitnessDate, (date) => _fitnessDate = date),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fitness Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_fitnessDate != null ? _fitnessDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, _pollutionDate, (date) => _pollutionDate = date),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pollution Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_pollutionDate != null ? _pollutionDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context, _taxDate, (date) => _taxDate = date),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tax Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_taxDate != null ? _taxDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.vehicleLicense != null ? 'Update' : 'Add')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700, foregroundColor: Colors.white),
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

