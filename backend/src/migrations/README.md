# Database Migrations

## Overview

This directory contains the consolidated database migrations for the Central360 application. All migrations have been consolidated into a single file for easier management.

## Current Active Migration

### `000_consolidated_migrations.sql`

**Purpose**: Complete database schema with all tables, indexes, default data, and all incremental updates in a single file.

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

## Archived Migrations

All historical migration files (001-050) have been archived in the `archive/` directory for reference. These are no longer needed for new installations but are kept for historical tracking.

The individual migration files (051-055) have been consolidated into `000_consolidated_migrations.sql` and removed.

## Maintenance

When adding new features:
1. Update `000_consolidated_migrations.sql` with new tables/columns in the appropriate section
2. Add ALTER TABLE statements in the "ALTER TABLE STATEMENTS FOR EXISTING DATABASES" section
3. Update indexes if needed
4. Update this README if needed
5. Document the changes in commit messages

## Migration History

- **Migrations 001-050**: Consolidated into the main schema and default data sections
- **Migration 051**: Performance indexes - Added to Part 6
- **Migration 052**: Made sales_details.name optional - Added to Part 5
- **Migration 053**: Created daily_income_expense table - Added to Part 4
- **Migration 054**: Added final_settlement_amount to mahal_bookings - Added to Part 5
- **Migration 055**: Made sales_details.product_name and quantity optional - Added to Part 5
