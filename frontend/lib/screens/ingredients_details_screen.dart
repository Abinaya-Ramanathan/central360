import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'add_ingredient_dialog.dart';

class IngredientsDetailsScreen extends StatefulWidget {
  final String username;
  final bool isMainAdmin;

  const IngredientsDetailsScreen({
    super.key,
    required this.username,
    this.isMainAdmin = false,
  });

  @override
  State<IngredientsDetailsScreen> createState() => _IngredientsDetailsScreenState();
}

class _IngredientsDetailsScreenState extends State<IngredientsDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _ingredients = [];
  bool _isLoading = false;
  String _searchQuery = '';
  
  // Check Ingredients tab state
  final _checkMenuController = TextEditingController();
  final _checkQuantityController = TextEditingController();
  Map<String, dynamic>? _checkedIngredientMenu;
  List<Map<String, dynamic>> _calculatedIngredients = [];
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadIngredients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _checkMenuController.dispose();
    _checkQuantityController.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    setState(() => _isLoading = true);
    try {
      final ingredients = await ApiService.getIngredients(search: _searchQuery.isEmpty ? null : _searchQuery);
      if (mounted) {
        setState(() {
          _ingredients = ingredients;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ingredients: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteIngredient(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ingredient'),
        content: const Text('Are you sure you want to delete this ingredient menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteIngredient(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingredient deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIngredients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting ingredient: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredIngredients {
    if (_searchQuery.isEmpty) return _ingredients;
    return _ingredients.where((ingredient) {
      final menu = ingredient['menu']?.toString().toLowerCase() ?? '';
      return menu.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients Details'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Existing Ingredients'),
            Tab(text: 'Check Ingredients'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 4),
                Text(widget.username, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                    initialSector: 'SSC',
                    isAdmin: AuthService.isAdmin,
                    isMainAdmin: AuthService.isMainAdmin,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingIngredientsTab(),
          _buildCheckIngredientsTab(),
        ],
      ),
    );
  }

  Widget _buildExistingIngredientsTab() {
    return Column(
      children: [
        // Search Bar and Add Button in same row
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Menu...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                              _loadIngredients();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _loadIngredients();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const AddIngredientDialog(),
                  );
                  if (result == true) {
                    _loadIngredients();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Ingredients'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Ingredients List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredIngredients.isEmpty
                  ? const Center(
                      child: Text(
                        'No ingredients found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _filteredIngredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _filteredIngredients[index];
                        return _buildIngredientNote(ingredient);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildIngredientNote(Map<String, dynamic> ingredient) {
    final bool isEditMode = ingredient['_isEditMode'] == true;
    final String menuId = ingredient['id'].toString();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: isEditMode
                      ? TextField(
                          controller: TextEditingController(text: ingredient['menu']?.toString() ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Menu',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              ingredient['_menu'] = value;
                            });
                          },
                        )
                      : Text(
                          ingredient['menu']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                if (!isEditMode) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        ingredient['_isEditMode'] = true;
                        ingredient['_menu'] = ingredient['menu']?.toString() ?? '';
                        ingredient['_membersCount'] = ingredient['members_count'] ?? 0;
                        ingredient['_ingredients'] = List<Map<String, dynamic>>.from(
                          (ingredient['ingredients'] as List? ?? []).map((ing) => {
                            'ingredient_name': ing['ingredient_name'] ?? '',
                            'quantity': ing['quantity'] ?? 0,
                            'unit': ing['unit'] ?? 'Gram',
                          }),
                        );
                      });
                    },
                  ),
                  if (widget.isMainAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteIngredient(menuId),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            isEditMode
                ? Column(
                    children: [
                      TextField(
                        controller: TextEditingController(
                          text: (ingredient['_membersCount'] ?? ingredient['members_count'] ?? 0).toString(),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Members Count',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            ingredient['_membersCount'] = int.tryParse(value) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ...((ingredient['_ingredients'] as List? ?? []).asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ing = entry.value;
                        return Card(
                          key: ValueKey('ingredient_${menuId}_$idx'),
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
                                        'Ingredient ${idx + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if ((ingredient['_ingredients'] as List).length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        iconSize: 20,
                                        onPressed: () {
                                          setState(() {
                                            (ingredient['_ingredients'] as List).removeAt(idx);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Ingredient Name
                                TextFormField(
                                  key: ValueKey('name_${menuId}_$idx'),
                                  initialValue: ing['ingredient_name']?.toString() ?? '',
                                  decoration: const InputDecoration(
                                    labelText: 'Ingredients Name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.shopping_basket),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      (ingredient['_ingredients'] as List)[idx]['ingredient_name'] = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Quantity
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        key: ValueKey('qty_${menuId}_$idx'),
                                        initialValue: (ing['quantity'] ?? 0.0).toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.numbers),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (value) {
                                          setState(() {
                                            (ingredient['_ingredients'] as List)[idx]['quantity'] = double.tryParse(value) ?? 0.0;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Unit
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey('unit_${menuId}_$idx'),
                                        initialValue: ing['unit']?.toString() ?? 'Gram',
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
                                          if (value != null) {
                                            setState(() {
                                              (ingredient['_ingredients'] as List)[idx]['unit'] = value;
                                            });
                                          }
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
                      const SizedBox(height: 16),
                      // Add Another Ingredients Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              (ingredient['_ingredients'] as List).add({
                                'ingredient_name': '',
                                'quantity': 0.0,
                                'unit': 'Gram',
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add another Ingredients'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                ingredient['_isEditMode'] = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              // Validate that all ingredients have names
                              final ingredientsList = ingredient['_ingredients'] as List? ?? [];
                              for (var ing in ingredientsList) {
                                if (ing['ingredient_name']?.toString().trim().isEmpty ?? true) {
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
                                await ApiService.updateIngredient(
                                  id: menuId,
                                  menu: ingredient['_menu'] ?? ingredient['menu'] ?? '',
                                  membersCount: ingredient['_membersCount'] ?? ingredient['members_count'] ?? 0,
                                  ingredients: ingredientsList.map((ing) => {
                                    'ingredient_name': ing['ingredient_name']?.toString().trim() ?? '',
                                    'quantity': ing['quantity'] ?? 0,
                                    'unit': ing['unit'] ?? 'Gram',
                                  }).toList(),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ingredient updated successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _loadIngredients();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error updating ingredient: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Members Count: ${ingredient['members_count'] ?? 0}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingredients:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...((ingredient['ingredients'] as List? ?? []).map((ing) {
                        final qty = ing['quantity'];
                        final quantity = (qty is int) ? qty.toDouble() : (qty is double) ? qty : 0.0;
                        final unit = ing['unit']?.toString() ?? 'Gram';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• ${ing['ingredient_name'] ?? 'N/A'}: ${_formatQuantityWithUnit(quantity, unit)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      })),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(num quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    } else {
      return quantity.toStringAsFixed(2);
    }
  }

  // Convert and format quantity with unit conversion
  String _formatQuantityWithUnit(num quantity, String unit) {
    String formattedQty = _formatQuantity(quantity);
    
    // Convert Kilogram to Gram if quantity < 1
    if (unit == 'Kilogram' && quantity < 1.0) {
      final grams = quantity * 1000;
      return '${_formatQuantity(grams)} Gram';
    }
    
    // Convert Litre to ml if quantity < 1
    if (unit == 'Litre' && quantity < 1.0) {
      final ml = quantity * 1000;
      return '${_formatQuantity(ml)} ml';
    }
    
    return '$formattedQty $unit';
  }

  Future<void> _checkIngredients() async {
    final menuName = _checkMenuController.text.trim();
    final quantityStr = _checkQuantityController.text.trim();
    
    if (menuName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a menu name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (quantityStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final quantity = double.tryParse(quantityStr);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive quantity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isChecking = true);
    try {
      // Fetch all ingredients to find the matching menu
      final allIngredients = await ApiService.getIngredients();
      
      // Find the menu that matches (case-insensitive)
      final matchingMenu = allIngredients.firstWhere(
        (ingredient) => ingredient['menu']?.toString().toLowerCase() == menuName.toLowerCase(),
        orElse: () => {},
      );
      
      if (matchingMenu.isEmpty || matchingMenu['id'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Menu "$menuName" not found in existing ingredients'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _checkedIngredientMenu = null;
          _calculatedIngredients = [];
        });
        return;
      }
      
      // Get the full menu details
      final menuDetails = await ApiService.getIngredientById(matchingMenu['id'].toString());
      
      // Get original members count
      final originalMembersCount = (menuDetails['members_count'] is int) 
          ? menuDetails['members_count'] as int 
          : (menuDetails['members_count'] is double) 
              ? (menuDetails['members_count'] as double).toInt() 
              : 1;
      
      if (originalMembersCount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid members count in the original menu'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Calculate multiplied quantities based on members count ratio
      // Formula: calculated_quantity = original_quantity * (requested_quantity / original_members_count)
      final ingredients = menuDetails['ingredients'] as List? ?? [];
      final calculated = ingredients.map((ing) {
        // Handle both int and double types from database
        final qty = ing['quantity'];
        final originalQuantity = (qty is int) ? qty.toDouble() : (qty is double) ? qty : 0.0;
        final originalUnit = ing['unit']?.toString() ?? 'Gram';
        // Scale based on members count ratio
        final calculatedQuantity = originalQuantity * (quantity / originalMembersCount);
        return {
          'ingredient_name': ing['ingredient_name'] ?? 'N/A',
          'original_quantity': originalQuantity,
          'calculated_quantity': calculatedQuantity,
          'unit': originalUnit,
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _checkedIngredientMenu = menuDetails;
          _calculatedIngredients = calculated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking ingredients: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Widget _buildCheckIngredientsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter Menu Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Menu Name, Quantity, and Check Button in same row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checkMenuController,
                          decoration: const InputDecoration(
                            labelText: 'Menu Name',
                            hintText: 'Enter menu name (e.g., Sambar)',
                            prefixIcon: Icon(Icons.restaurant_menu),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _checkQuantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: 'Enter quantity (e.g., 5)',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkIngredients,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search),
                        label: Text(_isChecking ? 'Checking...' : 'Check Ingredients'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Results Section
          if (_checkedIngredientMenu != null && _calculatedIngredients.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _checkedIngredientMenu!['menu']?.toString() ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Calculated Ingredients:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...(_calculatedIngredients.map((ing) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        color: Colors.brown.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ing['ingredient_name'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatQuantityWithUnit(ing['calculated_quantity'] as num, ing['unit'] as String),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    })),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

