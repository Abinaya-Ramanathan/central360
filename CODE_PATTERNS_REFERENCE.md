# 📚 Code Patterns Reference - Quick Copy & Paste Guide

## 🎯 **This guide helps you add new features quickly by copying existing patterns!**

---

## 📁 **1. Creating a New Model**

### **Template: Copy from `employee.dart`**

```dart
// File: lib/models/your_model.dart
class YourModel {
  final int? id;
  final String? sectorCode;
  final String name;
  final String description;
  // Add more fields as needed
  
  YourModel({
    this.id,
    this.sectorCode,
    required this.name,
    required this.description,
  });
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sectorCode != null) 'sector_code': sectorCode,
      'name': name,
      'description': description,
    };
  }
  
  factory YourModel.fromJson(Map<String, dynamic> json) {
    return YourModel(
      id: _parseId(json['id']),
      sectorCode: json['sector_code'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
  
  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
```

**Copy from**: `lib/models/employee.dart` or any model file

---

## 🔌 **2. Adding API Service Methods**

### **Template: CRUD Operations**

```dart
// File: lib/services/api_service.dart

// GET ALL
static Future<List<YourModel>> getYourModels({String? sector}) async {
  final uri = Uri.parse('$baseUrl/your-models');
  if (sector != null) {
    uri = uri.replace(queryParameters: {'sector': sector});
  }
  final response = await http.get(uri);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data.map((json) => YourModel.fromJson(json)).toList();
  }
  String errorMessage = 'Failed to load your models';
  try {
    final errorBody = json.decode(response.body);
    if (errorBody is Map && errorBody.containsKey('message')) {
      errorMessage = errorBody['message'];
    }
  } catch (e) {
    errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
  }
  throw Exception(errorMessage);
}

// CREATE
static Future<YourModel> createYourModel(YourModel model) async {
  final response = await http.post(
    Uri.parse('$baseUrl/your-models'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(model.toJson()),
  );
  if (response.statusCode == 200 || response.statusCode == 201) {
    return YourModel.fromJson(json.decode(response.body));
  }
  String errorMessage = 'Failed to create your model';
  try {
    final errorBody = json.decode(response.body);
    if (errorBody is Map && errorBody.containsKey('message')) {
      errorMessage = errorBody['message'];
    } else {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }
  } catch (e) {
    errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
  }
  throw Exception(errorMessage);
}

// UPDATE
static Future<YourModel> updateYourModel(YourModel model) async {
  final response = await http.put(
    Uri.parse('$baseUrl/your-models/${model.id}'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(model.toJson()),
  );
  if (response.statusCode == 200) {
    return YourModel.fromJson(json.decode(response.body));
  }
  String errorMessage = 'Failed to update your model';
  try {
    final errorBody = json.decode(response.body);
    if (errorBody is Map && errorBody.containsKey('message')) {
      errorMessage = errorBody['message'];
    } else {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }
  } catch (e) {
    errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
  }
  throw Exception(errorMessage);
}

// DELETE
static Future<void> deleteYourModel(int id) async {
  final response = await http.delete(Uri.parse('$baseUrl/your-models/$id'));
  if (response.statusCode != 200 && response.statusCode != 204) {
    String errorMessage = 'Failed to delete your model';
    try {
      final errorBody = json.decode(response.body);
      if (errorBody is Map && errorBody.containsKey('message')) {
        errorMessage = errorBody['message'];
      } else {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }
    throw Exception(errorMessage);
  }
}
```

**Copy from**: `lib/services/api_service.dart` - Look for similar CRUD methods

---

## 🎨 **3. Creating Add/Edit Dialog**

### **Template: Copy from `add_employee_dialog.dart`**

```dart
// File: lib/screens/add_your_dialog.dart
import 'package:flutter/material.dart';
import '../models/your_model.dart';
import '../services/api_service.dart';

class AddYourDialog extends StatefulWidget {
  final YourModel? item; // null for add, YourModel for edit
  final String? selectedSector;

  const AddYourDialog({
    super.key,
    this.item,
    this.selectedSector,
  });

  static Future<YourModel?> show(BuildContext context, {
    YourModel? item,
    String? selectedSector,
  }) async {
    return showDialog<YourModel?>(
      context: context,
      builder: (context) => AddYourDialog(item: item, selectedSector: selectedSector),
    );
  }

  @override
  State<AddYourDialog> createState() => _AddYourDialogState();
}

class _AddYourDialogState extends State<AddYourDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final model = YourModel(
        id: widget.item?.id,
        sectorCode: widget.selectedSector,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (widget.item == null) {
        await ApiService.createYourModel(model);
      } else {
        await ApiService.updateYourModel(model);
      }

      if (mounted) {
        Navigator.of(context).pop(model);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Your Model' : 'Edit Your Model'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              // Add more fields as needed
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.item == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
```

