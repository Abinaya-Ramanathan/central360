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
    // Use single consolidated migration file that includes all migrations (001-055)
    const migrationFiles = ['000_consolidated_migrations.sql'];
    
    for (const migrationFile of migrationFiles) {
      const migrationPath = path.join(migrationsDir, migrationFile);
      
      if (fs.existsSync(migrationPath)) {
        const sql = fs.readFileSync(migrationPath, 'utf8');
        console.log(`Running migration: ${migrationFile}`);
        await db.query(sql);
        console.log(`✓ Migration ${migrationFile} completed`);
      } else {
        console.warn(`Migration file not found: ${migrationFile}`);
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


