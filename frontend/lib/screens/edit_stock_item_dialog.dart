import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class EditStockItemDialog extends StatefulWidget {
  final int itemId;
  final String itemName;
  final String sectorCode;
  final String? vehicleType;
  final String? partNumber;

  const EditStockItemDialog({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.sectorCode,
    this.vehicleType,
    this.partNumber,
  });

  @override
  State<EditStockItemDialog> createState() => _EditStockItemDialogState();
}

class _EditStockItemDialogState extends State<EditStockItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _partNumberController = TextEditingController();
  String? _selectedSectorCode;
  List<Sector> _sectors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _itemNameController.text = widget.itemName;
    _selectedSectorCode = widget.sectorCode;
    _vehicleTypeController.text = widget.vehicleType ?? '';
    _partNumberController.text = widget.partNumber ?? '';
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
      await ApiService.updateStockItem(
        widget.itemId.toString(),
        _itemNameController.text.trim(),
        _selectedSectorCode!,
        vehicleType: _vehicleTypeController.text.trim().isEmpty ? null : _vehicleTypeController.text.trim(),
        partNumber: _partNumberController.text.trim().isEmpty ? null : _partNumberController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock item updated successfully'),
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
    _itemNameController.dispose();
    _vehicleTypeController.dispose();
    _partNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.brown.shade700),
          const SizedBox(width: 8),
          const Text('Edit Stock Item'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Item Name
              TextFormField(
                controller: _itemNameController,
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              // Vehicle Type and Part Number (only for SSEW sector)
              if (widget.sectorCode == 'SSEW') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleTypeController,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _partNumberController,
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
              const SizedBox(height: 16),
              // Sector Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector *',
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
              : const Text('Update'),
        ),
      ],
    );
  }
}