**Copy from**: `lib/screens/add_employee_dialog.dart` or any add dialog

---

## 📊 **4. Creating Main Screen with Table**

### **Template: Copy from `employee_details_screen.dart`**

```dart
// File: lib/screens/your_feature_screen.dart
import 'package:flutter/material.dart';
import '../models/your_model.dart';
import '../services/api_service.dart';
import 'add_your_dialog.dart';

class YourFeatureScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;

  const YourFeatureScreen({
    super.key,
    required this.username,
    this.selectedSector,
  });

  @override
  State<YourFeatureScreen> createState() => _YourFeatureScreenState();
}

class _YourFeatureScreenState extends State<YourFeatureScreen> {
  List<YourModel> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ApiService.getYourModels(sector: widget.selectedSector);
      if (mounted) {
        setState(() => _items = items);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addItem() async {
    final result = await AddYourDialog.show(context, selectedSector: widget.selectedSector);
    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _editItem(YourModel item) async {
    final result = await AddYourDialog.show(context, item: item, selectedSector: widget.selectedSector);
    if (result != null) {
      await _loadItems();
    }
  }

  Future<void> _deleteItem(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteYourModel(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully'), backgroundColor: Colors.green),
          );
          await _loadItems();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Feature'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
            onPressed: _addItem,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No items found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _items.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item.name)),
                          DataCell(Text(item.description)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _editItem(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _deleteItem(item.id!),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
```

**Copy from**: `lib/screens/employee_details_screen.dart` or similar screen

---

## 🗄️ **5. Creating Backend Route**

### **Template: Copy from any route file**

```javascript
// File: backend/src/routes/your_feature.routes.js
import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET ALL
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM your_table WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching items:', err);
    res.status(500).json({ message: 'Error fetching items' });
  }
});

// CREATE
router.post('/', async (req, res) => {
  try {
    const { name, description, sector_code } = req.body;
    const { rows } = await db.query(
      `INSERT INTO your_table (name, description, sector_code) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [name, description, sector_code]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating item:', err);
    res.status(500).json({ message: 'Error creating item' });
  }
});

// UPDATE
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description } = req.body;
    const { rows } = await db.query(
      `UPDATE your_table 
       SET name = $1, description = $2, updated_at = CURRENT_TIMESTAMP 
       WHERE id = $3 
       RETURNING *`,
      [name, description, id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Item not found' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error('Error updating item:', err);
    res.status(500).json({ message: 'Error updating item' });
  }
});

// DELETE
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rowCount } = await db.query('DELETE FROM your_table WHERE id = $1', [id]);
    if (rowCount === 0) {
      return res.status(404).json({ message: 'Item not found' });
    }
    res.status(204).send();
  } catch (err) {
    console.error('Error deleting item:', err);
    res.status(500).json({ message: 'Error deleting item' });
  }
});

export default router;
```

**Copy from**: `backend/src/routes/employee.routes.js` or any route file

---

## 🗄️ **6. Register Route in Server**

### **Add to `backend/src/server.js`:**

```javascript
// Import
import yourFeatureRouter from './routes/your_feature.routes.js';

// Register
app.use('/api/v1/your-feature', yourFeatureRouter);
```

**Copy from**: Existing route registrations in `server.js`

---

## 📊 **7. Update Database Schema**

### **Add to `backend/src/migrations/001_complete_schema.sql`:**

```sql
-- ============================================
-- YOUR TABLE NAME
-- ============================================
CREATE TABLE IF NOT EXISTS your_table (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_your_table_sector ON your_table(sector_code);
CREATE INDEX IF NOT EXISTS idx_your_table_name ON your_table(name);
```

**Copy from**: Existing table definitions in schema file

---

## 🏠 **8. Add Navigation in Home Screen**

### **Add to `lib/screens/home_screen.dart`:**

```dart
ElevatedButton.icon(
  icon: const Icon(Icons.your_icon),
  label: const Text('Your Feature'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YourFeatureScreen(
          username: widget.username,
          selectedSector: _selectedSector,
        ),
      ),
    );
  },
),
```

**Copy from**: Existing buttons in `home_screen.dart`

---

## ✅ **That's It!**

**Follow these patterns for any new feature:**
1. ✅ Copy similar code
2. ✅ Rename and update
3. ✅ Test locally
4. ✅ Build and deploy

**Everything follows the same patterns - just copy and modify!** 🚀

