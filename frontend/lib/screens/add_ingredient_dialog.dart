import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddIngredientDialog extends StatefulWidget {
  const AddIngredientDialog({super.key});

  @override
  State<AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<AddIngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _menuController = TextEditingController();
  final _membersCountController = TextEditingController();
  final List<Map<String, dynamic>> _ingredients = [
    {
      'ingredient_name': '',
      'quantity': 0.0,
      'unit': 'Gram',
    },
  ];

  @override
  void dispose() {
    _menuController.dispose();
    _membersCountController.dispose();
    super.dispose();
  }

  void _addAnotherIngredient() {
    setState(() {
      _ingredients.add({
        'ingredient_name': '',
        'quantity': 0.0,
        'unit': 'Gram',
      });
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that all ingredients have names
    for (var ingredient in _ingredients) {
      if (ingredient['ingredient_name']?.toString().trim().isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all ingredient names'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      await ApiService.createIngredient(
        menu: _menuController.text.trim(),
        membersCount: int.tryParse(_membersCountController.text) ?? 0,
        ingredients: _ingredients.map((ing) => {
          'ingredient_name': ing['ingredient_name']?.toString().trim() ?? '',
          'quantity': ing['quantity'] ?? 0.0,
          'unit': ing['unit'] ?? 'Gram',
        }).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingredient added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding ingredient: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.brown.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Add Ingredients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menu
                      TextFormField(
                        controller: _menuController,
                        decoration: const InputDecoration(
                          labelText: 'Menu',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter menu name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Members Count
                      TextFormField(
                        controller: _membersCountController,
                        decoration: const InputDecoration(
                          labelText: 'Members Count',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter members count';
                          }
                          if (int.tryParse(value) == null || int.parse(value) <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Ingredients List
                      const Text(
                        'Ingredients:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...(_ingredients.asMap().entries.map((entry) {
                        final index = entry.key;
                        final ingredient = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Ingredient ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (_ingredients.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        iconSize: 20,
                                        onPressed: () => _removeIngredient(index),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Ingredient Name
                                TextFormField(
                                  initialValue: ingredient['ingredient_name']?.toString() ?? '',
                                  decoration: const InputDecoration(
                                    labelText: 'Ingredients Name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.shopping_basket),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _ingredients[index]['ingredient_name'] = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter ingredient name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Quantity
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: ingredient['quantity']?.toString() ?? '0',
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.numbers),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            _ingredients[index]['quantity'] = double.tryParse(value) ?? 0.0;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Unit
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: ingredient['unit'] ?? 'Gram',
                                        decoration: const InputDecoration(
                                          labelText: 'Unit',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.scale),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'Litre', child: Text('Litre')),
                                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                                          DropdownMenuItem(value: 'Gram', child: Text('Gram')),
                                          DropdownMenuItem(value: 'Kilogram', child: Text('Kilogram')),
                                          DropdownMenuItem(value: 'Pieces', child: Text('Pieces')),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _ingredients[index]['unit'] = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
                      const SizedBox(height: 12),
                      // Add Another Ingredients Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addAnotherIngredient,
                          icon: const Icon(Icons.add),
                          label: const Text('Add another Ingredients'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer Buttons
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

