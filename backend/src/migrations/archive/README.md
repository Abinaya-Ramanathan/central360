# Archived Migration Files

This folder contains all historical migration files (001-031) that were used during development.

## Consolidation

These files have been consolidated into:
- `../001_complete_schema.sql` - All tables in their final state (includes all features through migration 031)
- `../002_default_data.sql` - All default data inserts

## Why Archive?

The migrations were consolidated to:
1. Simplify database setup for new installations
2. Reduce the number of active files from 31+ to 2
3. Make it easier to understand the complete database structure
4. Maintain all functionality while improving maintainability
5. Provide a clear migration history for reference

## Migration History

### Active Migrations (001-031)
All migrations from 001 to 031 have been consolidated into:
- **001_complete_schema.sql** - Complete database schema with all tables and columns
- **002_default_data.sql** - Default data (sectors, etc.)

### Included Features:
- ✅ All original features (migrations 001-027)
- ✅ Vehicle, Driver, and Engine Oil Service tables (migration 028)
- ✅ Packing items charge column (migration 029)
- ✅ Delivery location column (migration 030)
- ✅ Comments column in credit details (migration 031)

## For Existing Databases

If you have an existing database that was created using these individual migrations, you do NOT need to run the consolidated migrations. Your database is already up to date.

## For New Installations

Use the consolidated migrations:
- `001_complete_schema.sql` - Creates all tables with all columns
- `002_default_data.sql` - Inserts default data

These files are located in the parent directory: `../`

## Notes

- All archived migrations are preserved for historical reference
- The complete schema file includes comprehensive indexes for performance
- All foreign key relationships and constraints are included

