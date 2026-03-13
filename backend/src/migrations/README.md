# Database Migrations

## Overview

All backend database changes are in **one migration file**. There are no other migration files to run; previous standalone migration files have been removed and their changes are included in the consolidated file.

## Single Migration File

### `000_consolidated_migrations.sql`

**Purpose**: The only migration file. Contains the full schema, all tables, indexes, default data, and every incremental change (ALTERs, new columns, SSC subsectors, daily_stock/daily_production/overall_stock updates, etc.).

**Includes**:
- Complete database schema with all tables (sectors, employees, attendance, salary_expenses, daily_production, products, daily_expenses, maintenance_issues, mahal_bookings, catering_details, expense_details, credit_details, vehicle_licenses, driver_licenses, engine_oil_services, stock_items, daily_stock, overall_stock, sales_details, sales_balance_payments, company_purchase_details, company_purchase_balance_payments, maintenance_issue_photos, company_purchase_photos, daily_income_expense, mahal_vessels, rent_vehicles, rent_vehicle_attendance, ingredient_menus, ingredient_items, mining_activities, daily_mining_activities)
- All columns and relationships including latest additions
- All indexes for performance optimization
- All constraints and foreign keys
- Default data (sectors, products)
- All incremental updates (migrations 001-055)
- Safe ALTER TABLE statements for existing databases

**Usage**: Run this single file to set up a complete database or update an existing database.

```bash
node src/migrations/run_migration.js 000_consolidated_migrations.sql
```

## Migration Script

To run the migration file, use:

```bash
node src/migrations/run_migration.js 000_consolidated_migrations.sql
```

## Database Setup

### For New Installations

Simply run the consolidated migration file:

```bash
node src/migrations/run_migration.js 000_consolidated_migrations.sql
```

This will:
- Create all tables with proper schema
- Add all indexes for performance
- Insert default data (sectors, products)
- Apply all incremental updates

### For Existing Databases

The consolidated migration file is safe to run on existing databases:
- Uses `CREATE TABLE IF NOT EXISTS` for tables
- Uses `ADD COLUMN IF NOT EXISTS` for new columns
- Uses `CREATE INDEX IF NOT EXISTS` for indexes
- Uses `ON CONFLICT DO NOTHING` for default data inserts
- Handles errors gracefully with DO blocks for ALTER TABLE statements

Simply run:

```bash
node src/migrations/run_migration.js 000_consolidated_migrations.sql
```

## Other Files

- **`run_migration.js`** – Run this with the migration filename to execute it: `node run_migration.js 000_consolidated_migrations.sql`
- **`archive/`** – Old migration files (001–050) kept only for reference. Do not run them; everything is in `000_consolidated_migrations.sql`.

## Maintenance

When adding new features:
1. Update `000_consolidated_migrations.sql` with new tables/columns in the appropriate section
2. Add ALTER TABLE statements in the "ALTER TABLE STATEMENTS FOR EXISTING DATABASES" section
3. Update indexes if needed
4. Update this README if needed
5. Document the changes in commit messages

## Migration History

- **Migrations 001-050**: Consolidated into the main schema and default data sections (including 049 parent_sector_code, 050 SSC subsectors SSCT/CS/SSCM)
- **Migration 051**: Performance indexes - Added to Part 6
- **Migration 052**: Made sales_details.name optional - Added to Part 5
- **Migration 053**: Created daily_income_expense table - Added to Part 4
- **Migration 054**: Added final_settlement_amount to mahal_bookings - Added to Part 5
- **Migration 055**: Made sales_details.product_name and quantity optional - Added to Part 5
