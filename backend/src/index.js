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
  // Don't exit - let the app continue running
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit - let the app continue running
});

// Auto-run migrations on startup
async function runMigrations() {
  try {
    const migrationsDir = path.join(__dirname, 'migrations');
    const migrationFiles = ['001_complete_schema.sql', '002_default_data.sql', '003_add_vehicle_fields_to_stock_items.sql'];
    
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
  app.listen(port, host, () => {
    console.log(`Central360 API listening on http://${host}:${port}`);
  });
}).catch((error) => {
  console.error('Failed to start server:', error);
  // Still try to start the server even if migrations fail
  app.listen(port, host, () => {
    console.log(`Central360 API listening on http://${host}:${port}`);
  });
});


