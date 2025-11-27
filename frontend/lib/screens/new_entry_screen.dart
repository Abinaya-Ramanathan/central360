import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/sector.dart';
import 'add_sector_dialog.dart';
import 'add_product_dialog.dart';
import 'manage_products_dialog.dart';
import 'manage_sectors_dialog.dart';
import 'add_stock_item_dialog.dart';
import 'manage_stock_items_dialog.dart';
import 'home_screen.dart';

class NewEntryScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
  final bool isMainAdmin;

  const NewEntryScreen({
    super.key,
    required this.username,
    this.selectedSector,
    this.isMainAdmin = false,
  });

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  String? _selectedSector;

  @override
  void initState() {
    super.initState();
    _selectedSector = widget.selectedSector;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Entry'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  username: AuthService.username.isNotEmpty ? AuthService.username : widget.username,
                  initialSector: _selectedSector,
                  isAdmin: AuthService.isAdmin,
                  isMainAdmin: AuthService.isMainAdmin,
                ),
              ),
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        _buildAdminButton(
                          icon: Icons.add_business,
                          label: 'Add Sector',
                          color: Colors.green.shade700,
                          onPressed: () async {
                            await showDialog<Sector>(
                              context: context,
                              builder: (context) => const AddSectorDialog(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAdminButton(
                          icon: Icons.business,
                          label: 'Manage Sectors',
                          color: Colors.indigo.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageSectorsDialog(isMainAdmin: widget.isMainAdmin),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAdminButton(
                          icon: Icons.add_shopping_cart,
                          label: 'Add Production Item',
                          color: Colors.orange.shade700,
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddProductDialog(),
                            );
                            if (result == true) {
                              // Product created successfully
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAdminButton(
                          icon: Icons.inventory_2,
                          label: 'Manage Production Item',
                          color: Colors.purple.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageProductsDialog(
                                isMainAdmin: widget.isMainAdmin,
                                selectedSector: _selectedSector,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAdminButton(
                          icon: Icons.add_box,
                          label: 'Add Stock Item',
                          color: Colors.brown.shade700,
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddStockItemDialog(),
                            );
                            if (result == true) {
                              // Stock item created successfully
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAdminButton(
                          icon: Icons.inventory,
                          label: 'Manage Stock Item',
                          color: Colors.grey.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageStockItemsDialog(
                                isMainAdmin: widget.isMainAdmin,
                                selectedSector: _selectedSector,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

