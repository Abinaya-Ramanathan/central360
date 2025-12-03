import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class EditRentVehicleDialog extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;
  final String sectorCode;

  const EditRentVehicleDialog({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    required this.sectorCode,
  });

  @override
  State<EditRentVehicleDialog> createState() => _EditRentVehicleDialogState();
}

class _EditRentVehicleDialogState extends State<EditRentVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();
  String? _selectedSectorCode;
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _vehicleNameController.text = widget.vehicleName;
    _selectedSectorCode = widget.sectorCode;
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    try {
      final sectors = await ApiService.getSectors();
      setState(() {
        _sectors = sectors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sectors: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSectorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sector')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.updateRentVehicle(
        widget.vehicleId.toString(),
        _vehicleNameController.text.trim(),
        _selectedSectorCode!,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.cyan.shade700),
          const SizedBox(width: 8),
          const Text('Edit Rent Vehicle'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vehicle Name
              TextFormField(
                controller: _vehicleNameController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Name *',
                  hintText: 'e.g., Car, Bike, etc.',
                  prefixIcon: const Icon(Icons.directions_car, color: Colors.cyan),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyan, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vehicle name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Sector Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector *',
                  prefixIcon: const Icon(Icons.business, color: Colors.cyan),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyan, width: 2),
                  ),
                ),
                hint: const Text('Select Sector'),
                items: _sectors.map((sector) {
                  return DropdownMenuItem<String>(
                    value: sector.code,
                    child: Text('${sector.code} - ${sector.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSectorCode = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a sector';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.cyan.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

