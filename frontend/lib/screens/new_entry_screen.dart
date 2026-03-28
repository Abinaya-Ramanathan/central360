import 'package:flutter/material.dart';
import '../models/sector.dart';
import 'add_sector_dialog.dart';
import 'add_product_dialog.dart';
import 'manage_products_dialog.dart';
import 'manage_sectors_dialog.dart';
import 'add_stock_item_dialog.dart';
import 'manage_stock_items_dialog.dart';
import 'add_item_name_dialog.dart';
import 'manage_item_names_dialog.dart';
import 'add_rent_vehicle_dialog.dart';
import 'manage_rent_vehicles_dialog.dart';
import 'add_mining_activity_dialog.dart';
import 'manage_mining_activities_dialog.dart';
import '../widgets/sector_notes_app_bar_button.dart';

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
        actions: [
          SectorNotesAppBarButton(sectorCode: _selectedSector),
        ],
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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.start,
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
                        _buildAdminButton(
                          icon: Icons.directions_car,
                          label: 'Add Rent Vehicle',
                          color: Colors.teal.shade700,
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddRentVehicleDialog(),
                            );
                            if (result == true) {
                              // Rent vehicle created successfully
                            }
                          },
                        ),
                        _buildAdminButton(
                          icon: Icons.car_rental,
                          label: 'Manage Rent Vehicle',
                          color: Colors.cyan.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageRentVehiclesDialog(
                                isMainAdmin: widget.isMainAdmin,
                                selectedSector: _selectedSector,
                              ),
                            );
                          },
                        ),
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
                        _buildAdminButton(
                          icon: Icons.label,
                          label: 'Add Item Name',
                          color: Colors.indigo.shade700,
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddItemNameDialog(),
                            );
                            if (result == true) {}
                          },
                        ),
                        _buildAdminButton(
                          icon: Icons.list_alt,
                          label: 'Manage Item Name',
                          color: Colors.deepPurple.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageItemNamesDialog(
                                isMainAdmin: widget.isMainAdmin,
                                selectedSector: _selectedSector,
                              ),
                            );
                          },
                        ),
                        _buildAdminButton(
                          icon: Icons.construction,
                          label: 'Add Mining Activity',
                          color: Colors.amber.shade700,
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => const AddMiningActivityDialog(),
                            );
                            if (result == true) {
                              // Mining activity created successfully
                            }
                          },
                        ),
                        _buildAdminButton(
                          icon: Icons.settings,
                          label: 'Manage Mining Activity',
                          color: Colors.orange.shade700,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ManageMiningActivitiesDialog(
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
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

