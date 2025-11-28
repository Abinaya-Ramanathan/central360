import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class AddStockItemDialog extends StatefulWidget {
  final String? preSelectedSector;

  const AddStockItemDialog({super.key, this.preSelectedSector});

  @override
  State<AddStockItemDialog> createState() => _AddStockItemDialogState();
}

class _AddStockItemDialogState extends State<AddStockItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _itemNameControllers = [TextEditingController()];
  final List<TextEditingController> _vehicleTypeControllers = [TextEditingController()];
  final List<TextEditingController> _partNumberControllers = [TextEditingController()];
  String? _selectedSectorCode;
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSectorCode = widget.preSelectedSector;
    _loadSectors();
    // Check if user is admin (you may need to pass this from parent)
    // For now, we'll show fields for all users but backend will handle visibility
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

  void _addItemRow() {
    setState(() {
      _itemNameControllers.add(TextEditingController());
      _vehicleTypeControllers.add(TextEditingController());
      _partNumberControllers.add(TextEditingController());
    });
  }

  void _removeItemRow(int index) {
    if (_itemNameControllers.length > 1) {
      setState(() {
        _itemNameControllers[index].dispose();
        _vehicleTypeControllers[index].dispose();
        _partNumberControllers[index].dispose();
        _itemNameControllers.removeAt(index);
        _vehicleTypeControllers.removeAt(index);
        _partNumberControllers.removeAt(index);
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

    // Validate that at least one item name is filled
    bool hasAtLeastOneItem = false;
    for (var controller in _itemNameControllers) {
      if (controller.text.trim().isNotEmpty) {
        hasAtLeastOneItem = true;
        break;
      }
    }

    if (!hasAtLeastOneItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one item name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    try {
      for (int i = 0; i < _itemNameControllers.length; i++) {
        final itemName = _itemNameControllers[i].text.trim();
        if (itemName.isEmpty) continue; // Skip empty items

        try {
          await ApiService.createStockItem(
            itemName,
            _selectedSectorCode!,
            vehicleType: _vehicleTypeControllers[i].text.trim().isEmpty 
                ? null 
                : _vehicleTypeControllers[i].text.trim(),
            partNumber: _partNumberControllers[i].text.trim().isEmpty 
                ? null 
                : _partNumberControllers[i].text.trim(),
          );
          successCount++;
        } catch (e) {
          errorCount++;
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          errorMessages.add('$itemName: $errorMessage');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        String message;
        if (errorCount == 0) {
          message = '$successCount stock item(s) created successfully';
        } else {
          message = '$successCount item(s) created, $errorCount failed. ${errorMessages.join("; ")}';
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
    for (var controller in _itemNameControllers) {
      controller.dispose();
    }
    for (var controller in _vehicleTypeControllers) {
      controller.dispose();
    }
    for (var controller in _partNumberControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_box, color: Colors.brown.shade700),
          const SizedBox(width: 8),
          const Text('Add Stock Item'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sector Dropdown (shared for all items)
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector * (applies to all items)',
                  prefixIcon: const Icon(Icons.business, color: Colors.brown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.brown, width: 2),
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
              // Items List
              ...List.generate(_itemNameControllers.length, (index) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Item ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade700,
                            ),
                          ),
                        ),
                        if (_itemNameControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItemRow(index),
                            tooltip: 'Remove this item',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Item Name
                    TextFormField(
                      controller: _itemNameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'e.g., Rice, Oil, etc.',
                        prefixIcon: const Icon(Icons.inventory, color: Colors.brown),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.brown, width: 2),
                        ),
                      ),
                      validator: (value) {
                        // Only validate if other items have values or this is the first item
                        bool hasOtherItems = false;
                        for (int i = 0; i < _itemNameControllers.length; i++) {
                          if (i != index && _itemNameControllers[i].text.trim().isNotEmpty) {
                            hasOtherItems = true;
                            break;
                          }
                        }
                        if (hasOtherItems && (value == null || value.trim().isEmpty)) {
                          return 'Item name is required';
                        }
                        return null;
                      },
                    ),
                    // Vehicle Type and Part Number (only for SSEW sector)
                    if (_selectedSectorCode == 'SSEW') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _vehicleTypeControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Vehicle Type',
                          hintText: 'e.g., Truck, Car, etc.',
                          prefixIcon: const Icon(Icons.directions_car, color: Colors.brown),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.brown, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _partNumberControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Part Number',
                          hintText: 'e.g., PN-12345',
                          prefixIcon: const Icon(Icons.tag, color: Colors.brown),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.brown, width: 2),
                          ),
                        ),
                      ),
                    ],
                    if (index < _itemNameControllers.length - 1) const SizedBox(height: 16),
                  ],
                );
              }),
              const SizedBox(height: 16),
              // Add More Items Button
              OutlinedButton.icon(
                onPressed: _addItemRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Item'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.brown.shade700,
                  side: BorderSide(color: Colors.brown.shade700),
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
            backgroundColor: Colors.brown.shade700,
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

