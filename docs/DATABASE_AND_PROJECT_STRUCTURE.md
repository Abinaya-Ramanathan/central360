# Central360 - Database Structure & Project Structure

## 📊 Database Structure

### Database: PostgreSQL

The application uses PostgreSQL as the database. Below is the complete schema structure:

---

### Core Tables

#### 1. **sectors**
Stores business sectors/divisions.
```sql
- code (VARCHAR(50), PRIMARY KEY)
- name (VARCHAR(255), NOT NULL)
- created_at (TIMESTAMP)
```

#### 2. **employees**
Employee information and details.
```sql
- id (SERIAL, PRIMARY KEY)
- name (VARCHAR(255), NOT NULL)
- contact (VARCHAR(50), NOT NULL)
- contact2 (VARCHAR(50))
- address (TEXT)
- bank_details (TEXT)
- sector (VARCHAR(50), FK → sectors.code)
- role (VARCHAR(255))
- daily_salary (DECIMAL(10, 2))
- weekly_salary (DECIMAL(10, 2))
- monthly_salary (DECIMAL(10, 2))
- joining_date (DATE)
- joining_year (INTEGER)
- created_at, updated_at (TIMESTAMP)
```

#### 3. **attendance**
Daily employee attendance tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- employee_id (INTEGER, FK → employees.id)
- employee_name (VARCHAR(255))
- sector (VARCHAR(50))
- date (DATE, NOT NULL)
- status (VARCHAR(20), CHECK: 'present', 'absent', 'halfday')
- outstanding_advance (DECIMAL(10, 2))
- advance_taken (DECIMAL(10, 2))
- advance_paid (DECIMAL(10, 2))
- bulk_advance_taken (DECIMAL(10, 2))
- bulk_advance_paid (DECIMAL(10, 2))
- bulk_advance (DECIMAL(10, 2))
- ot_hours (DECIMAL(10, 2))
- created_at, updated_at (TIMESTAMP)
- UNIQUE(employee_id, date)
```

#### 4. **salary_expenses**
Weekly salary calculations and payments.
```sql
- id (SERIAL, PRIMARY KEY)
- employee_id (INTEGER, FK → employees.id)
- employee_name (VARCHAR(255))
- sector (VARCHAR(50))
- week_start_date (DATE)
- week_end_date (DATE)
- outstanding_advance (DECIMAL(10, 2))
- days_present (INTEGER)
- estimated_salary (DECIMAL(10, 2))
- salary_issued (DECIMAL(10, 2))
- salary_issued_date (DATE)
- advance_deducted (INTEGER)
- selected_dates (TEXT)
- created_at, updated_at (TIMESTAMP)
```

#### 5. **contract_employees**
Contract-based employee information (referenced in frontend models).

---

### Production & Inventory

#### 6. **products**
Product catalog by sector.
```sql
- id (SERIAL, PRIMARY KEY)
- product_name (VARCHAR(255), NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- created_at, updated_at (TIMESTAMP)
- UNIQUE(product_name, sector_code)
```

#### 7. **daily_production**
Daily production tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- product_name (VARCHAR(255), NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- morning_production (INTEGER)
- afternoon_production (INTEGER)
- evening_production (INTEGER)
- unit (VARCHAR(20), CHECK: 'gram', 'kg', 'Litre', 'pieces', 'Boxes')
- production_date (DATE, NOT NULL)
- created_at, updated_at (TIMESTAMP)
- UNIQUE(product_name, sector_code, production_date)
```

#### 8. **stock_items**
Stock item master data.
```sql
- id (SERIAL, PRIMARY KEY)
- item_name (VARCHAR(255), NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- vehicle_type (VARCHAR(255))
- part_number (VARCHAR(255))
- created_at, updated_at (TIMESTAMP)
- UNIQUE(item_name, sector_code)
```

#### 9. **daily_stock**
Daily stock transactions.
```sql
- id (SERIAL, PRIMARY KEY)
- item_id (INTEGER, FK → stock_items.id)
- quantity_taken (VARCHAR(255))
- reason (TEXT)
- unit (VARCHAR(20), CHECK: 'gram', 'kg', 'Litre', 'pieces', 'Boxes')
- stock_date (DATE)
- created_at, updated_at (TIMESTAMP)
```

#### 10. **overall_stock**
Current stock levels.
```sql
- id (SERIAL, PRIMARY KEY)
- item_id (INTEGER, FK → stock_items.id, UNIQUE)
- remaining_stock (DECIMAL(10, 2))
- new_stock (DECIMAL(10, 2))
- new_stock_date (DATE)
- unit (VARCHAR(20))
- remaining_stock_gram, remaining_stock_kg, remaining_stock_litre, 
  remaining_stock_pieces, remaining_stock_boxes (DECIMAL(10, 2))
- new_stock_gram, new_stock_kg, new_stock_litre, 
  new_stock_pieces, new_stock_boxes (DECIMAL(10, 2))
- created_at, updated_at (TIMESTAMP)
```

---

### Expenses & Financial

#### 11. **daily_expenses**
Daily expense tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- item_details (VARCHAR(255), NOT NULL)
- amount (DECIMAL(10, 2), NOT NULL)
- reason_for_purchase (TEXT)
- expense_date (DATE, NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- created_at, updated_at (TIMESTAMP)
```

#### 12. **credit_details**
Credit transactions and settlements.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- name (VARCHAR(255), NOT NULL)
- phone_number (VARCHAR(50))
- address (TEXT)
- purchase_details (TEXT)
- credit_amount (DECIMAL(10, 2), NOT NULL)
- amount_settled (DECIMAL(10, 2))
- credit_date (DATE, NOT NULL)
- full_settlement_date (DATE)
- comments (TEXT)
- company_staff (BOOLEAN)
- created_at, updated_at (TIMESTAMP)
```

#### 13. **sales_details**
Sales transactions.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- name (VARCHAR(255), NOT NULL)
- contact_number (VARCHAR(50))
- address (TEXT)
- product_name (VARCHAR(255), NOT NULL)
- quantity (VARCHAR(255), NOT NULL)
- amount_received (DECIMAL(10, 2))
- credit_amount (DECIMAL(10, 2))
- amount_pending (DECIMAL(10, 2))
- balance_paid (DECIMAL(10, 2))
- balance_paid_date (DATE)
- details (TEXT)
- company_staff (BOOLEAN)
- sale_date (DATE, NOT NULL)
- created_at, updated_at (TIMESTAMP)
```

#### 14. **sales_balance_payments**
Sales balance payment history.
```sql
- id (SERIAL, PRIMARY KEY)
- sale_id (INTEGER, FK → sales_details.id)
- balance_paid (DECIMAL(10, 2), NOT NULL)
- balance_paid_date (DATE)
- details (TEXT)
- overall_balance (DECIMAL(10, 2), NOT NULL)
- created_at, updated_at (TIMESTAMP)
```

#### 15. **company_purchase_details**
Company purchase transactions.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- name (VARCHAR(255))
- contact_number (VARCHAR(50))
- address (TEXT)
- product_name (VARCHAR(255))
- quantity (VARCHAR(255))
- amount_received (DECIMAL(10, 2))
- credit_amount (DECIMAL(10, 2))
- amount_pending (DECIMAL(10, 2))
- balance_paid (DECIMAL(10, 2))
- balance_paid_date (DATE)
- purchase_date (DATE)
- item_name (VARCHAR(255))
- shop_name (VARCHAR(255))
- purchase_details (TEXT)
- purchase_amount (DECIMAL(10, 2))
- amount_paid (DECIMAL(10, 2))
- credit (DECIMAL(10, 2))
- details (TEXT)
- created_at, updated_at (TIMESTAMP)
```

#### 16. **company_purchase_balance_payments**
Company purchase balance payment history.
```sql
- id (SERIAL, PRIMARY KEY)
- purchase_id (INTEGER, FK → company_purchase_details.id)
- balance_paid (DECIMAL(10, 2), NOT NULL)
- balance_paid_date (DATE)
- details (TEXT)
- overall_balance (DECIMAL(10, 2), NOT NULL)
- created_at, updated_at (TIMESTAMP)
```

#### 17. **company_purchase_photos**
Photos for company purchases.
```sql
- id (SERIAL, PRIMARY KEY)
- purchase_id (INTEGER, FK → company_purchase_details.id)
- image_url (VARCHAR(500), NOT NULL)
- created_at (TIMESTAMP)
```

---

### Mahal & Catering

#### 18. **mahal_bookings**
Hall/venue booking management.
```sql
- id (SERIAL, PRIMARY KEY)
- booking_id (VARCHAR(255), PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- mahal_detail (VARCHAR(255), NOT NULL)
- event_date (DATE, NOT NULL)
- event_timing (VARCHAR(255))
- event_name (VARCHAR(255))
- client_name (VARCHAR(255), NOT NULL)
- client_phone1 (VARCHAR(50))
- client_phone2 (VARCHAR(50))
- client_address (TEXT)
- food_service (VARCHAR(50))
- advance_received (DECIMAL(10, 2))
- quoted_amount (DECIMAL(10, 2))
- amount_received (DECIMAL(10, 2))
- order_status (VARCHAR(20), CHECK: 'open', 'closed')
- details (TEXT)
- created_at, updated_at (TIMESTAMP)
```

#### 19. **catering_details**
Catering details for bookings.
```sql
- id (SERIAL, PRIMARY KEY)
- booking_id (VARCHAR(255), FK → mahal_bookings.booking_id, PRIMARY KEY)
- delivery_location (TEXT)
- morning_food_menu (TEXT)
- morning_food_count (INTEGER)
- afternoon_food_menu (TEXT)
- afternoon_food_count (INTEGER)
- evening_food_menu (TEXT)
- evening_food_count (INTEGER)
- created_at, updated_at (TIMESTAMP)
```

#### 20. **expense_details**
Expense breakdown for bookings.
```sql
- id (SERIAL, PRIMARY KEY)
- booking_id (VARCHAR(255), FK → mahal_bookings.booking_id, PRIMARY KEY)
- master_salary (DECIMAL(10, 2))
- cooking_helper_salary (DECIMAL(10, 2))
- external_catering_salary (DECIMAL(10, 2))
- current_bill (DECIMAL(10, 2))
- cleaning_bill (DECIMAL(10, 2))
- grocery_bill (DECIMAL(10, 2))
- vegetable_bill (DECIMAL(10, 2))
- cylinder_amount (DECIMAL(10, 2))
- morning_food_expense (DECIMAL(10, 2))
- afternoon_food_expense (DECIMAL(10, 2))
- evening_food_expense (DECIMAL(10, 2))
- vehicle_expense (DECIMAL(10, 2))
- packing_items_charge (DECIMAL(10, 2))
- details (TEXT)
- created_at, updated_at (TIMESTAMP)
```

#### 21. **billing_details**
Billing information (referenced in frontend models).

#### 22. **mahal_vessels**
Vessel inventory for mahal halls.
```sql
- id (SERIAL, PRIMARY KEY)
- mahal_detail (VARCHAR(255), CHECK: 'Thanthondrimalai Mini hall', 
                'Thirukampuliyur Minihall', 'Thirukampuliyur Big Hall')
- item_name (VARCHAR(255), NOT NULL)
- count (INTEGER, DEFAULT 1)
- created_at, updated_at (TIMESTAMP)
```

---

### Vehicle Management

#### 23. **vehicle_licenses**
Vehicle license and permit tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- name (VARCHAR(255), NOT NULL)
- model (VARCHAR(255), NOT NULL)
- registration_number (VARCHAR(255), NOT NULL)
- permit_date (DATE)
- insurance_date (DATE)
- fitness_date (DATE)
- pollution_date (DATE)
- tax_date (DATE)
- created_at, updated_at (TIMESTAMP)
```

#### 24. **driver_licenses**
Driver license tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- driver_name (VARCHAR(255), NOT NULL)
- license_number (VARCHAR(255), NOT NULL)
- expiry_date (DATE, NOT NULL)
- created_at, updated_at (TIMESTAMP)
```

#### 25. **engine_oil_services**
Vehicle service and maintenance tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- vehicle_name (VARCHAR(255), NOT NULL)
- model (VARCHAR(255), NOT NULL)
- service_part_name (VARCHAR(255), NOT NULL)
- service_date (DATE, NOT NULL)
- service_in_kms (INTEGER)
- service_in_hrs (INTEGER)
- next_service_date (DATE)
- created_at, updated_at (TIMESTAMP)
```

#### 26. **rent_vehicles**
Rental vehicle management.
```sql
- id (SERIAL, PRIMARY KEY)
- vehicle_name (VARCHAR(255), NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- created_at, updated_at (TIMESTAMP)
- UNIQUE(vehicle_name, sector_code)
```

#### 27. **rent_vehicle_attendance**
Rental vehicle attendance tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- vehicle_id (INTEGER, FK → rent_vehicles.id)
- vehicle_name (VARCHAR(255))
- sector_code (VARCHAR(50))
- date (DATE, NOT NULL)
- status (VARCHAR(20), CHECK: 'present', 'absent', 'halfday')
- created_at, updated_at (TIMESTAMP)
- UNIQUE(vehicle_id, date)
```

---

### Maintenance

#### 28. **maintenance_issues**
Maintenance issue tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- sector_code (VARCHAR(50), FK → sectors.code)
- issue_description (TEXT)
- date_created (DATE)
- status (VARCHAR(20), CHECK: 'Resolved', 'Not resolved')
- date_resolved (DATE)
- image_url (VARCHAR(500))
- created_at, updated_at (TIMESTAMP)
```

#### 29. **maintenance_issue_photos**
Photos for maintenance issues.
```sql
- id (SERIAL, PRIMARY KEY)
- issue_id (INTEGER, FK → maintenance_issues.id)
- image_url (VARCHAR(500), NOT NULL)
- created_at (TIMESTAMP)
```

---

### Ingredients & Mining

#### 30. **ingredient_menus**
Menu master data.
```sql
- id (SERIAL, PRIMARY KEY)
- menu (VARCHAR(255), NOT NULL, UNIQUE)
- members_count (INTEGER, DEFAULT 1)
- created_at, updated_at (TIMESTAMP)
```

#### 31. **ingredient_items**
Ingredient items for menus.
```sql
- id (SERIAL, PRIMARY KEY)
- menu_id (INTEGER, FK → ingredient_menus.id)
- ingredient_name (VARCHAR(255), NOT NULL)
- quantity (DECIMAL(10, 3), NOT NULL)
- unit (VARCHAR(50), CHECK: 'Litre', 'Gram', 'Kilogram', 'Pieces', 'ml')
- created_at, updated_at (TIMESTAMP)
```

#### 32. **mining_activities**
Mining activity master data.
```sql
- id (SERIAL, PRIMARY KEY)
- activity_name (VARCHAR(255), NOT NULL)
- sector_code (VARCHAR(50), FK → sectors.code)
- description (TEXT)
- created_at, updated_at (TIMESTAMP)
- UNIQUE(activity_name, sector_code)
```

#### 33. **daily_mining_activities**
Daily mining activity tracking.
```sql
- id (SERIAL, PRIMARY KEY)
- activity_id (INTEGER, FK → mining_activities.id)
- date (DATE, NOT NULL)
- quantity (DECIMAL(10, 2))
- unit (VARCHAR(50))
- notes (TEXT)
- created_at, updated_at (TIMESTAMP)
- UNIQUE(activity_id, date)
```

---

### Default Sectors

The database includes the following default sectors:
- **SSBM** - SRI SURYA BLUE METALS
- **SSC** - SRI SURYAA'S CAFE
- **SSBP** - SRI SURYA BHARATH PERTROLEUM
- **SSR** - SRI SURYA RICEMILL
- **SSACF** - SRI SURYA AGRO AND CATTLE FARM
- **SSMMC** - SRI SURYA MAHAL MINI HALL AND CATERING
- **SSEW** - SRI SURYA ENGINEERING WORKS

---

## 📁 Full Project Structure

```
central360/
│
├── 📂 backend/                          # Node.js + Express + PostgreSQL Backend
│   ├── 📂 src/
│   │   ├── 📄 index.js                  # Server entry point
│   │   ├── 📄 server.js                 # Express server configuration
│   │   ├── 📄 db.js                     # PostgreSQL connection pool
│   │   │
│   │   ├── 📂 routes/                   # API Route Handlers (31 files)
│   │   │   ├── app.routes.js            # App version & update endpoints
│   │   │   ├── attendance.routes.js     # Employee attendance
│   │   │   ├── auth.routes.js           # Authentication & login
│   │   │   ├── billing_details.routes.js
│   │   │   ├── catering_details.routes.js
│   │   │   ├── company_purchase_details.routes.js
│   │   │   ├── contract_employees.routes.js
│   │   │   ├── credit_details.routes.js
│   │   │   ├── daily_expenses.routes.js
│   │   │   ├── daily_production.routes.js
│   │   │   ├── daily_stock.routes.js
│   │   │   ├── driver_licenses.routes.js
│   │   │   ├── email.routes.js          # Email notifications
│   │   │   ├── employees.routes.js
│   │   │   ├── engine_oil_services.routes.js
│   │   │   ├── expense_details.routes.js
│   │   │   ├── ingredients.routes.js
│   │   │   ├── mahal_bookings.routes.js
│   │   │   ├── mahal_vessels.routes.js
│   │   │   ├── maintenance_issues.routes.js
│   │   │   ├── mining_activities.routes.js
│   │   │   ├── overall_stock.routes.js
│   │   │   ├── products.routes.js
│   │   │   ├── rent_vehicle_attendance.routes.js
│   │   │   ├── rent_vehicles.routes.js
│   │   │   ├── salary_expenses.routes.js
│   │   │   ├── sales_details.routes.js
│   │   │   ├── sectors.routes.js
│   │   │   ├── stock_items.routes.js
│   │   │   ├── stock_statement.routes.js
│   │   │   └── vehicle_licenses.routes.js
│   │   │
│   │   └── 📂 migrations/               # Database Migrations
│   │       ├── 📄 000_consolidated_migrations.sql  # Complete schema
│   │       ├── 📄 run_migration.js      # Migration runner
│   │       ├── 📄 README.md
│   │       └── 📂 archive/              # Historical migrations (50 files)
│   │
│   ├── 📂 uploads/                      # File uploads
│   │   ├── maintenance/                 # Maintenance photos
│   │   └── purchases/                   # Purchase photos
│   │
│   ├── 📄 package.json                  # Node.js dependencies
│   ├── 📄 railway.json                  # Railway deployment config
│   ├── 📄 README_SETUP.md
│   ├── 📄 SETUP_GUIDE.md
│   ├── 📄 RAILWAY_DEPLOYMENT.md
│   ├── 📄 RUN_MIGRATION_RAILWAY.md
│   └── 📄 TROUBLESHOOTING.md
│
├── 📂 frontend/                         # Flutter Application
│   ├── 📂 lib/
│   │   ├── 📄 main.dart                 # App entry point
│   │   │
│   │   ├── 📂 config/
│   │   │   └── env_config.dart          # Environment configuration
│   │   │
│   │   ├── 📂 models/                   # Data Models (13 files)
│   │   │   ├── billing_details.dart
│   │   │   ├── catering_details.dart
│   │   │   ├── contract_employee.dart
│   │   │   ├── credit_details.dart
│   │   │   ├── driver_license.dart
│   │   │   ├── employee.dart
│   │   │   ├── engine_oil_service.dart
│   │   │   ├── expense_details.dart
│   │   │   ├── mahal_booking.dart
│   │   │   ├── maintenance_issue.dart
│   │   │   ├── product.dart
│   │   │   ├── sector.dart
│   │   │   └── vehicle_license.dart
│   │   │
│   │   ├── 📂 screens/                  # UI Screens (54 files)
│   │   │   ├── 📱 Core Screens
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── new_entry_screen.dart
│   │   │   │   └── update_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Employee Management
│   │   │   │   ├── add_employee_dialog.dart
│   │   │   │   ├── edit_employee_dialog.dart
│   │   │   │   ├── employee_details_screen.dart
│   │   │   │   ├── daily_attendance_screen.dart
│   │   │   │   ├── attendance_tab_content.dart
│   │   │   │   ├── attendance_advance_screen.dart
│   │   │   │   ├── present_days_count_tab_content.dart
│   │   │   │   └── salary_expense_screen.dart
│   │   │   │
│   │   │   ├── 📱 Production & Stock
│   │   │   │   ├── daily_production_screen.dart
│   │   │   │   ├── production_tab_content.dart
│   │   │   │   ├── stock_management_screen.dart
│   │   │   │   ├── add_stock_item_dialog.dart
│   │   │   │   ├── edit_stock_item_dialog.dart
│   │   │   │   └── manage_stock_items_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Expenses & Financial
│   │   │   │   ├── daily_expense_screen.dart
│   │   │   │   ├── daily_expense_without_credit_screen.dart
│   │   │   │   ├── expense_tab_content.dart
│   │   │   │   ├── credit_details_screen.dart
│   │   │   │   ├── credit_tab_content.dart
│   │   │   │   ├── sales_credit_details_screen.dart
│   │   │   │   └── company_purchase_credit_details_screen.dart
│   │   │   │
│   │   │   ├── 📱 Mahal & Catering
│   │   │   │   ├── mahal_booking_screen.dart
│   │   │   │   ├── add_mahal_booking_dialog.dart
│   │   │   │   ├── add_catering_details_dialog.dart
│   │   │   │   ├── add_expense_details_dialog.dart
│   │   │   │   └── add_billing_details_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Vehicle Management
│   │   │   │   ├── vehicle_driver_license_screen.dart
│   │   │   │   ├── add_vehicle_license_dialog.dart
│   │   │   │   ├── add_driver_license_dialog.dart
│   │   │   │   ├── add_engine_oil_service_dialog.dart
│   │   │   │   ├── add_rent_vehicle_dialog.dart
│   │   │   │   └── edit_rent_vehicle_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Maintenance
│   │   │   │   ├── maintenance_issue_screen.dart
│   │   │   │   ├── add_issue_dialog.dart
│   │   │   │   └── upload_photos_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Ingredients & Mining
│   │   │   │   ├── ingredients_details_screen.dart
│   │   │   │   ├── add_ingredient_dialog.dart
│   │   │   │   ├── daily_mining_activity_tab_content.dart
│   │   │   │   ├── add_mining_activity_dialog.dart
│   │   │   │   ├── edit_mining_activity_dialog.dart
│   │   │   │   └── manage_mining_activities_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Management Dialogs
│   │   │   │   ├── manage_sectors_dialog.dart
│   │   │   │   ├── add_sector_dialog.dart
│   │   │   │   ├── manage_products_dialog.dart
│   │   │   │   ├── add_product_dialog.dart
│   │   │   │   ├── edit_product_dialog.dart
│   │   │   │   ├── manage_rent_vehicles_dialog.dart
│   │   │   │   └── manage_stock_items_dialog.dart
│   │   │   │
│   │   │   ├── 📱 Reports & Utilities
│   │   │   │   ├── daily_report_details_screen.dart
│   │   │   │   ├── month_year_picker.dart
│   │   │   │   └── add_contract_employee_dialog.dart
│   │   │   │
│   │   ├── 📂 services/                 # API & Business Logic (6 files)
│   │   │   ├── api_service.dart         # Main API client
│   │   │   ├── auth_service.dart        # Authentication
│   │   │   ├── sector_service.dart      # Sector management
│   │   │   ├── notification_service.dart
│   │   │   ├── expiry_notification_service.dart
│   │   │   └── update_service.dart      # App update checking
│   │   │
│   │   └── 📂 utils/                    # Utilities (4 files)
│   │       ├── constants.dart           # App constants
│   │       ├── format_utils.dart        # Formatting helpers
│   │       ├── pdf_generator.dart       # PDF report generation
│   │       └── ui_helpers.dart          # UI helper functions
│   │
│   ├── 📂 android/                      # Android platform files
│   ├── 📂 ios/                          # iOS platform files
│   ├── 📂 windows/                      # Windows platform files
│   ├── 📂 assets/                      # App assets
│   │   └── brand/
│   │       └── c360-background.png
│   │
│   ├── 📄 pubspec.yaml                  # Flutter dependencies
│   ├── 📄 setup.iss                     # Inno Setup installer config
│   ├── 📄 README.md
│   ├── 📄 BUILD_ANDROID_MANUAL.md
│   ├── 📄 INSTALL_INNO_SETUP.md
│   ├── 📄 NOTIFICATION_SETUP.md
│   └── 📄 PERMISSIONS_GUIDE.md
│
├── 📂 docs/                             # Documentation
│   ├── 📄 PROJECT_STRUCTURE.md
│   ├── 📄 DATABASE_AND_PROJECT_STRUCTURE.md (this file)
│   └── 📂 scripts/
│       ├── COPY_SSR_PRODUCTS_TO_STOCK.sql
│       └── QUICK_DB_CHECK.sql
│
├── 📂 assets/                           # Brand assets
│   └── brand/
│       ├── c360-background.png
│       ├── c360-icon.ico
│       └── c360-icon.png
│
├── 📄 README.md                         # Main project README
├── 📄 railway.json                      # Root Railway config
├── 📄 RAILWAY_DISK_SPACE_RECOMMENDATION.md
├── 📄 RELEASE-v1.0.7.md
├── 📄 RELEASE-v1.0.8.md
├── 📄 BUILD-STEPS-v1.0.8.md
│
└── 📄 Build Scripts (PowerShell/Batch)
    ├── build-and-release.ps1
    ├── build-and-release-simple.ps1
    ├── build-android-v1.0.7.ps1
    ├── build-windows-v1.0.7.ps1
    ├── build-production-installer.bat
    ├── QUICK_RELEASE.ps1
    └── ... (multiple build scripts)
```

---

## 🔗 Key Relationships

### Foreign Key Relationships:
- **employees** → **sectors** (sector)
- **attendance** → **employees** (employee_id)
- **salary_expenses** → **employees** (employee_id)
- **products** → **sectors** (sector_code)
- **daily_production** → **sectors** (sector_code)
- **stock_items** → **sectors** (sector_code)
- **daily_stock** → **stock_items** (item_id)
- **overall_stock** → **stock_items** (item_id)
- **catering_details** → **mahal_bookings** (booking_id)
- **expense_details** → **mahal_bookings** (booking_id)
- **sales_balance_payments** → **sales_details** (sale_id)
- **company_purchase_balance_payments** → **company_purchase_details** (purchase_id)
- **maintenance_issue_photos** → **maintenance_issues** (issue_id)
- **company_purchase_photos** → **company_purchase_details** (purchase_id)
- **rent_vehicle_attendance** → **rent_vehicles** (vehicle_id)
- **ingredient_items** → **ingredient_menus** (menu_id)
- **daily_mining_activities** → **mining_activities** (activity_id)

---

## 📊 Database Statistics

- **Total Tables**: 33
- **Core Tables**: 5 (sectors, employees, attendance, salary_expenses, products)
- **Financial Tables**: 6 (credit_details, sales_details, company_purchase_details, etc.)
- **Inventory Tables**: 4 (stock_items, daily_stock, overall_stock, products)
- **Vehicle Tables**: 5 (vehicle_licenses, driver_licenses, engine_oil_services, rent_vehicles, rent_vehicle_attendance)
- **Mahal/Catering Tables**: 4 (mahal_bookings, catering_details, expense_details, mahal_vessels)
- **Other Tables**: 9 (maintenance_issues, ingredient_menus, mining_activities, etc.)

---

## 🛠️ Technology Stack

### Backend:
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: PostgreSQL
- **Authentication**: JWT (jsonwebtoken)
- **File Upload**: Multer
- **Email**: Nodemailer
- **Security**: Helmet, CORS

### Frontend:
- **Framework**: Flutter 3.0+
- **Platforms**: Windows, Android, iOS (Desktop priority)
- **State Management**: Flutter built-in
- **PDF Generation**: Custom PDF generator
- **Notifications**: Local notifications

### Deployment:
- **Backend**: Railway
- **Database**: PostgreSQL (Railway)
- **File Storage**: Local uploads directory

---

## 📝 Notes

- The database uses PostgreSQL with comprehensive indexing for performance
- All tables include `created_at` and `updated_at` timestamps
- Foreign key constraints ensure data integrity
- Unique constraints prevent duplicate entries where applicable
- The application supports multi-sector/branch operations
- Offline functionality is supported in the Flutter frontend

---

*Last Updated: Based on migration 000_consolidated_migrations.sql*
*Project Version: Backend v0.1.4, Frontend v1.0.17*

