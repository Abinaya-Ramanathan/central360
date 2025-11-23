# 🛠️ Development Guide - Adding New Features

## 📋 Easiest Way to Add New Code in the Future

This guide shows you the **easiest workflow** for adding new features to Central360.

---

## 🎯 **Quick Workflow Overview**

### **When Adding a New Feature:**

1. **Create Model** (if needed) → `lib/models/`
2. **Add API Service** (if needed) → `lib/services/api_service.dart`
3. **Create Screen/Dialog** → `lib/screens/`
4. **Add Navigation** → `lib/screens/home_screen.dart`
5. **Update Backend** (if needed) → `backend/src/`
6. **Test** → Build and test
7. **Build & Deploy** → Use build scripts

**That's it!** ✅

---

## 📁 **Project Structure**

Your codebase follows a clear structure:

```
frontend/lib/
├── models/          # Data models (Employee, Vehicle, etc.)
├── screens/         # UI screens and dialogs
├── services/        # API services and business logic
├── utils/           # Utilities (PDF generator, etc.)
└── config/          # Configuration (environment, etc.)

backend/src/
├── routes/          # API routes
├── migrations/      # Database migrations
└── server.js        # Main server file
```

---

## 🚀 **Step-by-Step: Adding a New Feature**

### **Example: Adding a "Products" Feature (Already Exists - Just Example)**

#### **Step 1: Create Model** ✅

**Location**: `lib/models/product.dart`

**Pattern to Follow:**
```dart
class Product {
  final int? id;
  final String productName;
  final String sectorCode;
  
  Product({
    this.id,
    required this.productName,
    required this.sectorCode,
  });
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_name': productName,
      'sector_code': sectorCode,
    };
  }
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _parseId(json['id']),
      productName: json['product_name'] as String,
      sectorCode: json['sector_code'] as String,
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

**What to Copy:**
- Copy any existing model file (e.g., `employee.dart`)
- Rename the class
- Update fields and methods
- Done! ✅

---

#### **Step 2: Add API Service Methods** ✅

**Location**: `lib/services/api_service.dart`

**Pattern to Follow:**
```dart
// Get all products
static Future<List<Product>> getProducts({String? sector}) async {
  final uri = Uri.parse('$baseUrl/products');
  if (sector != null) {
    uri = uri.replace(queryParameters: {'sector': sector});
  }
  final response = await http.get(uri);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data.map((json) => Product.fromJson(json)).toList();
  }
  throw Exception('Failed to load products');
}

