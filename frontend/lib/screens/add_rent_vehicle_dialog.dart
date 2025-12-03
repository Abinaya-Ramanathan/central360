import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class AddRentVehicleDialog extends StatefulWidget {
  final String? preSelectedSector;

  const AddRentVehicleDialog({super.key, this.preSelectedSector});

  @override
  State<AddRentVehicleDialog> createState() => _AddRentVehicleDialogState();
}

class _AddRentVehicleDialogState extends State<AddRentVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _vehicleNameControllers = [TextEditingController()];
  String? _selectedSectorCode;
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSectorCode = widget.preSelectedSector;
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

  void _addVehicleRow() {
    setState(() {
      _vehicleNameControllers.add(TextEditingController());
    });
  }

  void _removeVehicleRow(int index) {
    if (_vehicleNameControllers.length > 1) {
      setState(() {
        _vehicleNameControllers[index].dispose();
        _vehicleNameControllers.removeAt(index);
      });
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

    // Validate that at least one vehicle name is filled
    bool hasAtLeastOneVehicle = false;
    for (var controller in _vehicleNameControllers) {
      if (controller.text.trim().isNotEmpty) {
        hasAtLeastOneVehicle = true;
        break;
      }
    }

    if (!hasAtLeastOneVehicle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one vehicle name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    try {
      for (int i = 0; i < _vehicleNameControllers.length; i++) {
        final vehicleName = _vehicleNameControllers[i].text.trim();
        if (vehicleName.isEmpty) continue; // Skip empty vehicles

        try {
          await ApiService.createRentVehicle(
            vehicleName,
            _selectedSectorCode!,
          );
          successCount++;
        } catch (e) {
          errorCount++;
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          errorMessages.add('$vehicleName: $errorMessage');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        String message;
        if (errorCount == 0) {
          message = '$successCount vehicle(s) created successfully';
        } else {
          message = '$successCount vehicle(s) created, $errorCount failed. ${errorMessages.join("; ")}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: errorCount > 0 ? 6 : 2),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
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
    for (var controller in _vehicleNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.directions_car, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          const Text('Add Rent Vehicle'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sector Dropdown (shared for all vehicles)
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector * (applies to all vehicles)',
                  prefixIcon: const Icon(Icons.business, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
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
              const SizedBox(height: 16),
              // Vehicles List
              ...List.generate(_vehicleNameControllers.length, (index) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Vehicle ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ),
                        if (_vehicleNameControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeVehicleRow(index),
                            tooltip: 'Remove this vehicle',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Vehicle Name
                    TextFormField(
                      controller: _vehicleNameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Vehicle Name *',
                        hintText: 'e.g., Car, Bike, etc.',
                        prefixIcon: const Icon(Icons.directions_car, color: Colors.teal),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                      validator: (value) {
                        // Only validate if other vehicles have values or this is the first vehicle
                        bool hasOtherVehicles = false;
                        for (int i = 0; i < _vehicleNameControllers.length; i++) {
                          if (i != index && _vehicleNameControllers[i].text.trim().isNotEmpty) {
                            hasOtherVehicles = true;
                            break;
                          }
                        }
                        if (hasOtherVehicles && (value == null || value.trim().isEmpty)) {
                          return 'Vehicle name is required';
                        }
                        return null;
                      },
                    ),
                    if (index < _vehicleNameControllers.length - 1) const SizedBox(height: 16),
                  ],
                );
              }),
              const SizedBox(height: 16),
              // Add More Vehicles Button
              OutlinedButton.icon(
                onPressed: _addVehicleRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Vehicle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  side: BorderSide(color: Colors.teal.shade700),
                ),
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
            backgroundColor: Colors.teal.shade700,
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
              : const Text('Create'),
        ),
      ],
    );
  }
}

