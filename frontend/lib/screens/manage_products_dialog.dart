import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/sector.dart';
import 'edit_product_dialog.dart';

class ManageProductsDialog extends StatefulWidget {
  final bool isMainAdmin;
  final String? selectedSector;

  const ManageProductsDialog({
    super.key,
    required this.isMainAdmin,
    this.selectedSector,
  });

  @override
  State<ManageProductsDialog> createState() => _ManageProductsDialogState();
}

class _ManageProductsDialogState extends State<ManageProductsDialog> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Sector> _sectors = [];
  bool _isLoading = false;
  bool _sortAscending = true; // Sort direction for Sector column
  String? _searchSectorCode; // Selected sector for search filter

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.getProducts();
      final sectors = await ApiService.getSectors();
      if (mounted) {
        // Filter products by selected sector
        List<Map<String, dynamic>> filteredProducts = products;
        if (widget.selectedSector != null) {
          filteredProducts = products.where((product) {
            final productSector = product['sector_code']?.toString();
            return productSector == widget.selectedSector;
          }).toList();
        }
        
        setState(() {
          _products = filteredProducts;
          _filteredProducts = filteredProducts;
          _sectors = sectors;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getSectorName(String? sectorCode) {
    if (sectorCode == null) return 'N/A';
    final sector = _sectors.firstWhere(
      (s) => s.code == sectorCode,
      orElse: () => Sector(code: sectorCode, name: sectorCode),
    );
    return sector.name;
  }

  Future<void> _deleteProduct(int productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"?'),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.deleteProduct(productId.toString());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editProduct(Map<String, dynamic> productData) async {
    final product = Product(
      id: productData['id'] as int,
      productName: productData['product_name'] as String,
      sectorCode: productData['sector_code'] as String,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditProductDialog(product: product),
    );

    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Products',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (widget.selectedSector != null)
                        Text(
                          'Sector: ${_getSectorName(widget.selectedSector)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        )
                      else
                        const Text(
                          'All Sectors',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            // Sector Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  const Text('Search by Sector:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _searchSectorCode,
                      decoration: InputDecoration(
                        hintText: 'All Sectors',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Sectors'),
                        ),
                        ..._sectors.map((sector) {
                          return DropdownMenuItem<String>(
                            value: sector.code,
                            child: Text('${sector.code} - ${sector.name}'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _searchSectorCode = value;
                          if (value == null) {
                            _filteredProducts = _products;
                          } else {
                            _filteredProducts = _products.where((product) {
                              return product['sector_code']?.toString() == value;
                            }).toList();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 20,
                            sortColumnIndex: 1,
                            sortAscending: _sortAscending,
                            columns: [
                              const DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                label: const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
                                onSort: (columnIndex, ascending) {
                                  setState(() {
                                    _sortAscending = ascending;
                                    _products.sort((a, b) {
                                      final aName = _getSectorName(a['sector_code']?.toString()).toLowerCase();
                                      final bName = _getSectorName(b['sector_code']?.toString()).toLowerCase();
                                      return ascending
                                          ? aName.compareTo(bName)
                                          : bName.compareTo(aName);
                                    });
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredProducts.map((product) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(product['product_name']?.toString() ?? 'N/A')),
                                  DataCell(Text(_getSectorName(product['sector_code']?.toString()))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit',
                                          onPressed: () => _editProduct(product),
                                        ),
                                        if (widget.isMainAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            tooltip: 'Delete',
                                            onPressed: () => _deleteProduct(
                                              product['id'] as int,
                                              product['product_name']?.toString() ?? 'Product',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

