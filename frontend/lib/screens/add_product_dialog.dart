import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/sector.dart';

class AddProductDialog extends StatefulWidget {
  final String? preSelectedSector;

  const AddProductDialog({super.key, this.preSelectedSector});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _productNameControllers = [TextEditingController()];
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

  void _addProductRow() {
    setState(() {
      _productNameControllers.add(TextEditingController());
    });
  }

  void _removeProductRow(int index) {
    if (_productNameControllers.length > 1) {
      setState(() {
        _productNameControllers[index].dispose();
        _productNameControllers.removeAt(index);
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

    // Validate that at least one product name is filled
    bool hasAtLeastOneProduct = false;
    for (var controller in _productNameControllers) {
      if (controller.text.trim().isNotEmpty) {
        hasAtLeastOneProduct = true;
        break;
      }
    }

    if (!hasAtLeastOneProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one product name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;
    List<String> errorMessages = [];

    try {
      for (int i = 0; i < _productNameControllers.length; i++) {
        final productName = _productNameControllers[i].text.trim();
        if (productName.isEmpty) continue; // Skip empty products

        try {
          await ApiService.createProduct(
            productName,
            _selectedSectorCode!,
          );
          successCount++;
        } catch (e) {
          errorCount++;
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          errorMessages.add('$productName: $errorMessage');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        String message;
        if (errorCount == 0) {
          message = '$successCount product(s) created successfully';
        } else {
          message = '$successCount product(s) created, $errorCount failed. ${errorMessages.join("; ")}';
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
    for (var controller in _productNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_business, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text('Add Product'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sector Dropdown (shared for all products)
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorCode,
                decoration: InputDecoration(
                  labelText: 'Sector * (applies to all products)',
                  prefixIcon: const Icon(Icons.business, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
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
              // Products List
              ...List.generate(_productNameControllers.length, (index) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Product ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        if (_productNameControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeProductRow(index),
                            tooltip: 'Remove this product',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Product Name
                    TextFormField(
                      controller: _productNameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        hintText: 'e.g., Sholling, Milk, etc.',
                        prefixIcon: const Icon(Icons.inventory_2, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.green, width: 2),
                        ),
                      ),
                      validator: (value) {
                        // Only validate if other products have values or this is the first product
                        bool hasOtherProducts = false;
                        for (int i = 0; i < _productNameControllers.length; i++) {
                          if (i != index && _productNameControllers[i].text.trim().isNotEmpty) {
                            hasOtherProducts = true;
                            break;
                          }
                        }
                        if (hasOtherProducts && (value == null || value.trim().isEmpty)) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    if (index < _productNameControllers.length - 1) const SizedBox(height: 16),
                  ],
                );
              }),
              const SizedBox(height: 16),
              // Add More Products Button
              OutlinedButton.icon(
                onPressed: _addProductRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
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
            backgroundColor: Colors.green.shade700,
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

