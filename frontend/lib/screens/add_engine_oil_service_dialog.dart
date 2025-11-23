import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/engine_oil_service.dart';
import '../services/api_service.dart';

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
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _modelController.dispose();
    _servicePartNameController.dispose();
    _serviceInKmsController.dispose();
    _serviceInHrsController.dispose();
    super.dispose();
  }

  Future<void> _selectServiceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _serviceDate = picked;
      });
    }
  }

  Future<void> _selectNextServiceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextServiceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _nextServiceDate = picked;
      });
    }
  }

  Future<void> _submit() async {
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
                InkWell(
                  onTap: _selectServiceDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Service Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_serviceDate != null ? _serviceDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
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
                InkWell(
                  onTap: _selectNextServiceDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Next Service Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_nextServiceDate != null ? _nextServiceDate!.toIso8601String().split('T')[0] : 'Select Date'),
                  ),
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