// Create product
static Future<Product> createProduct(Product product) async {
  final response = await http.post(
    Uri.parse('$baseUrl/products'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(product.toJson()),
  );
  if (response.statusCode == 200 || response.statusCode == 201) {
    return Product.fromJson(json.decode(response.body));
  }
  throw Exception('Failed to create product');
}

// Update product
static Future<Product> updateProduct(Product product) async {
  final response = await http.put(
    Uri.parse('$baseUrl/products/${product.id}'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode(product.toJson()),
  );
  if (response.statusCode == 200) {
    return Product.fromJson(json.decode(response.body));
  }
  throw Exception('Failed to update product');
}

// Delete product
static Future<void> deleteProduct(int id) async {
  final response = await http.delete(Uri.parse('$baseUrl/products/$id'));
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('Failed to delete product');
  }
}
```

**What to Copy:**
- Copy any existing CRUD methods from `api_service.dart`
- Change URLs and model names
- Done! ✅

---

#### **Step 3: Create Screen/Dialog** ✅

**Location**: `lib/screens/`

**Pattern to Follow:**

**A. Dialog for Add/Edit** (e.g., `add_product_dialog.dart`):
- Copy any existing dialog (e.g., `add_employee_dialog.dart`)
- Update form fields
- Update API calls
- Done! ✅

**B. Main Screen** (e.g., `product_screen.dart`):
- Copy any existing screen (e.g., `employee_details_screen.dart`)
- Update model imports
- Update API calls
- Update UI components
- Done! ✅

**Key Pattern:**
```dart
class ProductScreen extends StatefulWidget {
  // Constructor with required parameters
}

class _ProductScreenState extends State<ProductScreen> {
  List<Product> _products = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.getProducts(sector: widget.selectedSector);
      setState(() => _products = products);
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // Add, Edit, Delete methods following same pattern
}
```

---

#### **Step 4: Add Navigation** ✅

**Location**: `lib/screens/home_screen.dart`

**Pattern to Follow:**
```dart
ElevatedButton.icon(
  icon: Icon(Icons.inventory),
  label: Text('Products'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductScreen(
          username: widget.username,
          selectedSector: _selectedSector,
        ),
      ),
    );
  },
)
```

**What to Copy:**
- Copy any existing button from `home_screen.dart`
- Update icon, label, and navigation
- Done! ✅

---

#### **Step 5: Update Backend (If Needed)** ✅

**A. Add Route** → `backend/src/routes/`
- Copy any existing route file
- Update table name and fields
- Done! ✅

**B. Register Route** → `backend/src/server.js`
```javascript
import productRouter from './routes/product.routes.js';
app.use('/api/v1/products', productRouter);
```

**C. Update Database Schema** → `backend/src/migrations/001_complete_schema.sql`
- Add new table if needed
- Or update existing table with new columns
- Done! ✅

---

## 📝 **Quick Reference: File Locations**

### **Frontend:**

| What to Add | Where | Copy From |
|-------------|-------|-----------|
| New Model | `lib/models/your_model.dart` | Any model file |
| API Methods | `lib/services/api_service.dart` | Similar CRUD methods |
| Add/Edit Dialog | `lib/screens/add_your_dialog.dart` | `add_employee_dialog.dart` |
| Main Screen | `lib/screens/your_screen.dart` | `employee_details_screen.dart` |
| Navigation | `lib/screens/home_screen.dart` | Existing buttons |
| PDF Export | `lib/utils/pdf_generator.dart` | Existing PDF methods |

### **Backend:**

| What to Add | Where | Copy From |
|-------------|-------|-----------|
| API Route | `backend/src/routes/your_route.js` | Any route file |
| Register Route | `backend/src/server.js` | Existing route imports |
| Database Table | `backend/src/migrations/001_complete_schema.sql` | Existing tables |
| Default Data | `backend/src/migrations/002_default_data.sql` | Existing inserts |

---

## 🔄 **Common Patterns to Follow**

### **Pattern 1: Adding a New Screen**

1. ✅ Copy similar screen (e.g., `employee_details_screen.dart`)
2. ✅ Rename class and file
3. ✅ Update imports (model, API service)
4. ✅ Update API calls (use new model methods)
5. ✅ Update UI components
6. ✅ Add navigation in `home_screen.dart`
7. ✅ Test
8. ✅ Done! ✅

### **Pattern 2: Adding a New Field to Existing Feature**

**Example: Add "Notes" field to Employee**

1. ✅ Update Model → `lib/models/employee.dart`
   - Add `final String? notes;`
   - Update `toJson()` and `fromJson()`

2. ✅ Update Dialog → `lib/screens/add_employee_dialog.dart`
   - Add `TextFormField` for notes

3. ✅ Update Screen → `lib/screens/employee_details_screen.dart`
   - Add column in table
   - Display notes value

4. ✅ Update Backend → `backend/src/routes/employee.routes.js`
   - Add `notes` to INSERT/UPDATE queries

5. ✅ Update Schema (if needed) → `backend/src/migrations/001_complete_schema.sql`
   - Add `notes TEXT` column

6. ✅ Test
7. ✅ Done! ✅

### **Pattern 3: Adding New Date Field with Notifications**

**Example: Add "Renewal Date" to Vehicle License**

1. ✅ Update Model → Add `final DateTime? renewalDate;`
2. ✅ Update Dialog → Add date picker
3. ✅ Update Screen → Add column with sort option
4. ✅ Update API → Add field to queries
5. ✅ Update Database → Add column
6. ✅ Update Notifications → Add check in `notification_service.dart`
   - Copy existing date check pattern
7. ✅ Test
8. ✅ Done! ✅

---

## 🛠️ **Development Workflow**

### **Step 1: Set Up Development Environment**

```bash
# Terminal 1: Backend
cd backend
npm install
npm start

# Terminal 2: Frontend
cd frontend
flutter pub get
flutter run
```

### **Step 2: Make Changes**

1. Edit files in your IDE
2. Save files
3. Flutter hot reload updates automatically (if running)
4. Test in app

### **Step 3: Test Changes**

1. Run `flutter run` (if not already running)
2. Test new features
3. Fix any errors
4. Test again

### **Step 4: Build Release**

```bash
cd frontend
build-release.bat  # Windows
# OR
bash build-release.sh  # Linux/Mac
```

### **Step 5: Deploy**

1. Upload APK/.exe to website
2. Share download links
3. Done! ✅

---

## 📚 **Code Patterns Reference**

### **CRUD Operations Pattern**

**All features follow the same CRUD pattern:**

```dart
// CREATE
Future<void> _addItem() async {
  // Show dialog → Get data → Call API → Refresh list
}

