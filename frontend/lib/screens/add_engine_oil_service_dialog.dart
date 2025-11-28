import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/engine_oil_service.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';

class AddEngineOilServiceDialog extends StatefulWidget {
  final String? selectedSector;
  final EngineOilService? engineOilService;

  const AddEngineOilServiceDialog({
    super.key,
    this.selectedSector,
    this.engineOilService,
  });

  @override
  State<AddEngineOilServiceDialog> createState() => _AddEngineOilServiceDialogState();
}

class _AddEngineOilServiceDialogState extends State<AddEngineOilServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _servicePartNameController = TextEditingController();
  final _serviceInKmsController = TextEditingController();
  final _serviceInHrsController = TextEditingController();
  final _serviceDateController = TextEditingController();
  final _nextServiceDateController = TextEditingController();
  DateTime? _serviceDate;
  DateTime? _nextServiceDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.engineOilService != null) {
      _vehicleNameController.text = widget.engineOilService!.vehicleName;
      _modelController.text = widget.engineOilService!.model;
      _servicePartNameController.text = widget.engineOilService!.servicePartName;
      _serviceDate = widget.engineOilService!.serviceDate;
      _serviceInKmsController.text = widget.engineOilService!.serviceInKms?.toString() ?? '';
      _serviceInHrsController.text = widget.engineOilService!.serviceInHrs?.toString() ?? '';
      _nextServiceDate = widget.engineOilService!.nextServiceDate;
      _serviceDateController.text = FormatUtils.formatDateDisplay(_serviceDate);
      _nextServiceDateController.text = FormatUtils.formatDateDisplay(_nextServiceDate);
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _modelController.dispose();
    _servicePartNameController.dispose();
    _serviceInKmsController.dispose();
    _serviceInHrsController.dispose();
    _serviceDateController.dispose();
    _nextServiceDateController.dispose();
    super.dispose();
  }

  void _onServiceDateTextChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _serviceDate = null;
      });
      return;
    }
    final parsedDate = FormatUtils.parseDate(value);
    if (parsedDate != null) {
      setState(() {
        _serviceDate = parsedDate;
      });
    }
  }

  void _onNextServiceDateTextChanged(String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _nextServiceDate = null;
      });
      return;
    }
    final parsedDate = FormatUtils.parseDate(value);
    if (parsedDate != null) {
      setState(() {
        _nextServiceDate = parsedDate;
      });
    }
  }

  Future<void> _submit() async {
    // Parse date from text field if not already set
    if (_serviceDate == null && _serviceDateController.text.trim().isNotEmpty) {
      _serviceDate = FormatUtils.parseDate(_serviceDateController.text);
    }
    if (_formKey.currentState!.validate() && _serviceDate != null) {
      setState(() => _isSubmitting = true);

      try {
        final engineOilService = EngineOilService(
          id: widget.engineOilService?.id,
          sectorCode: widget.selectedSector,
          vehicleName: _vehicleNameController.text.trim(),
          model: _modelController.text.trim(),
          servicePartName: _servicePartNameController.text.trim(),
          serviceDate: _serviceDate!,
          serviceInKms: _serviceInKmsController.text.trim().isEmpty ? null : int.tryParse(_serviceInKmsController.text.trim()),
          serviceInHrs: _serviceInHrsController.text.trim().isEmpty ? null : int.tryParse(_serviceInHrsController.text.trim()),
          nextServiceDate: _nextServiceDate,
        );

        if (widget.engineOilService != null) {
          await ApiService.updateEngineOilService(engineOilService);
        } else {
          await ApiService.createEngineOilService(engineOilService);
        }

        if (mounted) {
          Navigator.of(context).pop(engineOilService);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.engineOilService != null ? 'Engine oil service updated successfully' : 'Engine oil service added successfully'),
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
    } else if (_serviceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select service date'), backgroundColor: Colors.red),
      );
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
                      widget.engineOilService != null ? 'Edit Engine Oil Service' : 'Add Engine Oil Service Details',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(null)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleNameController,
                  decoration: const InputDecoration(labelText: 'Vehicle Name *', border: OutlineInputBorder()),
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
                  controller: _servicePartNameController,
                  decoration: const InputDecoration(labelText: 'Service Part Name *', border: OutlineInputBorder()),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serviceDateController,
                  decoration: const InputDecoration(
                    labelText: 'Service Date *',
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/YYYY',
                  ),
                  onChanged: _onServiceDateTextChanged,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serviceInKmsController,
                  decoration: const InputDecoration(labelText: 'Service in Kms', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serviceInHrsController,
                  decoration: const InputDecoration(labelText: 'Service in Hrs', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nextServiceDateController,
                  decoration: const InputDecoration(
                    labelText: 'Next Service Date',
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/YYYY',
                  ),
                  onChanged: _onNextServiceDateTextChanged,
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
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : (widget.engineOilService != null ? 'Update' : 'Add')),
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

