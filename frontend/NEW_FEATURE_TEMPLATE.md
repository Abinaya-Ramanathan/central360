# 🆕 Adding New Feature - Quick Template

## 📋 Quick Checklist

When adding a new feature, follow this checklist:

### **Frontend Steps:**

1. ✅ **Create Model** → `lib/models/your_feature.dart`
   - Copy from: `lib/models/employee.dart`
   - Update: Class name, fields, methods

2. ✅ **Add API Methods** → `lib/services/api_service.dart`
   - Copy from: Similar CRUD methods
   - Update: URLs, model names

3. ✅ **Create Add/Edit Dialog** → `lib/screens/add_your_feature_dialog.dart`
   - Copy from: `lib/screens/add_employee_dialog.dart`
   - Update: Form fields, validation

4. ✅ **Create Main Screen** → `lib/screens/your_feature_screen.dart`
   - Copy from: `lib/screens/employee_details_screen.dart`
   - Update: Model, API calls, UI

5. ✅ **Add Navigation** → `lib/screens/home_screen.dart`
   - Copy from: Existing button
   - Update: Label, icon, navigation

6. ✅ **Add View Option** (if needed)
   - Copy: `_viewEmployee()` pattern
   - Update: Fields to display

7. ✅ **Add PDF Export** (if needed)
   - Copy: `PdfGenerator` method
   - Update: Fields, format

### **Backend Steps:**

1. ✅ **Create Route** → `backend/src/routes/your_feature.routes.js`
   - Copy from: Any route file
   - Update: Table name, fields

2. ✅ **Register Route** → `backend/src/server.js`
   ```javascript
   import yourFeatureRouter from './routes/your_feature.routes.js';
   app.use('/api/v1/your-feature', yourFeatureRouter);
   ```

3. ✅ **Update Schema** → `backend/src/migrations/001_complete_schema.sql`
   - Add table or columns
   - Add indexes

---

## 🎯 **Example: Adding "Inventory" Feature**

### **Step 1: Create Model**

**File**: `lib/models/inventory.dart`
```dart
// Copy from employee.dart, update fields
class Inventory {
  final int? id;
  final String itemName;
  final int quantity;
  // ... more fields
}
```

### **Step 2: Add API Methods**

**File**: `lib/services/api_service.dart`
```dart
// Copy CRUD methods, update URLs
static Future<List<Inventory>> getInventories() async {
  // Copy pattern from getEmployees()
}

static Future<Inventory> createInventory(Inventory item) async {
  // Copy pattern from createEmployee()
}
```

### **Step 3: Create Dialog**

**File**: `lib/screens/add_inventory_dialog.dart`
```dart
// Copy from add_employee_dialog.dart
// Update form fields and API calls
```

### **Step 4: Create Screen**

**File**: `lib/screens/inventory_screen.dart`
```dart
// Copy from employee_details_screen.dart
// Update model imports and API calls
```

### **Step 5: Add Navigation**

**File**: `lib/screens/home_screen.dart`
```dart
// Add button similar to existing buttons
ElevatedButton.icon(
  icon: Icon(Icons.inventory),
  label: Text('Inventory'),
  onPressed: () {
    Navigator.push(...);
  },
)
```

### **Step 6: Backend Route**

**File**: `backend/src/routes/inventory.routes.js`
```javascript
// Copy from employee.routes.js
// Update table name and fields
```

### **Step 7: Update Schema**

**File**: `backend/src/migrations/001_complete_schema.sql`
```sql
-- Add table definition
CREATE TABLE IF NOT EXISTS inventory (
  id SERIAL PRIMARY KEY,
  item_name VARCHAR(255) NOT NULL,
  quantity INTEGER DEFAULT 0,
  -- ... more columns
);
```

---

## ✅ **Done!**

**That's it!** Follow the same pattern for any new feature. Everything follows consistent patterns throughout the codebase!

