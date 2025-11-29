import dotenv from 'dotenv';
dotenv.config();

import app from './server.js';
import db from './db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Handle uncaught errors to prevent crashes
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  console.error('Stack:', error.stack);
  // Don't exit - let the app continue running
  // Railway will restart if needed
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise);
  console.error('Reason:', reason);
  // Don't exit - let the app continue running
  // Railway will restart if needed
});

// Auto-run migrations on startup
async function runMigrations() {
  try {
    const migrationsDir = path.join(__dirname, 'migrations');
    const migrationFiles = ['001_complete_schema.sql', '002_default_data.sql', '003_add_vehicle_fields_to_stock_items.sql', '032_add_maintenance_issue_photos.sql', '033_add_sales_details.sql', '034_add_balance_paid_to_sales_details.sql', '035_add_balance_paid_date_to_sales_details.sql', '036_add_bulk_advance_columns.sql', '037_add_company_purchase_details.sql', '038_update_company_purchase_details.sql', '039_add_balance_payments_table.sql', '040_add_sales_balance_payments_table.sql', '041_add_details_to_sales_details.sql', '042_add_sector_code_to_daily_production.sql', '043_add_unit_columns_to_stock_and_production.sql', '044_add_unit_columns_to_overall_stock.sql', '045_add_pieces_to_stock.sql'];
    
    for (const file of migrationFiles) {
      const migrationPath = path.join(migrationsDir, file);
      if (fs.existsSync(migrationPath)) {
        const sql = fs.readFileSync(migrationPath, 'utf8');
        console.log(`Running migration: ${file}`);
        await db.query(sql);
        console.log(`✓ Migration ${file} completed`);
      }
    }
  } catch (error) {
    // If migrations fail, log but don't crash - tables might already exist
    if (error.message.includes('already exists') || error.message.includes('duplicate')) {
      console.log('Migrations already applied or partially applied');
    } else {
      console.error('Migration error (non-fatal):', error.message);
    }
  }
}

const port = process.env.PORT || 4000;
const host = process.env.HOST || '0.0.0.0';

// Start server after migrations
runMigrations().then(() => {
  const server = app.listen(port, host, () => {
    console.log(`Central360 API listening on http://${host}:${port}`);
    console.log(`Health check available at http://${host}:${port}/api/health`);
  });
  
  // Keep the process alive
  server.on('error', (error) => {
    console.error('Server error:', error);
  });
  
  // Handle graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
  
  process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
}).catch((error) => {
  console.error('Failed to start server:', error);
  // Still try to start the server even if migrations fail
  const server = app.listen(port, host, () => {
    console.log(`Central360 API listening on http://${host}:${port}`);
    console.log(`Health check available at http://${host}:${port}/api/health`);
  });
  
  server.on('error', (error) => {
    console.error('Server error:', error);
  });
  
  // Handle graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
  
  process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
});


