# Database Migrations

## Overview

This directory contains the consolidated database migrations for the Central360 application.

## Current Active Migrations

### 1. `001_complete_schema.sql`
**Purpose**: Complete database schema with all tables in their final state.

**Includes**:
- All 15 tables (sectors, employees, attendance, salary_expenses, daily_production, products, daily_expenses, maintenance_issues, mahal_bookings, catering_details, expense_details, credit_details, vehicle_licenses, driver_licenses, engine_oil_services)
- All columns and relationships
- All indexes for performance optimization
- All constraints and foreign keys
- Consolidates migrations 001-031

**Usage**: Run this file to create a fresh database with all tables.

### 2. `002_default_data.sql`
**Purpose**: Inserts default data required for the application to function.

**Includes**:
- Default sectors (SSBM, SSMM, etc.)
- Any other required initial data

**Usage**: Run after `001_complete_schema.sql` to populate default data.

## Migration Script

To run a migration file, use:

```bash
node src/migrations/run_migration.js <migration_file>
```

Example:
```bash
node src/migrations/run_migration.js 001_complete_schema.sql
```

## Archived Migrations

All historical migration files (001-031) have been archived in the `archive/` directory for reference. These are no longer needed for new installations but are kept for historical tracking.

See `archive/README.md` for more details.

## Database Setup for New Installations

1. Run the complete schema:
   ```bash
   node src/migrations/run_migration.js 001_complete_schema.sql
   ```

2. Run the default data:
   ```bash
   node src/migrations/run_migration.js 002_default_data.sql
   ```

That's it! Your database is now set up with all tables, indexes, and default data.

## For Existing Databases

If you have an existing database:
- Your database should already be up to date
- Individual migrations have already been applied
- No action needed

## Schema Changes

All schema changes are now consolidated into `001_complete_schema.sql`. The file includes:
- Table definitions
- Column definitions with all recent additions
- Indexes for query performance
- Foreign key relationships
- Check constraints

## Maintenance

When adding new features:
1. Update `001_complete_schema.sql` with new tables/columns
2. Update this README if needed
3. Document the changes in commit messages

