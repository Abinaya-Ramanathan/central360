import 'package:flutter/material.dart';
import '../models/vehicle_license.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';

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
  final _permitDateController = TextEditingController();
  final _insuranceDateController = TextEditingController();
  final _fitnessDateController = TextEditingController();
  final _pollutionDateController = TextEditingController();
  final _taxDateController = TextEditingController();
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
      _permitDateController.text = FormatUtils.formatDateDisplay(_permitDate);
      _insuranceDateController.text = FormatUtils.formatDateDisplay(_insuranceDate);
      _fitnessDateController.text = FormatUtils.formatDateDisplay(_fitnessDate);
      _pollutionDateController.text = FormatUtils.formatDateDisplay(_pollutionDate);
      _taxDateController.text = FormatUtils.formatDateDisplay(_taxDate);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _registrationNumberController.dispose();
    _permitDateController.dispose();
    _insuranceDateController.dispose();
    _fitnessDateController.dispose();
    _pollutionDateController.dispose();
    _taxDateController.dispose();
    super.dispose();
  }

  void _onDateTextChanged(String value, Function(DateTime?) onDateChanged) {
    if (value.trim().isEmpty) {
      onDateChanged(null);
      setState(() {});
      return;
    }
    final parsedDate = FormatUtils.parseDate(value);
    if (parsedDate != null) {
      onDateChanged(parsedDate);
      setState(() {});
    }
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required DateTime? dateValue,
    required Function(DateTime?) onDateChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintText: 'DD/MM/YYYY',
      ),
      onChanged: (value) => _onDateTextChanged(value, onDateChanged),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Optional field
        }
        final parsedDate = FormatUtils.parseDate(value);
        if (parsedDate == null) {
          return 'Invalid format. Use DD/MM/YYYY';
        }
        return null;
      },
    );
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
                _buildDateField(
                  label: 'Permit Date',
                  controller: _permitDateController,
                  dateValue: _permitDate,
                  onDateChanged: (date) => _permitDate = date,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'Insurance Date',
                  controller: _insuranceDateController,
                  dateValue: _insuranceDate,
                  onDateChanged: (date) => _insuranceDate = date,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'Fitness Date',
                  controller: _fitnessDateController,
                  dateValue: _fitnessDate,
                  onDateChanged: (date) => _fitnessDate = date,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'Pollution Date',
                  controller: _pollutionDateController,
                  dateValue: _pollutionDate,
                  onDateChanged: (date) => _pollutionDate = date,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'Tax Date',
                  controller: _taxDateController,
                  dateValue: _taxDate,
                  onDateChanged: (date) => _taxDate = date,
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