// READ
Future<void> _loadItems() async {
  // Call API → Update state
}

// UPDATE
Future<void> _editItem(Item item) async {
  // Show dialog with existing data → Update → Call API → Refresh
}

// DELETE
Future<void> _deleteItem(int id) async {
  // Confirm → Call API → Refresh list
}
```

### **Dialog Pattern**

**All dialogs follow the same pattern:**

```dart
class AddItemDialog extends StatefulWidget {
  final Item? item; // null for add, Item for edit
  
  Future<Item?> show(BuildContext context) {
    return showDialog<Item?>(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'field1': TextEditingController(),
    // ... more controllers
  };
  
  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Create Item object → Call API → Close dialog
    }
  }
}
```

### **Screen Pattern**

**All screens follow the same pattern:**

```dart
class ItemScreen extends StatefulWidget {
  final String username;
  final String? selectedSector;
}

class _ItemScreenState extends State<ItemScreen> {
  List<Item> _items = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadItems();
  }
  
  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ApiService.getItems(sector: widget.selectedSector);
      setState(() => _items = items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // UI with DataTable or ListView
}
```

---

## 🔧 **Best Practices**

### **1. Always Follow Existing Patterns**
- ✅ Copy similar code first
- ✅ Modify as needed
- ✅ Keep structure consistent

### **2. Update Both Frontend & Backend**
- ✅ Frontend model ↔ Backend table
- ✅ Frontend API calls ↔ Backend routes
- ✅ Keep them in sync

### **3. Test Before Deploying**
- ✅ Test locally first
- ✅ Test on device/emulator
- ✅ Fix errors before building release

### **4. Keep Code Organized**
- ✅ Models in `lib/models/`
- ✅ Screens in `lib/screens/`
- ✅ Services in `lib/services/`
- ✅ Utils in `lib/utils/`

### **5. Update Database Schema**
- ✅ Update `001_complete_schema.sql` for new tables/columns
- ✅ Add indexes for performance
- ✅ Add foreign keys if needed

---

## 📋 **Checklist: Adding New Feature**

**Use this checklist when adding new features:**

**Frontend:**
- [ ] Create model file (`lib/models/your_model.dart`)
- [ ] Add API methods (`lib/services/api_service.dart`)
- [ ] Create add/edit dialog (`lib/screens/add_your_dialog.dart`)
- [ ] Create main screen (`lib/screens/your_screen.dart`)
- [ ] Add navigation (`lib/screens/home_screen.dart`)
- [ ] Add View option (if needed)
- [ ] Add PDF export (if needed)
- [ ] Add notifications (if date-based feature)

**Backend:**
- [ ] Create route file (`backend/src/routes/your_route.js`)
- [ ] Register route (`backend/src/server.js`)
- [ ] Update schema (`backend/src/migrations/001_complete_schema.sql`)
- [ ] Add indexes (if needed)

**Testing:**
- [ ] Test locally
- [ ] Test on device/emulator
- [ ] Test all CRUD operations
- [ ] Test error handling

**Deployment:**
- [ ] Build release versions
- [ ] Upload to website
- [ ] Share download links

---

## 🆘 **Quick Help**

**When Adding New Code:**

1. **Need a model?** → Copy `employee.dart`, rename, update fields
2. **Need API methods?** → Copy CRUD methods from `api_service.dart`
3. **Need a screen?** → Copy `employee_details_screen.dart`, update
4. **Need a dialog?** → Copy `add_employee_dialog.dart`, update
5. **Need backend route?** → Copy any route file, update
6. **Need database table?** → Copy table definition from schema, update

**Everything follows the same patterns!** ✅

---

## 📞 **Questions?**

**Common Questions:**

1. **Where do I add...?**
   - Models → `lib/models/`
   - Screens → `lib/screens/`
   - API calls → `lib/services/api_service.dart`
   - Backend routes → `backend/src/routes/`

2. **How do I test?**
   - Run `flutter run` → See changes instantly
   - Test all features → Fix errors → Build release

3. **How do I deploy?**
   - Run `build-release.bat` → Get APK and .exe → Upload to website

4. **How do I add a new screen?**
   - Copy similar screen → Update imports → Update UI → Add navigation

**Everything is documented and follows clear patterns!** ✅

