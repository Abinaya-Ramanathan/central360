import 'package:flutter/material.dart';
import '../models/driver_license.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';

class AddDriverLicenseDialog extends StatefulWidget {
  final String? selectedSector;
  final DriverLicense? driverLicense;

  const AddDriverLicenseDialog({
    super.key,
    this.selectedSector,
    this.driverLicense,
  });

  @override
  State<AddDriverLicenseDialog> createState() => _AddDriverLicenseDialogState();
}

class _AddDriverLicenseDialogState extends State<AddDriverLicenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.driverLicense != null) {
      _driverNameController.text = widget.driverLicense!.driverName;
      _licenseNumberController.text = widget.driverLicense!.licenseNumber;
      _expiryDate = widget.driverLicense!.expiryDate;
      _expiryDateController.text = FormatUtils.formatDateDisplay(_expiryDate);
    }
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _licenseNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  void _onDateTextChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _expiryDate = null;
      });
      return;
    }
    final parsedDate = FormatUtils.parseDate(value);
    if (parsedDate != null) {
      setState(() {
        _expiryDate = parsedDate;
      });
    }
  }

  Future<void> _submit() async {
    // Parse date from text field if not already set
    if (_expiryDate == null && _expiryDateController.text.trim().isNotEmpty) {
      _expiryDate = FormatUtils.parseDate(_expiryDateController.text);
    }
    if (_formKey.currentState!.validate() && _expiryDate != null) {
      setState(() => _isSubmitting = true);

      try {
        final driverLicense = DriverLicense(
          id: widget.driverLicense?.id,
          sectorCode: widget.selectedSector,
          driverName: _driverNameController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim(),
          expiryDate: _expiryDate!,
        );

        if (widget.driverLicense != null) {
          await ApiService.updateDriverLicense(driverLicense);
        } else {
          await ApiService.createDriverLicense(driverLicense);
        }

        if (mounted) {
          Navigator.of(context).pop(driverLicense);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.driverLicense != null ? 'Driver license updated successfully' : 'Driver license added successfully'),
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
    } else if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expiry date'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                      widget.driverLicense != null ? 'Edit Driver License' : 'Add Driver License Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(null)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _driverNameController,
                  decoration: const InputDecoration(labelText: 'Driver Name *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(labelText: 'License Number *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expiryDateController,
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date *',
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/YYYY',
                  ),
                  onChanged: _onDateTextChanged,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final parsedDate = FormatUtils.parseDate(value);
                    if (parsedDate == null) {
                      return 'Invalid format. Use DD/MM/YYYY';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.driverLicense != null ? 'Update' : 'Add')),
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

